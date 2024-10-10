// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {EigenDARollupUtils} from "@eigenda/eigenda-utils/libraries/EigenDARollupUtils.sol";
import {IEigenDAServiceManager} from "@eigenda/eigenda-utils/interfaces/IEigenDAServiceManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {BN254} from "eigenlayer-middleware/libraries/BN254.sol";

contract EigenDAVerifier is Ownable {
    struct BlobInfo {
        IEigenDAServiceManager.BlobHeader blobHeader;
        EigenDARollupUtils.BlobVerificationProof blobVerificationProof;
    }

    IEigenDAServiceManager public EIGEN_DA_SERVICE_MANAGER;

    constructor(address _initialOwner, address _eigenDAServiceManager) {
        _transferOwnership(_initialOwner);
        EIGEN_DA_SERVICE_MANAGER = IEigenDAServiceManager(_eigenDAServiceManager);
    }

    function setServiceManager(address _eigenDAServiceManager) external onlyOwner {
        EIGEN_DA_SERVICE_MANAGER = IEigenDAServiceManager(_eigenDAServiceManager);
    }

    function decodeBlobHeader(
        bytes calldata blobHeader
    ) internal pure returns (IEigenDAServiceManager.BlobHeader memory) {
        uint32 offset = 0;
        // Decode x
        uint32 xLen = uint32(bytes4(blobHeader[0:4]));
        uint256 x = uint256(bytes32(blobHeader[4:4 + xLen]));
        offset += 4 + xLen;
        // Decode y
        uint32 yLen = uint32(bytes4(blobHeader[offset:4 + offset]));
        uint256 y = uint256(bytes32(blobHeader[4 + offset:4 + offset + yLen]));
        offset += 4 + yLen;

        BN254.G1Point memory commitment = BN254.G1Point(x, y);
        // Decode dataLength
        uint32 dataLength = uint32(bytes4(blobHeader[offset:offset + 4]));
        offset += 4;

        // Decode quorumBlobParams
        uint32 quorumBlobParamsLen = uint32(bytes4(blobHeader[offset:offset + 4]));
        IEigenDAServiceManager.QuorumBlobParam[] memory quorumBlobParams = new IEigenDAServiceManager.QuorumBlobParam[](
            quorumBlobParamsLen
        );
        offset += 4;
        for (uint256 i = 0; i < quorumBlobParamsLen; i++) {
            quorumBlobParams[i].quorumNumber = uint8(uint32(bytes4(blobHeader[offset:offset + 4])));
            quorumBlobParams[i].adversaryThresholdPercentage = uint8(uint32(bytes4(blobHeader[offset + 4:offset + 8])));
            quorumBlobParams[i].confirmationThresholdPercentage = uint8(
                uint32(bytes4(blobHeader[offset + 8:offset + 12]))
            );
            quorumBlobParams[i].chunkLength = uint32(bytes4(blobHeader[offset + 12:offset + 16]));
            offset += 16;
        }
        return IEigenDAServiceManager.BlobHeader(commitment, dataLength, quorumBlobParams);
    }

    function decodeBatchHeader(
        bytes calldata batchHeader
    ) internal pure returns (IEigenDAServiceManager.BatchHeader memory) {
        uint32 offset = 0;
        // Decode blobHeadersRoot
        bytes32 blobHeadersRoot = bytes32(batchHeader[offset:offset + 32]);
        offset += 32;
        // Decode quorumNumbers
        uint32 quorumNumbersLen = uint32(bytes4(batchHeader[offset:offset + 4]));
        bytes memory quorumNumbers = batchHeader[offset + 4:offset + 4 + quorumNumbersLen];
        offset += 4 + quorumNumbersLen;
        // Decode signedStakeForQuorums
        uint32 signedStakeForQuorumsLen = uint32(bytes4(batchHeader[offset:offset + 4]));
        bytes memory signedStakeForQuorums = batchHeader[offset + 4:offset + 4 + signedStakeForQuorumsLen];
        offset += 4 + signedStakeForQuorumsLen;
        // Decode referenceBlockNumber
        uint32 referenceBlockNumber = uint32(bytes4(batchHeader[offset:offset + 4]));
        return
            IEigenDAServiceManager.BatchHeader(
                blobHeadersRoot,
                quorumNumbers,
                signedStakeForQuorums,
                referenceBlockNumber
            );
    }

    function decodeBatchMetadata(
        bytes calldata batchMetadata
    ) internal pure returns (IEigenDAServiceManager.BatchMetadata memory) {
        uint32 offset = 0;
        // Decode batchHeader
        uint32 batchHeaderLen = uint32(bytes4(batchMetadata[offset:offset + 4]));
        IEigenDAServiceManager.BatchHeader memory batchHeader = decodeBatchHeader(
            batchMetadata[offset + 4:offset + 4 + batchHeaderLen]
        );
        offset += 4 + batchHeaderLen;
        // Decode signatoryRecordHash
        bytes32 signatoryRecordHash = bytes32(batchMetadata[offset:offset + 32]);
        offset += 32;
        // Decode confirmationBlockNumber
        uint32 confirmationBlockNumber = uint32(bytes4(batchMetadata[offset:offset + 4]));
        return IEigenDAServiceManager.BatchMetadata(batchHeader, signatoryRecordHash, confirmationBlockNumber);
    }

    function decodeBlobVerificationProof(
        bytes calldata blobVerificationProof
    ) internal pure returns (EigenDARollupUtils.BlobVerificationProof memory) {
        // Decode batchId
        uint32 batchId = uint32(bytes4(blobVerificationProof[:4]));
        // Decode blobIndex
        uint32 blobIndex = uint32(bytes4(blobVerificationProof[4:8]));
        // Decode batchMetadata
        uint32 batchMetadataLen = uint32(bytes4(blobVerificationProof[8:12]));
        IEigenDAServiceManager.BatchMetadata memory batchMetadata = decodeBatchMetadata(
            blobVerificationProof[12:batchMetadataLen]
        );
        uint32 offset = 12 + batchMetadataLen;
        // Decode inclusionProof
        uint32 inclusionProofLen = uint32(bytes4(blobVerificationProof[offset:offset + 4]));
        bytes memory inclusionProof = blobVerificationProof[offset + 4:offset + 4 + inclusionProofLen];
        offset += 4 + inclusionProofLen;
        // Decode quorumIndexes
        uint32 quorumIndexesLen = uint32(bytes4(blobVerificationProof[offset:offset + 4]));
        bytes memory quorumIndexes = blobVerificationProof[offset + 4:offset + 4 + quorumIndexesLen];

        return
            EigenDARollupUtils.BlobVerificationProof(batchId, blobIndex, batchMetadata, inclusionProof, quorumIndexes);
    }

    function decodeBlobInfo(bytes calldata blobInfo) internal pure returns (BlobInfo memory) {
        uint32 blobHeaderLen = uint32(bytes4(blobInfo[:4]));
        IEigenDAServiceManager.BlobHeader memory blobHeader = decodeBlobHeader(blobInfo[4:blobHeaderLen]);
        EigenDARollupUtils.BlobVerificationProof memory blobVerificationProof = decodeBlobVerificationProof(
            blobInfo[blobHeaderLen:]
        );
        return BlobInfo(blobHeader, blobVerificationProof);
    }

    function verifyBlob(bytes calldata blobInfo) external view {
        BlobInfo memory blob = decodeBlobInfo(blobInfo);
        this._verifyBlob(blob);
    }

    function _verifyBlob(BlobInfo calldata blobInfo) external view {
        require(address(EIGEN_DA_SERVICE_MANAGER) != address(0), "EigenDAVerifier: EIGEN_DA_SERVICE_MANAGER not set");
        EigenDARollupUtils.verifyBlob(blobInfo.blobHeader, EIGEN_DA_SERVICE_MANAGER, blobInfo.blobVerificationProof);
    }
}
