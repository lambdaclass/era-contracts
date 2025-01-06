// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

interface IImplementation {
    function rangeStartBlocks(bytes32 rangeHash) external view returns (uint32 startBlock);
}
