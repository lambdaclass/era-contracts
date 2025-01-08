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

    struct QuorumBlobParam {
        uint8 quorumNumber;
        uint8 adversaryThresholdPercentage;
        uint8 confirmationThresholdPercentage; 
        uint32 chunkLength; 
    }

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    struct BlobHeader {
        G1Point commitment; 
        uint32 dataLength; 
        QuorumBlobParam[] quorumBlobParams; 
    }

    struct MerkleProofInput {
        BlobHeader blobHeader;
        BlobVerificationProof blobVerificationProof;
    }

    function implementation() external view returns (IImplementation implementation);
    function verifyBlobLeaf(MerkleProofInput calldata input) external view returns (bool);
}
