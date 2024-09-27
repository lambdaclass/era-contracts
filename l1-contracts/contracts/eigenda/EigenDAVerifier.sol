// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {EigenDARollupUtils} from "@eigenda/eigenda-utils/libraries/EigenDARollupUtils.sol";
import {IEigenDAServiceManager} from "@eigenda/eigenda-utils/interfaces/IEigenDAServiceManager.sol";

contract EigenDAVerifier {

    struct BlobInfo {
        IEigenDAServiceManager.BlobHeader blobHeader;
        EigenDARollupUtils.BlobVerificationProof blobVerificationProof;
    }

    IEigenDAServiceManager public immutable EIGEN_DA_SERVICE_MANAGER;

    constructor(address _eigenDAServiceManager) {
        EIGEN_DA_SERVICE_MANAGER = IEigenDAServiceManager(_eigenDAServiceManager);
    }

    function verifyBlob(
        BlobInfo calldata blobInfo
    ) external view {
        EigenDARollupUtils.verifyBlob(blobInfo.blobHeader, EIGEN_DA_SERVICE_MANAGER, blobInfo.blobVerificationProof);
    }
}
