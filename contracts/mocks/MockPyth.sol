// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

contract MockPyth {
    PythStructs.Price public storedPrice;

    function setPrice(int64 price, int32 expo) external {
        storedPrice = PythStructs.Price({
            price: price,
            conf: 0,
            expo: expo,
            publishTime: uint64(block.timestamp)
        });
    }

    function getPriceUnsafe(
        bytes32 /* id */
    ) external view returns (PythStructs.Price memory) {
        return storedPrice;
    }
}
