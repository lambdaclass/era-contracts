// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IEigenDABridge} from "./IEigenDABridge.sol";
import {IVectorx} from "./IVectorx.sol";
import {DummyVectorX} from "./DummyVectorX.sol";

contract DummyEigenDABridge is IEigenDABridge {
    IVectorx public vectorxContract;

    constructor() {
        vectorxContract = new DummyVectorX();
    }

    function vectorx() external view returns (IVectorx) {
        return vectorxContract;
    }

    function verifyBlobLeaf(bytes calldata) external view returns (bool) {
        return true;
    }
}
