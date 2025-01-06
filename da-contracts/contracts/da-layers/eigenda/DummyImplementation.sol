// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IImplementation} from "./IImplementation.sol";

contract DummyImplementation is IImplementation {
    function rangeStartBlocks(bytes32) external view returns (uint32 startBlock) {
        return 1;
    }
}
