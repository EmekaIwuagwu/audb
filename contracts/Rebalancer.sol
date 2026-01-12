// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./AUDB.sol";
import "./LiquidityManager.sol"; // For ILiquidityManager
import "./interfaces/IJoeRouter02.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Rebalancer - Algorithmic Stability Engine for AUDB
 * @notice Manages AUDB supply based on oracle price feeds
 * @dev Implements rate limiting, circuit breakers, and secure oracle integration
 */
contract Rebalancer is Ownable, ReentrancyGuard, Pausable {
    IPyth public pyth;
    AUDB public audb;
    ILiquidityManager public liquidityManager;
    IJoeRouter02 public router;

    bytes32 public audUsdPriceId;
    address public usdc;

    uint256 public peg = 1e18; // 1.00 AUD
    uint256 public deviationThreshold = 0.01e18; // 1%

    /// @notice Maximum price age in seconds
    uint256 public constant MAX_PRICE_AGE = 60;

    /// @notice Maximum confidence interval as percentage of price (1%)
    uint256 public constant MAX_CONFIDENCE_PERCENT = 1;

    /// @notice Minimum time between rebalances
    uint256 public constant MIN_REBALANCE_INTERVAL = 1 hours;

    /// @notice Maximum supply change per rebalance (10%)
    uint256 public constant MAX_SUPPLY_CHANGE_PERCENT = 10;

    /// @notice Circuit breaker: max price deviation (10x from peg)
    uint256 public constant MAX_PRICE_DEVIATION = 10;

    /// @notice Timestamp of last rebalance
    uint256 public lastRebalanceTime;

    /// @notice Emitted when supply is rebalanced
    event Rebalanced(
        uint256 marketPrice,
        uint256 adjustment,
        bool isExpansion,
        uint256 timestamp
    );

    /// @notice Emitted when circuit breaker is triggered
    event CircuitBreakerTriggered(uint256 price, uint256 deviation);

    /// @notice Emitted when parameters are updated
    event ParametersUpdated(uint256 newPeg, uint256 newThreshold);

    /**
     * @notice Initializes the Rebalancer contract
     * @dev Validates all constructor parameters
     * @param _pyth Pyth Network oracle address
     * @param _audUsdPriceId AUD/USD price feed ID
     * @param _audb AUDB token address
     * @param _liquidityManager LiquidityManager address
     * @param _router Trader Joe router address
     * @param _usdc USDC token address
     */
    constructor(
        address _pyth,
        bytes32 _audUsdPriceId,
        address _audb,
        address _liquidityManager,
        address _router,
        address _usdc
    ) Ownable() {
        require(_pyth != address(0), "Rebalancer: invalid Pyth address");
        require(_audb != address(0), "Rebalancer: invalid AUDB address");
        require(
            _liquidityManager != address(0),
            "Rebalancer: invalid LM address"
        );
        require(_router != address(0), "Rebalancer: invalid router address");
        require(_usdc != address(0), "Rebalancer: invalid USDC address");
        require(_audUsdPriceId != bytes32(0), "Rebalancer: invalid price ID");

        pyth = IPyth(_pyth);
        audUsdPriceId = _audUsdPriceId;
        audb = AUDB(_audb);
        liquidityManager = ILiquidityManager(_liquidityManager);
        router = IJoeRouter02(_router);
        usdc = _usdc;
    }

    /**
     * @notice Fetches secure oracle price with validation
     * @dev Validates price freshness and confidence intervals
     * @return Normalized price in 18 decimals
     */
    function getOraclePrice() public view returns (uint256) {
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            audUsdPriceId,
            MAX_PRICE_AGE
        );

        // Validate confidence interval
        require(price.price > 0, "Rebalancer: invalid price");
        uint256 confidence = uint256(uint64(price.conf));
        uint256 priceValue = uint256(int256(price.price));

        // Confidence must be less than 1% of price
        require(
            confidence * 100 <= priceValue * MAX_CONFIDENCE_PERCENT,
            "Rebalancer: price confidence too low"
        );

        return convertToUint(price, 18);
    }

    function getDexPrice() public view returns (uint256) {
        // Check AUDB -> USDC price on Trader Joe
        address[] memory path = new address[](2);
        path[0] = address(audb);
        path[1] = usdc;

        try router.getAmountsOut(1e18, path) returns (uint[] memory amounts) {
            // amounts[1] is USDC amount for 1 AUDB
            // Assuming USDC is 6 decimals, we need to scale to 18
            return amounts[1] * 1e12;
        } catch {
            return 0; // Fallback if no liquidity
        }
    }

    function convertToUint(
        PythStructs.Price memory price,
        uint8 targetDecimals
    ) private pure returns (uint256) {
        if (price.price < 0 || price.expo > 0 || price.expo < -255)
            revert("Invalid price");
        uint8 priceDecimals = uint8(uint32(-1 * price.expo));
        if (targetDecimals >= priceDecimals) {
            return
                uint256(int256(price.price)) *
                (10 ** uint256(targetDecimals - priceDecimals));
        } else {
            return
                uint256(int256(price.price)) /
                (10 ** uint256(priceDecimals - targetDecimals));
        }
    }

    /**
     * @notice Rebalances AUDB supply based on oracle price
     * @dev Implements circuit breakers, rate limiting, and supply caps
     */
    function rebalance() external onlyOwner nonReentrant whenNotPaused {
        // Rate limiting: enforce minimum interval between rebalances
        require(
            block.timestamp >= lastRebalanceTime + MIN_REBALANCE_INTERVAL,
            "Rebalancer: too soon to rebalance"
        );

        uint256 currentPrice = getOraclePrice();

        // Circuit breaker: halt if price deviation is extreme
        if (
            currentPrice > peg * MAX_PRICE_DEVIATION ||
            currentPrice < peg / MAX_PRICE_DEVIATION
        ) {
            _pause();
            emit CircuitBreakerTriggered(currentPrice, MAX_PRICE_DEVIATION);
            return;
        }

        lastRebalanceTime = block.timestamp;

        if (currentPrice > peg + deviationThreshold) {
            // Price High → Expand Supply
            uint256 delta = currentPrice - peg;
            uint256 supply = audb.totalSupply();
            uint256 amountToMint = (delta * supply) / peg;

            // Cap expansion at MAX_SUPPLY_CHANGE_PERCENT%
            uint256 maxMint = (supply * MAX_SUPPLY_CHANGE_PERCENT) / 100;
            if (amountToMint > maxMint) {
                amountToMint = maxMint;
            }

            // Mint to Rebalancer first
            audb.mint(address(this), amountToMint);

            // Approve LiquidityManager
            audb.approve(address(liquidityManager), amountToMint);

            // Call Manager to sell/LP
            liquidityManager.manageSupplyExpansion(amountToMint);

            emit Rebalanced(currentPrice, amountToMint, true, block.timestamp);
        } else if (currentPrice < peg - deviationThreshold) {
            // Price Low → Contract Supply
            uint256 delta = peg - currentPrice;
            uint256 supply = audb.totalSupply();
            uint256 targetBurn = (delta * supply) / peg;

            // Cap contraction at MAX_SUPPLY_CHANGE_PERCENT%
            uint256 maxBurn = (supply * MAX_SUPPLY_CHANGE_PERCENT) / 100;
            if (targetBurn > maxBurn) {
                targetBurn = maxBurn;
            }

            // Try to get tokens from Liquidity Manager
            uint256 burned = liquidityManager.manageSupplyContraction(
                targetBurn
            );

            if (burned > 0) {
                audb.burn(address(this), burned);
            }
            emit Rebalanced(currentPrice, burned, false, block.timestamp);
        }
    }
}
