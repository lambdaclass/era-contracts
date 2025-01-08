// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IEigenDABridge} from "./IEigenDABridge.sol";
import {IImplementation} from "./IImplementation.sol";
import {DummyImplementation} from "./DummyImplementation.sol";
import {IBlobVerifier} from "./IBlobVerifier.sol";

contract DummyEigenDABridge is IEigenDABridge {
    IImplementation public implementationContract;
    IBlobVerifier public eigenBlobVerifier;

    constructor(address _eigenBlobVerifier) {
        implementationContract = new DummyImplementation();
        eigenBlobVerifier = IBlobVerifier(_eigenBlobVerifier);
    }

    function implementation() external view returns (IImplementation) {
        return implementationContract;
    }

    function verifyBlobLeaf(MerkleProofInput calldata merkleProof) external view returns (bool) {
        eigenBlobVerifier.verifyBlobV1(merkleProof.blobHeader, merkleProof.blobVerificationProof);
        return true;
    }
}
