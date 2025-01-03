// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {IEigenDABridge} from "./IEigenDABridge.sol";
import {IVectorx} from "./IVectorx.sol";

abstract contract EigenDAAttestationLib {
    struct AttestationData {
        uint32 blockNumber;
        uint128 leafIndex;
    }

    IEigenDABridge public bridge;
    IVectorx public vectorx;

    /// @dev Mapping from attestation leaf to attestation data.
    /// It is necessary for recovery of the state from the onchain data.
    mapping(bytes32 => AttestationData) public attestations;

    error InvalidAttestationProof();

    constructor(IEigenDABridge _bridge) {
        bridge = _bridge;
        vectorx = bridge.vectorx();
    }

    function _attest(bytes memory input) internal virtual {
        if (!bridge.verifyBlobLeaf(input)) revert InvalidAttestationProof();
        /*attestations[input.leaf] = AttestationData(
            vectorx.rangeStartBlocks(input.rangeHash) + uint32(input.dataRootIndex) + 1,
            uint128(input.leafIndex)
        );*/
    }
}
