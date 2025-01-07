// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IL1DAValidator, L1DAValidatorOutput} from "../../IL1DAValidator.sol";
import {ValL1DAWrongInputLength} from "../../DAContractsErrors.sol";
import {EigenDAAttestationLib} from "./EigenDAAttestationLib.sol";
import {IEigenDABridge} from "./IEigenDABridge.sol";

contract EigenDAL1Validator is IL1DAValidator, EigenDAAttestationLib {
    error InvalidValidatorOutputHash();

    constructor(IEigenDABridge _eigendaBridge) EigenDAAttestationLib(_eigendaBridge) {}

    function checkDA(
        uint256, // _chainId
        uint256, // _batchNumber
        bytes32, // _l2DAValidatorOutputHash, // TODO: Maybe we don't need this
        bytes calldata operatorDAInput,
        uint256 maxBlobsSupported
    ) external override returns (L1DAValidatorOutput memory output) {
        // TODO: Implement real validation logic.
        // For Validiums, we expect the operator to just provide the data for us.
        // We don't need to do any checks with regard to the l2DAValidatorOutputHash.
        if (operatorDAInput.length < 32) {
            revert ValL1DAWrongInputLength(operatorDAInput.length, 32);
        }
        bytes32 stateDiffHash = abi.decode(operatorDAInput[:32], (bytes32));

        output.stateDiffHash = stateDiffHash;

        IEigenDABridge.MerkleProofInput memory input = abi.decode(operatorDAInput[32:], (IEigenDABridge.MerkleProofInput));
        /*if (l2DAValidatorOutputHash != keccak256(abi.encodePacked(output.stateDiffHash, input.leaf))) 
            revert InvalidValidatorOutputHash();*/ //TODO: Maybe we don't need this
        _attest(input);

        output.blobsLinearHashes = new bytes32[](maxBlobsSupported);
        output.blobsOpeningCommitments = new bytes32[](maxBlobsSupported);
    }
}
