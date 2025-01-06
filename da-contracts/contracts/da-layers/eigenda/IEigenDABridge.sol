// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IImplementation} from "./IImplementation.sol";

interface IEigenDABridge {
    // solhint-disable-next-line gas-struct-packing

    struct MerkleProofInput {
        bytes32 batchRoot;
        bytes32 leaf;
        uint256 index;
        bytes inclusionProof;
    }

    function implementation() external view returns (IImplementation implementation);
    function verifyBlobLeaf(MerkleProofInput calldata input) external view returns (bool);
}
