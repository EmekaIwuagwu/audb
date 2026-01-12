// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "./AUDB.sol";
import "./LiquidityManager.sol"; // For ILiquidityManager
import "./interfaces/IJoeRouter02.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Rebalancer is Ownable, ReentrancyGuard {
    IPyth public pyth;
    AUDB public audb;
    ILiquidityManager public liquidityManager;
    IJoeRouter02 public router;

    bytes32 public audUsdPriceId;
    address public usdc;

    uint256 public peg = 1e18;
    uint256 public deviationThreshold = 0.01e18;

    event Rebalanced(uint256 marketPrice, uint256 adjustment, bool isExpansion);

    constructor(
        address _pyth,
        bytes32 _audUsdPriceId,
        address _audb,
        address _liquidityManager,
        address _router,
        address _usdc
    ) Ownable() {
        pyth = IPyth(_pyth);
        audUsdPriceId = _audUsdPriceId;
        audb = AUDB(_audb);
        liquidityManager = ILiquidityManager(_liquidityManager);
        router = IJoeRouter02(_router);
        usdc = _usdc;
    }

    function getOraclePrice() public view returns (uint256) {
        PythStructs.Price memory price = pyth.getPriceUnsafe(audUsdPriceId);
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

    function rebalance() external onlyOwner nonReentrant {
        // Hybrid Price Check: Average of Oracle and DEX?
        // Or Oracle is source of truth, DEX is target.
        // We use Oracle for absolute peg.
        uint256 currentPrice = getOraclePrice();

        if (currentPrice > peg + deviationThreshold) {
            // Price High -> Expand Supply
            uint256 delta = currentPrice - peg;
            uint256 supply = audb.totalSupply();
            uint256 amountToMint = (delta * supply) / peg;

            // Mint to Rebalancer first
            audb.mint(address(this), amountToMint);

            // Approve LiquidityManager
            audb.approve(address(liquidityManager), amountToMint);

            // Call Manager to sell/LP
            liquidityManager.manageSupplyExpansion(amountToMint);

            emit Rebalanced(currentPrice, amountToMint, true);
        } else if (currentPrice < peg - deviationThreshold) {
            // Price Low -> Contract Supply
            uint256 delta = peg - currentPrice;
            uint256 supply = audb.totalSupply();
            uint256 targetBurn = (delta * supply) / peg;

            // Try to get tokens from Liquidity Manager
            uint256 burned = liquidityManager.manageSupplyContraction(
                targetBurn
            );

            if (burned > 0) {
                audb.burn(address(this), burned);
            }
            emit Rebalanced(currentPrice, burned, false);
        }
    }
}
