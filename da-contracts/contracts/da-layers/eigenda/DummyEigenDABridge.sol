// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IEigenDABridge} from "./IEigenDABridge.sol";
import {IImplementation} from "./IImplementation.sol";
import {DummyImplementation} from "./DummyImplementation.sol";

contract DummyEigenDABridge is IEigenDABridge {
    IImplementation public implementationContract;

    constructor() {
        implementationContract = new DummyImplementation();
    }

    function implementation() external view returns (IImplementation) {
        return implementationContract;
    }

    function verifyBlobLeaf(bytes calldata) external view returns (bool) {
        return true;
    }
}
