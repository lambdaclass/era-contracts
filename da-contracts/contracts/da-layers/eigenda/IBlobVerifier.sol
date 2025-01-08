// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IEigenDABridge} from "./IEigenDABridge.sol";

interface IBlobVerifier {
    function verifyBlobV1(
        IEigenDABridge.BlobHeader calldata blobHeader,
        IEigenDABridge.BlobVerificationProof calldata blobVerificationProof
    ) external view;
}
