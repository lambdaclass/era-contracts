// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IEigenDABridge} from "./IEigenDABridge.sol";
import {IImplementation} from "./IImplementation.sol";
import {DummyImplementation} from "./DummyImplementation.sol";

contract DummyEigenDABridge is IEigenDABridge {
    IImplementation public implementationContract;

    constructor() {
        implementationContract = new DummyImplementation();
    }

    function implementation() external view returns (IImplementation) {
        return implementationContract;
    }

    function verifyBlobLeaf(MerkleProofInput calldata merkleProof) external view returns (bool) {
        // Inspired by eigenlayer contracts Merkle.verifyInclusionKeccak
        // https://github.com/Layr-Labs/eigenlayer-contracts/blob/3f3f83bd194b3bdc77d06d8fe6b101fafc3bcfd5/src/contracts/libraries/Merkle.sol
        uint256 index = merkleProof.index;
        bytes memory inclusionProof = merkleProof.inclusionProof;
        require(inclusionProof.length % 32 == 0, "proof length not multiple of 32");
        bytes32 computedHash = merkleProof.leaf;
        uint256 length = inclusionProof.length;
        for (uint256 i = 32; i <= length; i += 32) {
            if (index % 2 == 0) {
                // if ith bit of index is 0, then computedHash is a left sibling
                assembly {
                    mstore(0x00, computedHash)
                    mstore(0x20, mload(add(inclusionProof, i)))
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            } else {
                // if ith bit of index is 1, then computedHash is a right sibling
                assembly {
                    mstore(0x00, mload(add(inclusionProof, i)))
                    mstore(0x20, computedHash)
                    computedHash := keccak256(0x00, 0x40)
                    index := div(index, 2)
                }
            }
        }
        require(computedHash == merkleProof.batchRoot, "invalid proof");
        return true;
    }
}
