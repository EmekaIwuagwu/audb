// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

contract LiquidityManager is Ownable, ReentrancyGuard, ILiquidityManager {
    IJoeRouter02 public router;
    AUDB public audb;
    IERC20 public collateral; // e.g., USDC or WAVAX

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

    constructor(address _router, address _audb, address _collateral) Ownable() {
        router = IJoeRouter02(_router);
        audb = AUDB(_audb);
        collateral = IERC20(_collateral);
    }

    // Called by Rebalancer during Expansion:
    // 1. Receives AUDB
    // 2. Swaps half for Collateral (USDC)
    // 3. Adds Liquidity (AUDB/USDC)
    // Result: Sell pressure on AUDB + Deeper Liquidity
    function manageSupplyExpansion(
        uint256 amount
    ) external override onlyOwner nonReentrant {
        require(
            audb.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
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

    function _swapAudbForCollateral(
        uint256 amountIn
    ) internal returns (uint256) {
        audb.approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(audb);
        path[1] = address(collateral);

        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            0, // Accept any amount of collateral for now (Production: Use oracle/min bounds)
            path,
            address(this),
            block.timestamp
        );
        return amounts[1];
    }

    function _addLiquidity(
        uint256 audbAmount,
        uint256 collateralAmount
    ) internal {
        audb.approve(address(router), audbAmount);
        collateral.approve(address(router), collateralAmount);

        router.addLiquidity(
            address(audb),
            address(collateral),
            audbAmount,
            collateralAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function _removeLiquidity(uint256 lpAmount) internal {
        address pair = _getPair();
        IERC20(pair).approve(address(router), lpAmount);

        router.removeLiquidity(
            address(audb),
            address(collateral),
            lpAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function _getPair() internal view returns (address) {
        address factory = 0xF5c7d9733e5f53abCC1695820c4818C59B457C2C;
        return IJoeFactory(factory).getPair(address(audb), address(collateral));
    }

    // Admin functions to rescue tokens
    function withdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }
}
