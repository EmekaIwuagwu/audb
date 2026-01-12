// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IJoeRouter02.sol";
import "./AUDB.sol";

interface IJoeFactory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

interface ILiquidityManager {
    function manageSupplyExpansion(uint256 amount) external;
    function manageSupplyContraction(
        uint256 amountToBurn
    ) external returns (uint256);
}

/**
 * @title LiquidityManager - Protocol-Owned Liquidity Manager
 * @notice Manages AUDB/USDC liquidity on Trader Joe
 * @dev Implements slippage protection and emergency withdrawals
 */
contract LiquidityManager is Ownable, ReentrancyGuard, ILiquidityManager {
    using SafeERC20 for IERC20;

    IJoeRouter02 public router;
    AUDB public audb;
    IERC20 public collateral; // e.g., USDC or WAVAX

    /// @notice Maximum slippage tolerance (1% = 100 basis points)
    uint256 public constant MAX_SLIPPAGE_BPS = 100;

    /// @notice Deadline offset for DEX operations (5 minutes)
    uint256 public constant DEADLINE_OFFSET = 300;

    event LiquidityAdded(
        uint256 audbAmount,
        uint256 collateralAmount,
        uint256 liquidity
    );
    event LiquidityRemoved(
        uint256 liquidity,
        uint256 audbAmount,
        uint256 collateralAmount
    );
    event ExpansionManaged(uint256 audbAmount, uint256 collateralReceived);
    event EmergencyWithdrawal(address indexed token, uint256 amount);

    constructor(address _router, address _audb, address _collateral) Ownable() {
        require(_router != address(0), "LM: invalid router");
        require(_audb != address(0), "LM: invalid AUDB");
        require(_collateral != address(0), "LM: invalid collateral");

        router = IJoeRouter02(_router);
        audb = AUDB(_audb);
        collateral = IERC20(_collateral);
    }

    // Called by Rebalancer during Expansion:
    // 1. Receives AUDB
    // 2. Swaps half for Collateral (USDC)
    // 3. Adds Liquidity (AUDB/USDC)
    // Result: Sell pressure on AUDB + Deeper Liquidity
    /**
     * @notice Manages supply expansion by selling AUDB and adding liquidity
     * @param amount Amount of AUDB to manage
     */
    function manageSupplyExpansion(
        uint256 amount
    ) external override onlyOwner nonReentrant {
        require(amount > 0, "LM: zero amount");

        require(
            audb.transferFrom(msg.sender, address(this), amount),
            "LM: transfer failed"
        );

        uint256 half = amount / 2;
        uint256 otherHalf = amount - half;

        // Swap half AUDB for Collateral
        uint256 collateralReceived = _swapAudbForCollateral(half);

        // Add Liquidity with remaining AUDB and received Collateral
        _addLiquidity(otherHalf, collateralReceived);

        emit ExpansionManaged(amount, collateralReceived);
    }

    // Called by Rebalancer during Contraction:
    // 1. Removes Liquidity
    // 2. Uses AUDB to burn (sends back to Rebalancer)
    // 3. Uses Collateral to buy AUDB? Or just holds it?
    // Simplified: Just remove LP, send AUDB back.
    function manageSupplyContraction(
        uint256 amountToBurn
    ) external override onlyOwner nonReentrant returns (uint256) {
        // We will just remove a fixed amount of liquidity if available.
        address pair = _getPair();
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));
        if (lpBalance == 0) return 0;

        uint256 paramsLpToRemove = lpBalance / 10; // Remove 10% chunks
        _removeLiquidity(paramsLpToRemove);

        uint256 audbBalance = audb.balanceOf(address(this));
        if (audbBalance > amountToBurn) {
            audb.transfer(msg.sender, amountToBurn);
            return amountToBurn;
        } else {
            audb.transfer(msg.sender, audbBalance);
            return audbBalance;
        }
    }

    /**
     * @notice Swaps AUDB for collateral with slippage protection
     * @param amountIn Amount of AUDB to swap
     * @return Amount of collateral received
     */
    function _swapAudbForCollateral(
        uint256 amountIn
    ) internal returns (uint256) {
        audb.approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(audb);
        path[1] = address(collateral);

        // Get expected output amount
        uint[] memory amountsOut = router.getAmountsOut(amountIn, path);

        // Calculate minimum with 1% slippage protection
        uint256 minCollateral = (amountsOut[1] * (10000 - MAX_SLIPPAGE_BPS)) /
            10000;

        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minCollateral, // Slippage protection
            path,
            address(this),
            block.timestamp + DEADLINE_OFFSET
        );
        return amounts[1];
    }

    /**
     * @notice Adds liquidity to AUDB/Collateral pool
     * @param audbAmount Amount of AUDB to add
     * @param collateralAmount Amount of collateral to add
     */
    function _addLiquidity(
        uint256 audbAmount,
        uint256 collateralAmount
    ) internal {
        audb.approve(address(router), audbAmount);
        collateral.approve(address(router), collateralAmount);

        // Calculate minimum amounts with 1% slippage
        uint256 minAudb = (audbAmount * (10000 - MAX_SLIPPAGE_BPS)) / 10000;
        uint256 minCollateral = (collateralAmount *
            (10000 - MAX_SLIPPAGE_BPS)) / 10000;

        router.addLiquidity(
            address(audb),
            address(collateral),
            audbAmount,
            collateralAmount,
            minAudb,
            minCollateral,
            address(this),
            block.timestamp + DEADLINE_OFFSET
        );
    }

    /**
     * @notice Removes liquidity from the pool
     * @param lpAmount Amount of LP tokens to remove
     */
    function _removeLiquidity(uint256 lpAmount) internal {
        address pair = _getPair();
        IERC20(pair).approve(address(router), lpAmount);

        router.removeLiquidity(
            address(audb),
            address(collateral),
            lpAmount,
            0, // Emergency mode - accept any amount
            0,
            address(this),
            block.timestamp + DEADLINE_OFFSET
        );
    }

    function _getPair() internal view returns (address) {
        address factory = 0xF5c7d9733e5f53abCC1695820c4818C59B457C2C;
        return IJoeFactory(factory).getPair(address(audb), address(collateral));
    }

    /**
     * @notice Emergency withdrawal of all liquidity
     * @dev Only callable by owner in emergency situations
     */
    function emergencyRemoveAllLiquidity() external onlyOwner nonReentrant {
        address pair = _getPair();
        uint256 lpBalance = IERC20(pair).balanceOf(address(this));

        if (lpBalance > 0) {
            _removeLiquidity(lpBalance);
        }

        // Transfer all rescued tokens to owner
        uint256 audbBal = audb.balanceOf(address(this));
        uint256 colBal = collateral.balanceOf(address(this));

        if (audbBal > 0)
            require(
                audb.transfer(msg.sender, audbBal),
                "LM: AUDB transfer failed"
            );
        if (colBal > 0) collateral.safeTransfer(msg.sender, colBal);

        emit EmergencyWithdrawal(address(audb), audbBal);
        emit EmergencyWithdrawal(address(collateral), colBal);
    }

    /**
     * @notice Admin function to rescue tokens
     * @param token Token address to withdraw
     * @param amount Amount to withdraw
     */
    function withdraw(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "LM: invalid token");
        require(amount > 0, "LM: zero amount");
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdrawal(token, amount);
    }
}
