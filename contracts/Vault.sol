// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AUDB.sol";

/**
 * @title Vault - Over-Collateralized AUDB Minting
 * @notice Allows users to mint AUDB by depositing USDC collateral
 * @dev Enforces 150% minimum collateralization ratio with liquidation mechanism
 */
contract Vault is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    AUDB public audb;
    IERC20 public collateral; // USDC

    /// @notice Minimum collateralization ratio (150%)
    uint256 public constant MIN_COLLATERAL_RATIO = 150;

    /// @notice Liquidation threshold (140%)
    uint256 public constant LIQUIDATION_THRESHOLD = 140;

    /// @notice Liquidation bonus for liquidators (5%)
    uint256 public constant LIQUIDATION_BONUS = 5;

    /// @notice Price precision
    uint256 public constant PRICE_PRECISION = 1e18;

    /// @notice USDC decimals
    uint8 public constant USDC_DECIMALS = 6;

    /// @notice AUDB decimals
    uint8 public constant AUDB_DECIMALS = 18;

    struct Position {
        uint256 collateralAmount; // USDC (6 decimals)
        uint256 debtAmount; // AUDB minted (18 decimals)
    }

    mapping(address => Position) public positions;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Minted(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Liquidated(
        address indexed user,
        address indexed liquidator,
        uint256 debtRepaid,
        uint256 collateralSeized
    );

    constructor(address _audb, address _collateral) {
        require(_audb != address(0), "Vault: invalid AUDB");
        require(_collateral != address(0), "Vault: invalid collateral");

        audb = AUDB(_audb);
        collateral = IERC20(_collateral);
    }

    /**
     * @notice Deposit collateral and mint AUDB
     * @param colAmount Amount of USDC to deposit (6 decimals)
     * @param mintAmount Amount of AUDB to mint (18 decimals)
     */
    function depositAndMint(
        uint256 colAmount,
        uint256 mintAmount
    ) external nonReentrant whenNotPaused {
        require(colAmount > 0, "Vault: zero collateral");
        require(mintAmount > 0, "Vault: zero mint amount");

        // 1. Transfer Collateral
        collateral.safeTransferFrom(msg.sender, address(this), colAmount);

        // 2. Update Position
        Position storage pos = positions[msg.sender];
        pos.collateralAmount += colAmount;
        pos.debtAmount += mintAmount;

        // 3. Check Health (must maintain >= 150% ratio)
        require(
            _checkHealth(pos.collateralAmount, pos.debtAmount),
            "Vault: undercollateralized"
        );

        // 4. Mint AUDB
        audb.mint(msg.sender, mintAmount);

        emit Deposited(msg.sender, colAmount);
        emit Minted(msg.sender, mintAmount);
    }

    /**
     * @notice Repay debt and withdraw collateral
     * @param repayAmount Amount of AUDB to repay
     * @param colToWithdraw Amount of USDC to withdraw
     */
    function repayAndWithdraw(
        uint256 repayAmount,
        uint256 colToWithdraw
    ) external nonReentrant whenNotPaused {
        Position storage pos = positions[msg.sender];

        require(repayAmount > 0 || colToWithdraw > 0, "Vault: zero operation");

        // 1. Burn Debt if repaying
        if (repayAmount > 0) {
            require(pos.debtAmount >= repayAmount, "Vault: over repayment");
            require(
                audb.transferFrom(msg.sender, address(this), repayAmount),
                "Vault: transfer failed"
            );
            audb.burn(address(this), repayAmount);
            pos.debtAmount -= repayAmount;
        }

        // 2. Update Collateral if withdrawing
        if (colToWithdraw > 0) {
            require(
                pos.collateralAmount >= colToWithdraw,
                "Vault: over withdrawal"
            );
            pos.collateralAmount -= colToWithdraw;
        }

        // 3. Check Health (if still has debt)
        if (pos.debtAmount > 0) {
            require(
                _checkHealth(pos.collateralAmount, pos.debtAmount),
                "Vault: unhealthy withdrawal"
            );
        }

        // 4. Send Collateral if withdrawing
        if (colToWithdraw > 0) {
            collateral.safeTransfer(msg.sender, colToWithdraw);
            emit Withdrawn(msg.sender, colToWithdraw);
        }

        if (repayAmount > 0) {
            emit Repaid(msg.sender, repayAmount);
        }
    }

    /**
     * @notice Liquidate an undercollateralized position
     * @param user Address of the position to liquidate
     */
    function liquidate(address user) external nonReentrant whenNotPaused {
        require(user != address(0), "Vault: invalid user");
        Position storage pos = positions[user];

        require(pos.debtAmount > 0, "Vault: no debt to liquidate");

        // Check if position is underwater (CR < 140%)
        uint256 currentRatio = _getCollateralRatio(
            pos.collateralAmount,
            pos.debtAmount
        );

        require(
            currentRatio < LIQUIDATION_THRESHOLD,
            "Vault: position is healthy"
        );

        uint256 debtToRepay = pos.debtAmount;
        uint256 collateralToSeize = pos.collateralAmount;

        // Liquidator pays off debt
        require(
            audb.transferFrom(msg.sender, address(this), debtToRepay),
            "Vault: transfer failed"
        );
        audb.burn(address(this), debtToRepay);

        // Liquidator receives collateral + 5% bonus
        // Note: Bonus comes from user's over-collateralization
        uint256 collateralReward = (collateralToSeize *
            (100 + LIQUIDATION_BONUS)) / 100;

        // Ensure we don't overpay (cap at actual collateral)
        if (collateralReward > collateralToSeize) {
            collateralReward = collateralToSeize;
        }

        collateral.safeTransfer(msg.sender, collateralReward);

        // Clear position
        delete positions[user];

        emit Liquidated(user, msg.sender, debtToRepay, collateralReward);
    }

    /**
     * @notice Get collateral ratio for a position
     * @param colAmount Collateral amount (6 decimals)
     * @param debtAmount Debt amount (18 decimals)
     * @return Collateral ratio (100 = 100%)
     */
    function _getCollateralRatio(
        uint256 colAmount,
        uint256 debtAmount
    ) internal pure returns (uint256) {
        if (debtAmount == 0) return type(uint256).max;

        // Normalize USDC to 18 decimals: colAmount * 1e12
        // Ratio = (collateral / debt) * 100
        return (colAmount * 1e12 * 100) / debtAmount;
    }

    /**
     * @notice Check if position maintains minimum health
     * @dev Enforces 150% minimum collateralization ratio
     * @param colAmount Collateral amount (6 decimals)
     * @param debtAmount Debt amount (18 decimals)
     * @return true if position is healthy (>= 150% CR)
     */
    function _checkHealth(
        uint256 colAmount,
        uint256 debtAmount
    ) internal pure returns (bool) {
        if (debtAmount == 0) return true;

        // 150% ratio: collateral value >= 1.5 * debt value
        // Assuming 1 USDC ≈ 1 AUD (simplified for stability)
        // (colAmount * 1e12 * 100) / debtAmount >= 150
        uint256 ratio = (colAmount * 1e12 * 100) / debtAmount;
        return ratio >= MIN_COLLATERAL_RATIO;
    }

    /**
     * @notice Get position health for a user
     * @param user User address
     * @return collateral ratio (100 = 100%)
     */
    function getPositionHealth(address user) external view returns (uint256) {
        Position storage pos = positions[user];
        return _getCollateralRatio(pos.collateralAmount, pos.debtAmount);
    }

    /**
     * @notice Pause vault operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause vault operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
