// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IImplementation} from "./IImplementation.sol";

interface IEigenDABridge {
    // solhint-disable-next-line gas-struct-packing

    struct BatchHeader {
        bytes32 blobHeadersRoot;
        bytes quorumNumbers; 
        bytes signedStakeForQuorums; 
        uint32 referenceBlockNumber;
    }

    struct BatchMetadata {
        BatchHeader batchHeader; 
        bytes32 signatoryRecordHash; 
        uint32 confirmationBlockNumber; 
    }

    struct BlobVerificationProof {
        uint32 batchId;
        uint32 blobIndex;
        BatchMetadata batchMetadata;
        bytes inclusionProof;
        bytes quorumIndices;
    }

    struct MerkleProofInput {
        bytes32 leaf;
        BlobVerificationProof blobVerificationProof;
    }

    function implementation() external view returns (IImplementation implementation);
    function verifyBlobLeaf(MerkleProofInput calldata input) external view returns (bool);
}
