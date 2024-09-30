// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {EigenDARollupUtils} from "@eigenda/eigenda-utils/libraries/EigenDARollupUtils.sol";
import {IEigenDAServiceManager} from "@eigenda/eigenda-utils/interfaces/IEigenDAServiceManager.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

    function verifyBlob(
        BlobInfo calldata blobInfo
    ) external view {
        require(address(EIGEN_DA_SERVICE_MANAGER) != address(0), "EigenDAVerifier: EIGEN_DA_SERVICE_MANAGER not set");
        EigenDARollupUtils.verifyBlob(blobInfo.blobHeader, EIGEN_DA_SERVICE_MANAGER, blobInfo.blobVerificationProof);
    }
}
