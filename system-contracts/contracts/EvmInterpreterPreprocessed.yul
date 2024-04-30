object "EVMInterpreter" {
    code {
        /// @dev This function is used to get the initCode.
        /// @dev It assumes that the initCode has been passed via the calldata and so we use the pointer
        /// to obtain the bytecode.
        function getConstructorBytecode() {
            let bytecodeLengthOffset := BYTECODE_OFFSET()
            let bytecodeOffset := add(BYTECODE_OFFSET(), 32)

            loadCalldataIntoActivePtr()

            let size := getActivePtrDataSize()
            mstore(bytecodeLengthOffset, size)

            copyActivePtrData(bytecodeOffset, 0, size)
        }

        // Note that this function modifies EVM memory and does not restore it. It is expected that
        // it is the last called function during execution.
        function setDeployedCode(gasLeft, offset, len) {
            // This error should never be triggered
            // require(offset > 100, "Offset too small");

            mstore8(sub(offset, 100), 0xd9)
            mstore8(sub(offset, 99), 0xeb)
            mstore8(sub(offset, 98), 0x76)
            mstore8(sub(offset, 97), 0xb2)
            mstore(sub(offset, 96), gasLeft)
            mstore(sub(offset, 64), 0x40)
            mstore(sub(offset, 32), len)

            let success := call(gas(), DEPLOYER_SYSTEM_CONTRACT(), 0, sub(offset, 100), add(len, 100), 0, 0)

            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        }

        function padBytecode(offset, len) -> blobOffset, blobLen {
            blobOffset := sub(offset, 32)
            let trueLastByte := add(offset, len)

            mstore(blobOffset, len)
            // clearing out additional bytes
            mstore(trueLastByte, 0)
            mstore(add(trueLastByte, 32), 0)

            blobLen := add(len, 32)

            if iszero(eq(mod(blobLen, 32), 0)) {
                blobLen := add(blobLen, sub(32, mod(blobLen, 32)))
            }

            // Not it is divisible by 32, but we must make sure that the number of 32 byte words is odd
            if iszero(eq(mod(blobLen, 64), 32)) {
                blobLen := add(blobLen, 32)
            }
        }

        function validateCorrectBytecode(offset, len, gasToReturn) -> returnGas {
            if len {
                // let firstByte := shr(mload(offset), 248)
                // FIXME: Check this.
                let firstByte := shr(248, mload(offset))
                if eq(firstByte, 0xEF) {
                    revert(0, 0)
                }
            }

            let gasForCode := mul(len, 200)
            returnGas := chargeGas(gasToReturn, gasForCode)
        }

        function SYSTEM_CONTRACTS_OFFSET() -> offset {
            offset := 0x8000
        }
        
        function ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT() -> addr {
            addr := 0x0000000000000000000000000000000000008002
        }
        
        function NONCE_HOLDER_SYSTEM_CONTRACT() -> addr {
            addr := 0x0000000000000000000000000000000000008003
        }
        
        function DEPLOYER_SYSTEM_CONTRACT() -> addr {
            addr :=  0x0000000000000000000000000000000000008006
        }
        
        function CODE_ADDRESS_CALL_ADDRESS() -> addr {
            addr := 0x000000000000000000000000000000000000FFFE
        }
        
        function CODE_ORACLE_SYSTEM_CONTRACT() -> addr {
            addr := 0x0000000000000000000000000000000000008012
        }
        
        function EVM_GAS_MANAGER_CONTRACT() -> addr {   
            addr :=  0x0000000000000000000000000000000000008013
        }
        
        function CALLFLAGS_CALL_ADDRESS() -> addr {
            addr := 0x000000000000000000000000000000000000FFEF
        }
        
        function DEBUG_SLOT_OFFSET() -> offset {
            offset := mul(32, 32)
        }
        
        function LAST_RETURNDATA_SIZE_OFFSET() -> offset {
            offset := add(DEBUG_SLOT_OFFSET(), mul(5, 32))
        }
        
        function STACK_OFFSET() -> offset {
            offset := add(LAST_RETURNDATA_SIZE_OFFSET(), 32)
        }
        
        function BYTECODE_OFFSET() -> offset {
            offset := add(STACK_OFFSET(), mul(1024, 32))
        }
        
        function INF_PASS_GAS() -> inf {
            inf := 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        }
        
        function MAX_POSSIBLE_BYTECODE() -> max {
            max := 32000
        }
        
        function MEM_OFFSET() -> offset {
            offset := add(BYTECODE_OFFSET(), MAX_POSSIBLE_BYTECODE())
        }
        
        function MEM_OFFSET_INNER() -> offset {
            offset := add(MEM_OFFSET(), 32)
        }
        
        function MAX_POSSIBLE_MEM() -> max {
            max := 0x100000 // 1MB
        }
        
        function MAX_MEMORY_FRAME() -> max {
            max := add(MEM_OFFSET_INNER(), MAX_POSSIBLE_MEM())
        }
        
        // It is the responsibility of the caller to ensure that ip >= BYTECODE_OFFSET + 32
        function readIP(ip) -> opcode {
            // TODO: Why not do this at the beginning once instead of every time?
            let bytecodeLen := mload(BYTECODE_OFFSET())
        
            let maxAcceptablePos := add(add(BYTECODE_OFFSET(), bytecodeLen), 31)
            if gt(ip, maxAcceptablePos) {
                revert(0, 0)
            }
        
            opcode := and(mload(sub(ip, 31)), 0xff)
        }
        
        function readBytes(start, length) -> value {
            let max := add(start, length)
            for {} lt(start, max) { start := add(start, 1) } {
                let next_byte := readIP(start)
        
                value := or(shl(8, value), next_byte)
            }
        }
        
        function dupStackItem(sp, evmGas, position) -> newSp, evmGasLeft {
            evmGasLeft := chargeGas(evmGas, 3)
            let tempSp := sub(sp, mul(0x20, sub(position, 1)))
        
            if or(gt(tempSp, BYTECODE_OFFSET()), eq(tempSp, BYTECODE_OFFSET())) {
                revert(0, 0)
            }
        
            if lt(tempSp, STACK_OFFSET()) {
                revert(0, 0)
            }
        
            let dup := mload(tempSp)                    
        
            newSp := add(sp, 0x20)
            mstore(newSp, dup)
        }
        
        function swapStackItem(sp, evmGas, position) ->  evmGasLeft {
            evmGasLeft := chargeGas(evmGas, 3)
            let tempSp := sub(sp, mul(0x20, position))
        
            if or(gt(tempSp, BYTECODE_OFFSET()), eq(tempSp, BYTECODE_OFFSET())) {
                revert(0, 0)
            }
        
            if lt(tempSp, STACK_OFFSET()) {
                revert(0, 0)
            }
        
        
            let s2 := mload(sp)
            let s1 := mload(tempSp)                    
        
            mstore(sp, s1)
            mstore(tempSp, s2)
        }
        
        function popStackItem(sp) -> a, newSp {
            // We can not return any error here, because it would break compatibility
            if lt(sp, STACK_OFFSET()) {
                revert(0, 0)
            }
        
            a := mload(sp)
            newSp := sub(sp, 0x20)
        }
        
        function pushStackItem(sp, item) -> newSp {
            if or(gt(sp, BYTECODE_OFFSET()), eq(sp, BYTECODE_OFFSET())) {
                revert(0, 0)
            }
        
            newSp := add(sp, 0x20)
            mstore(newSp, item)
        }
        
        function getCodeAddress() -> addr {
            addr := verbatim_0i_1o("code_source")
        }
        
        function loadReturndataIntoActivePtr() {
            verbatim_0i_0o("return_data_ptr_to_active")
        }
        
        function loadCalldataIntoActivePtr() {
            verbatim_0i_0o("calldata_ptr_to_active")
        }
        
        function getActivePtrDataSize() -> size {
            size := verbatim_0i_1o("active_ptr_data_size")
        }
        
        function copyActivePtrData(_dest, _source, _size) {
            verbatim_3i_0o("active_ptr_data_copy", _dest, _source, _size)
        }
        
        function ptrAddIntoActive(_dest) {
            verbatim_1i_0o("active_ptr_add_assign", _dest)
        }
        
        function ptrShrinkIntoActive(_dest) {
            verbatim_1i_0o("active_ptr_shrink_assign", _dest)
        }
        
        function _getRawCodeHash(account) -> hash {
            // TODO: Unhardcode this selector
            mstore8(0, 0x4d)
            mstore8(1, 0xe2)
            mstore8(2, 0xe4)
            mstore8(3, 0x68)
            mstore(4, account)
        
            let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            hash := mload(0)
        }
        
        function _getCodeHash(account) -> hash {
            // function getCodeHash(uint256 _input) external view override returns (bytes32)
            // 0xe03fe177
            // TODO: Unhardcode this selector
            mstore8(0, 0xe0)
            mstore8(1, 0x3f)
            mstore8(2, 0xe1)
            mstore8(3, 0x77)
            mstore(4, account)
        
            let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            hash := mload(0)
        }
        
        function getIsStaticFromCallFlags() -> isStatic {
            isStatic := verbatim_0i_1o("get_global::call_flags")
            // TODO: make it a constnat
            isStatic := iszero(iszero(and(isStatic, 0x04)))
        }
        
        // Basically performs an extcodecopy, while returning the length of the bytecode.
        function _fetchDeployedCode(addr, _offset, _len) -> codeLen {
            let codeHash := _getRawCodeHash(addr)
        
            mstore(0, codeHash)
        
            let success := staticcall(gas(), CODE_ORACLE_SYSTEM_CONTRACT(), 0, 32, 0, 0)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            // The first word is the true length of the bytecode
            returndatacopy(0, 0, 32)
            codeLen := mload(0)
        
            if gt(_len, codeLen) {
                _len := codeLen
            }
        
            returndatacopy(_offset, 32, _len)
        }
        
        // Returns the length of the bytecode.
        function _fetchDeployedCodeLen(addr) -> codeLen {
            let codeHash := _getRawCodeHash(addr)
        
            mstore(0, codeHash)
        
            let success := staticcall(gas(), CODE_ORACLE_SYSTEM_CONTRACT(), 0, 32, 0, 0)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            // The first word is the true length of the bytecode
            returndatacopy(0, 0, 32)
            codeLen := mload(0)
        }
        
        function getDeployedBytecode() {
            let codeLen := _fetchDeployedCode(
                getCodeAddress(),
                add(BYTECODE_OFFSET(), 32),
                MAX_POSSIBLE_BYTECODE()
            )
        
            mstore(BYTECODE_OFFSET(), codeLen)
        }
        
        function consumeEvmFrame() -> passGas, isStatic, callerEVM {
            // function consumeEvmFrame() external returns (uint256 passGas, bool isStatic)
            // TODO: Unhardcode selector
            mstore8(0, 0x04)
            mstore8(1, 0xc1)
            mstore8(2, 0x4e)
            mstore8(3, 0x9e)
        
            let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 4, 0, 64)
        
            if iszero(success) {
                // Should never happen
                revert(0, 0)
            }
        
            passGas := mload(0)
            isStatic := mload(32)
        
            if iszero(eq(passGas, INF_PASS_GAS())) {
                callerEVM := true
            }
        }
        
        function chargeGas(prevGas, toCharge) -> gasRemaining {
            if lt(prevGas, toCharge) {
                revert(0, 0)
            }
        
            gasRemaining := sub(prevGas, toCharge)
        }
        
        function checkMemOverflow(location) {
            if gt(location, MAX_MEMORY_FRAME()) {
                revert(0, 0)
            }
        }
        
        // Note, that this function can overflow. It's up to the caller to ensure that it does not.
        function memCost(memSizeWords) -> gasCost {
            // The first term of the sum is the quadratic cost, the second one the linear one.
            gasCost := add(div(mul(memSizeWords, memSizeWords), 512), mul(3, memSizeWords))
        }
        
        // This function can overflow, it is the job of the caller to ensure that it does not.
        // The argument to this function is the offset into the memory region IN BYTES.
        function expandMemory(newSize) -> gasCost {
            let oldSizeInWords := mload(MEM_OFFSET())
        
            // The add 31 here before dividing is there to account for misaligned
            // memory expansions, where someone calls this with a newSize that is not
            // a multiple of 32. For instance, if someone calls it with an offset of 33,
            // the new size in words should be 2, not 1, but dividing by 32 will give 1.
            // Adding 31 solves it.
            let newSizeInWords := div(add(newSize, 31), 32)
        
            if gt(newSizeInWords, oldSizeInWords) {
                // TODO: Check this, it feels like there might be a more optimized way
                // of doing this cost calculation.
                let oldCost := memCost(oldSizeInWords)
                let newCost := memCost(newSizeInWords)
        
                gasCost := sub(newCost, oldCost)
                mstore(MEM_OFFSET(), newSizeInWords)
            }
        }
        
        // Essentially a NOP that will not get optimized away by the compiler
        function $llvm_NoInline_llvm$_unoptimized() {
            pop(1)
        }
        
        function printHex(value) {
            mstore(add(DEBUG_SLOT_OFFSET(), 0x20), 0x00debdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebde)
            mstore(add(DEBUG_SLOT_OFFSET(), 0x40), value)
            mstore(DEBUG_SLOT_OFFSET(), 0x4A15830341869CAA1E99840C97043A1EA15D2444DA366EFFF5C43B4BEF299681)
            $llvm_NoInline_llvm$_unoptimized()
        }
        
        function printString(value) {
            mstore(add(DEBUG_SLOT_OFFSET(), 0x20), 0x00debdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdf)
            mstore(add(DEBUG_SLOT_OFFSET(), 0x40), value)
            mstore(DEBUG_SLOT_OFFSET(), 0x4A15830341869CAA1E99840C97043A1EA15D2444DA366EFFF5C43B4BEF299681)
            $llvm_NoInline_llvm$_unoptimized()
        }
        
        function isSlotWarm(key) -> isWarm {
            // TODO: Unhardcode this selector 0x482d2e74
            mstore8(0, 0x48)
            mstore8(1, 0x2d)
            mstore8(2, 0x2e)
            mstore8(3, 0x74)
            mstore(4, key)
        
            let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 36, 0, 32)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            isWarm := mload(0)
        }
        
        function warmSlot(key,currentValue) -> isWarm, originalValue {
            // TODO: Unhardcode this selector 0xbdf78160
            mstore8(0, 0xbd)
            mstore8(1, 0xf7)
            mstore8(2, 0x81)
            mstore8(3, 0x60)
            mstore(4, key)
            mstore(36,currentValue)
        
            let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 68, 0, 64)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            isWarm := mload(0)
            originalValue := mload(32)
        }
        
        function getNewAddress(addr) -> newAddr {
            let digest, nonce, addressEncoded, nonceEncoded, nonceEncodedLength, listLength, listLengthEconded
        
            nonce := getNonce(addr)
        
            addressEncoded := and(
                add(addr, shl(160, 0x94)),
                0xffffffffffffffffffffffffffffffffffffffffff
            )
        
            nonceEncoded := nonce
            nonceEncodedLength := 1
            if iszero(nonce) {
                nonceEncoded := 128
            }
            // The nonce has 4 bytes
            if gt(nonce, 0xFFFFFF) {
                nonceEncoded := shl(32, 0x84)
                nonceEncoded := add(nonceEncoded, nonce)
                nonceEncodedLength := 5
            }
            // The nonce has 3 bytes
            if and(gt(nonce, 0xFFFF), lt(nonce, 0x1000000)) {
                nonceEncoded := shl(24, 0x83)
                nonceEncoded := add(nonceEncoded, nonce)
                nonceEncodedLength := 4
            }
            // The nonce has 2 bytes
            if and(gt(nonce, 0xFF), lt(nonce, 0x10000)) {
                nonceEncoded := shl(16, 0x82)
                nonceEncoded := add(nonceEncoded, nonce)
                nonceEncodedLength := 3
            }
            // The nonce has 1 byte and it's in [0x80, 0xFF]
            if and(gt(nonce, 0x7F), lt(nonce, 0x100)) {
                nonceEncoded := shl(8, 0x81)
                nonceEncoded := add(nonceEncoded, nonce)
                nonceEncodedLength := 2
            }
        
            listLength := add(21, nonceEncodedLength)
            listLengthEconded := add(listLength, 0xC0)
        
            let arrayLength := add(168, mul(8, nonceEncodedLength))
        
            digest := add(
                shl(arrayLength, listLengthEconded),
                add(
                    shl(
                        mul(8, nonceEncodedLength),
                        addressEncoded
                    ),
                    nonceEncoded
                )
            )
        
            mstore(0, shl(sub(248, arrayLength), digest))
        
            newAddr := and(
                keccak256(0, add(div(arrayLength, 8), 1)),
                0xffffffffffffffffffffffffffffffffffffffff
            )
        }
        
        function incrementNonce(addr) {
            mstore8(0, 0x30)
            mstore8(1, 0x63)
            mstore8(2, 0x95)
            mstore8(3, 0xc6)
            mstore(4, addr)
        
            let result := call(gas(), NONCE_HOLDER_SYSTEM_CONTRACT(), 0, 0, 36, 0, 0)
        
            if iszero(result) {
                revert(0, 0)
            }
        }
        
        function ensureAcceptableMemLocation(location) {
            if gt(location,MAX_POSSIBLE_MEM()) {
                revert(0,0) // Check if this is whats needed
            }
        }
        
        function addGasIfEvmRevert(isCallerEVM,offset,size,evmGasLeft) -> newOffset,newSize {
            newOffset := offset
            newSize := size
            if eq(isCallerEVM,1) {
                // include gas
                let previousValue := mload(sub(offset,32))
                mstore(sub(offset,32),evmGasLeft)
                //mstore(sub(offset,32),previousValue) // Im not sure why this is needed, it was like this in the solidity code,
                // but it appears to rewrite were we want to store the gas
        
                newOffset := sub(offset, 32)
                newSize := add(size, 32)
            }
        }
        
        function warmAddress(addr) -> isWarm {
            // TODO: Unhardcode this selector 0x8db2ba78
            mstore8(0, 0x8d)
            mstore8(1, 0xb2)
            mstore8(2, 0xba)
            mstore8(3, 0x78)
            mstore(4, addr)
        
            let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 36, 0, 32)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            isWarm := mload(0)
        }
        
        function getNonce(addr) -> nonce {
            mstore8(0, 0xfb)
            mstore8(1, 0x1a)
            mstore8(2, 0x9a)
            mstore8(3, 0x57)
            mstore(4, addr)
        
            let result := staticcall(gas(), NONCE_HOLDER_SYSTEM_CONTRACT(), 0, 36, 0, 32)
        
            if iszero(result) {
                revert(0, 0)
            }
        
            nonce := mload(0)
        }
        
        function _isEVM(_addr) -> isEVM {
            // bytes4 selector = ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT.isAccountEVM.selector; (0x8c040477)
            // function isAccountEVM(address _addr) external view returns (bool);
            // IAccountCodeStorage constant ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT = IAccountCodeStorage(
            //      address(SYSTEM_CONTRACTS_OFFSET + 0x02)
            // );
        
            mstore8(0, 0x8c)
            mstore8(1, 0x04)
            mstore8(2, 0x04)
            mstore8(3, 0x77)
            mstore(4, _addr)
        
            let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            isEVM := mload(0)
        }
        
        function _pushEVMFrame(_passGas, _isStatic) {
            // function pushEVMFrame(uint256 _passGas, bool _isStatic) external
            let selector := 0xead77156
        
            mstore8(0, 0xea)
            mstore8(1, 0xd7)
            mstore8(2, 0x71)
            mstore8(3, 0x56)
            mstore(4, _passGas)
            mstore(36, _isStatic)
        
            let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 68, 0, 0)
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        }
        
        function _popEVMFrame() {
            // function popEVMFrame() external
            // 0xe467d2f0
            let selector := 0xe467d2f0
        
            mstore8(0, 0xe4)
            mstore8(1, 0x67)
            mstore8(2, 0xd2)
            mstore8(3, 0xf0)
        
            let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 4, 0, 0)
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        }
        
        // Each evm gas is 5 zkEVM one
        // FIXME: change this variable to reflect real ergs : gas ratio
        function GAS_DIVISOR() -> gas_div { gas_div := 5 }
        function EVM_GAS_STIPEND() -> gas_stipend { gas_stipend := shl(30, 1) } // 1 << 30
        function OVERHEAD() -> overhead { overhead := 2000 }
        // From precompiles/CodeOracle
        function DECOMMIT_COST_PER_WORD() -> cost { cost := 4 }
        function UINT32_MAX() -> ret { ret := 4294967295 } // 2^32 - 1
        
        function _calcEVMGas(_zkevmGas) -> calczkevmGas {
            calczkevmGas := div(_zkevmGas, GAS_DIVISOR())
        }
        
        function getEVMGas() -> evmGas {
            let _gas := gas()
            let requiredGas := add(EVM_GAS_STIPEND(), OVERHEAD())
        
            if lt(sub(_gas,shl(30,1)), requiredGas) {
                // This cheks if enough zkevm gas was provided, we are substracting 2^30 since that's the stipend, 
                // and we need to make sure that the gas provided over that is enough for security reasons
                revert(0, 0)
            }
            evmGas := div(sub(_gas, requiredGas), GAS_DIVISOR())
        }
        
        function _getZkEVMGas(addr) -> zkevmGas {
            let byteSize := extcodesize(addr)
            zkevmGas := mul(byteSize, DECOMMIT_COST_PER_WORD())
            if gt(zkevmGas, UINT32_MAX()) {
                zkevmGas := UINT32_MAX()
            }
        }
        
        function _saveReturndataAfterEVMCall(_outputOffset, _outputLen) -> _gasLeft{
            let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()
            let rtsz := returndatasize()
        
            loadReturndataIntoActivePtr()
        
            // if (rtsz > 31)
            switch gt(rtsz, 31)
                case 0 {
                    // Unexpected return data.
                    _gasLeft := 0
                    _eraseReturndataPointer()
                }
                default {
                    returndatacopy(0, 0, 32)
                    _gasLeft := mload(0)
                    returndatacopy(_outputOffset, 32, _outputLen)
                    mstore(lastRtSzOffset, sub(rtsz, 32))
        
                    // Skip the returnData
                    ptrAddIntoActive(32)
                }
        }
        
        function _eraseReturndataPointer() {
            let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()
        
            let activePtrSize := getActivePtrDataSize()
            ptrShrinkIntoActive(and(activePtrSize, 0xFFFFFFFF))// uint32(activePtrSize)
            mstore(lastRtSzOffset, 0)
        }
        
        function _saveReturndataAfterZkEVMCall() {
            loadReturndataIntoActivePtr()
            let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()
        
            mstore(lastRtSzOffset, returndatasize())
        }
        
        function performStaticCall(oldSp,evmGasLeft) -> extraCost, sp {
            let gasToPass,addr, argsOffset, argsSize, retOffset, retSize
        
            gasToPass, sp := popStackItem(oldSp)
            addr, sp := popStackItem(sp)
            argsOffset, sp := popStackItem(sp)
            argsSize, sp := popStackItem(sp)
            retOffset, sp := popStackItem(sp)
            retSize, sp := popStackItem(sp)
        
            switch warmAddress(addr)
                case 0 { extraCost := 2600 }
                default { extraCost := 100 }
            {
                let maxExpand := add(retOffset, retSize)
                switch lt(maxExpand,add(argsOffset, argsSize))  // Check if this makes sense
                case 0 {
                    maxExpand := expandMemory(add(argsOffset, argsSize))
                }
                default {
                    maxExpand := expandMemory(maxExpand)
                }
                extraCost := add(extraCost,maxExpand)
            }
            let maxGasToPass := sub(evmGasLeft, shr(6, evmGasLeft)) // evmGasLeft >> 6 == evmGasLeft/64
            if gt(gasToPass, maxGasToPass) { 
                gasToPass := maxGasToPass
            }
        
            let frameGasLeft
            let success
            if _isEVM(addr) {
                _pushEVMFrame(gasToPass, true)
                // TODO Check the following comment from zkSync .sol.
                // We can not just pass all gas here to prevert overflow of zkEVM gas counter
                success := staticcall(gasToPass, addr, add(MEM_OFFSET_INNER(), argsOffset), argsSize, 0, 0)
        
                frameGasLeft := _saveReturndataAfterEVMCall(add(MEM_OFFSET_INNER(), retOffset), retSize)
                _popEVMFrame()
            }
        
            // zkEVM native
            if iszero(_isEVM(addr)) {
                gasToPass := _getZkEVMGas(addr)
                let zkevmGasBefore := gas()
                success := staticcall(gasToPass, addr, add(MEM_OFFSET_INNER(), argsOffset), argsSize, add(MEM_OFFSET_INNER(), retOffset), retSize)
                _saveReturndataAfterZkEVMCall()
        
                let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))
        
                frameGasLeft := 0
                if gt(gasToPass, gasUsed) {
                    frameGasLeft := sub(gasToPass, gasUsed)
                }
            }
            extraCost := add(extraCost,sub(gasToPass,frameGasLeft))
        
            sp := pushStackItem(sp, success)
        }
        function capGas(evmGasLeft,oldGasToPass) -> gasToPass {
            let maxGasToPass := sub(evmGasLeft, shr(6, evmGasLeft)) // evmGasLeft >> 6 == evmGasLeft/64
            gasToPass := oldGasToPass
            if gt(oldGasToPass, maxGasToPass) { 
                gasToPass := maxGasToPass
            }
        }
        function performCall(oldSp, evmGasLeft, isStatic) -> extraCost, sp {
            let gasToPass,addr,value,argsOffset,argsSize,retOffset,retSize
        
            gasToPass, sp := popStackItem(oldSp)
            addr, sp := popStackItem(sp)
            value, sp := popStackItem(sp)
            argsOffset, sp := popStackItem(sp)
            argsSize, sp := popStackItem(sp)
            retOffset, sp := popStackItem(sp)
            retSize, sp := popStackItem(sp)
        
        
            // static_gas = 0
            // dynamic_gas = memory_expansion_cost + code_execution_cost + address_access_cost + positive_value_cost + value_to_empty_account_cost
            // code_execution_cost is the cost of the called code execution (limited by the gas parameter).
            // If address is warm, then address_access_cost is 100, otherwise it is 2600. See section access sets.
            // If value is not 0, then positive_value_cost is 9000. In this case there is also a call stipend that is given to make sure that a basic fallback function can be called. 2300 is thus removed from the cost, and also added to the gas input.
            // If value is not 0 and the address given points to an empty account, then value_to_empty_account_cost is 25000. An account is empty if its balance is 0, its nonce is 0 and it has no code.
            
        
            switch warmAddress(addr)
                case 0 { extraCost := 2600 }
                default { extraCost := 100 }
            if gt(value, 0) {
                extraCost := add(extraCost,6700)
                gasToPass := add(gasToPass,2300)
            }
            if and(isAddrEmpty(addr), gt(value, 0)) {
                extraCost := add(extraCost,25000)
            }
            {
                let maxExpand := add(retOffset, retSize)
                switch lt(maxExpand,add(argsOffset, argsSize)) 
                case 0 {
                    maxExpand := expandMemory(add(argsOffset, argsSize))
                }
                default {
                    maxExpand := expandMemory(maxExpand)
                }
                extraCost := add(extraCost,maxExpand)
            }
            gasToPass := capGas(evmGasLeft,gasToPass)
        
            argsOffset := add(argsOffset,MEM_OFFSET_INNER())
            retOffset := add(retOffset,MEM_OFFSET_INNER())
            checkMemOverflow(argsOffset)
            checkMemOverflow(retOffset)
        
            let frameGasLeft
            let success
        
            if isStatic {
                if value {
                    revert(0, 0)
                }
                success, frameGasLeft:= _performStaticCall(
                    _isEVM(addr),
                    gasToPass,
                    addr,
                    argsOffset,
                    argsSize,
                    retOffset,
                    retSize
                )
            }
        
            if and(_isEVM(addr), iszero(isStatic)) {
                _pushEVMFrame(gasToPass, isStatic)
                success := call(gasToPass, addr, value, argsOffset, argsSize, 0, 0)
                frameGasLeft := _saveReturndataAfterEVMCall(retOffset, retSize)
                _popEVMFrame()
            }
        
            // zkEVM native
            if and(iszero(_isEVM(addr)), iszero(isStatic)) {
                gasToPass := _getZkEVMGas(addr)
                let zkevmGasBefore := gas()
                success := call(gasToPass, addr, value, argsOffset, argsSize, retOffset, retSize)
                _saveReturndataAfterZkEVMCall()
                let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))
        
                frameGasLeft := 0
                if gt(gasToPass, gasUsed) {
                    frameGasLeft := sub(gasToPass, gasUsed)
                }
            }
        
            extraCost := add(extraCost,sub(gasToPass,frameGasLeft))
            sp := pushStackItem(sp,success) 
        }
        
        function delegateCall(oldSp, oldIsStatic, evmGasLeft) -> sp, isStatic, extraCost {
            let addr, gasToPass, argsOffset, argsSize, retOffset, retSize
        
            sp := oldSp
            isStatic := oldIsStatic
        
            gasToPass, sp := popStackItem(sp)
            addr, sp := popStackItem(sp)
            argsOffset, sp := popStackItem(sp)
            argsSize, sp := popStackItem(sp)
            retOffset, sp := popStackItem(sp)
            retSize, sp := popStackItem(sp)
        
            if iszero(_isEVM(addr)) {
                revert(0, 0)
            }
        
            switch warmAddress(addr)
                case 0 { extraCost := 2600 }
                default { extraCost := 100 }
            {
                let maxExpand := add(retOffset, retSize)
                switch lt(maxExpand,add(argsOffset, argsSize)) 
                case 0 {
                    maxExpand := expandMemory(add(argsOffset, argsSize))
                }
                default {
                    maxExpand := expandMemory(maxExpand)
                }
                extraCost := add(extraCost,maxExpand)
            }
            gasToPass := capGas(evmGasLeft,gasToPass)
        
            // TODO: Do this
            // if warmAccount(addr) {
            //     extraCost = GAS_WARM_ACCESS;
            // } else {
            //     extraCost = GAS_COLD_ACCOUNT_ACCESS;
            // }
        
            _pushEVMFrame(gasToPass, isStatic)
            addr := delegatecall(
                // We can not just pass all gas here to prevert overflow of zkEVM gas counter
                gasToPass,
                addr,
                add(MEM_OFFSET_INNER(), argsOffset),
                argsSize,
                0,
                0
            )
        
            let frameGasLeft := _saveReturndataAfterEVMCall(add(MEM_OFFSET_INNER(), retOffset), retSize)
        
            _popEVMFrame()
        
            extraCost := add(extraCost,sub(gasToPass,frameGasLeft))
            sp := pushStackItem(sp, addr)
        }
        
        function getMessageCallGas (
            _value,
            _gas,
            _gasLeft,
            _memoryCost,
            _extraGas
        ) -> gasPlusExtra, gasPlusStipend {
            let callStipend := 2300
            if iszero(_value) {
                callStipend := 0
            }
        
            switch lt(_gasLeft, add(_extraGas, _memoryCost))
                case 0
                {
                    let _gasTemp := sub(sub(_gasLeft, _extraGas), _memoryCost)
                    // From the Tangerine Whistle fork, gas is capped at all but one 64th (remaining_gas / 64)
                    // of the remaining gas of the current context. If a call tries to send more, the gas is 
                    // changed to match the maximum allowed.
                    let maxGasToPass := sub(_gasTemp, shr(6, _gasTemp)) // _gas >> 6 == _gas/64
                    if gt(_gas, maxGasToPass) {
                        _gas := maxGasToPass
                    }
                    gasPlusExtra := add(_gas, _extraGas)
                    gasPlusStipend := add(_gas, callStipend)
                }
                default {
                    gasPlusExtra := add(_gas, _extraGas)
                    gasPlusStipend := add(_gas, callStipend)
                }
        }
        
        function _performStaticCall(
            _calleeIsEVM,
            _calleeGas,
            _callee,
            _inputOffset,
            _inputLen,
            _outputOffset,
            _outputLen
        ) ->  success, _gasLeft {
            if _calleeIsEVM {
                _pushEVMFrame(_calleeGas, true)
                // TODO Check the following comment from zkSync .sol.
                // We can not just pass all gas here to prevert overflow of zkEVM gas counter
                success := staticcall(_calleeGas, _callee, _inputOffset, _inputLen, 0, 0)
        
                _gasLeft := _saveReturndataAfterEVMCall(_outputOffset, _outputLen)
                _popEVMFrame()
            }
        
            // zkEVM native
            if iszero(_calleeIsEVM) {
                _calleeGas := _getZkEVMGas(_callee)
                let zkevmGasBefore := gas()
                success := staticcall(_calleeGas, _callee, _inputOffset, _inputLen, _outputOffset, _outputLen)
        
                _saveReturndataAfterZkEVMCall()
        
                let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))
        
                _gasLeft := 0
                if gt(_calleeGas, gasUsed) {
                    _gasLeft := sub(_calleeGas, gasUsed)
                }
            }
        }
        
        function isAddrEmpty(addr) -> isEmpty {
            isEmpty := 0
            if  and( and( 
                    iszero(balance(addr)), 
                    iszero(extcodesize(addr)) ),
                    iszero(getNonce(addr))
                ) {
                isEmpty := 1
            }
        }
        
        function _fetchConstructorReturnGas() -> gasLeft {
            //selector is 0x24e5ab4a
        
            mstore8(0, 0x24)
            mstore8(1, 0xe5)
            mstore8(2, 0xab)
            mstore8(3, 0x4a)
        
            let success := staticcall(gas(), DEPLOYER_SYSTEM_CONTRACT(), 0, 4, 0, 32)
        
            if iszero(success) {
                // This error should never happen
                revert(0, 0)
            }
        
            gasLeft := mload(0)
        }
        
        function genericCreate(addr, offset, size, sp, value, evmGasLeftOld) -> result, evmGasLeft {
            pop(warmAddress(addr))
        
            _eraseReturndataPointer()
        
            let gasForTheCall := capGas(evmGasLeftOld,INF_PASS_GAS())
        
            if lt(balance(addr),value) {
                revert(0,0)
            }
        
            let nonceNewAddr := getNonce(addr)
            let bytecodeNewAddr := extcodesize(addr)
            if or(gt(nonceNewAddr, 0), gt(bytecodeNewAddr, 0)) {
                incrementNonce(address())
                revert(0, 0)
            }
        
            offset := add(MEM_OFFSET_INNER(), offset)
        
            sp := pushStackItem(sp, mload(sub(offset, 0x80)))
            sp := pushStackItem(sp, mload(sub(offset, 0x60)))
            sp := pushStackItem(sp, mload(sub(offset, 0x40)))
            sp := pushStackItem(sp, mload(sub(offset, 0x20)))
        
            // Selector
            mstore(sub(offset, 0x80), 0x5b16a23c)
            // Arg1: address
            mstore(sub(offset, 0x60), addr)
            // Arg2: init code
            // Where the arg starts (third word)
            mstore(sub(offset, 0x40), 0x40)
            // Length of the init code
            mstore(sub(offset, 0x20), size)
        
            _pushEVMFrame(gasForTheCall, false)
        
            result := call(INF_PASS_GAS(), DEPLOYER_SYSTEM_CONTRACT(), value, sub(offset, 0x64), add(size, 0x64), 0, 0)
        
            let gasLeft
            switch result
                case 0 {
                    gasLeft := _saveReturndataAfterEVMCall(0, 0)
                }
                default {
                    gasLeft := _fetchConstructorReturnGas()
                }
                
            let gasUsed := sub(gasForTheCall, gasLeft)
            evmGasLeft := chargeGas(evmGasLeftOld, gasUsed)
        
            _popEVMFrame()
        
            incrementNonce(address())
        
            let back
        
            back, sp := popStackItem(sp)
            mstore(sub(offset, 0x20), back)
            back, sp := popStackItem(sp)
            mstore(sub(offset, 0x40), back)
            back, sp := popStackItem(sp)
            mstore(sub(offset, 0x60), back)
            back, sp := popStackItem(sp)
            mstore(sub(offset, 0x80), back)
        }
        

        function simulate(
            isCallerEVM,
            evmGasLeft,
            isStatic,
        ) -> returnOffset, returnLen, retGasLeft {

            returnOffset := MEM_OFFSET_INNER()
            returnLen := 0

            // stack pointer - index to first stack element; empty stack = -1
            let sp := sub(STACK_OFFSET(), 32)
            // instruction pointer - index to next instruction. Not called pc because it's an
            // actual yul/evm instruction.
            let ip := add(BYTECODE_OFFSET(), 32)
            let opcode
            
            for { } true { } {
                opcode := readIP(ip)
            
                ip := add(ip, 1)
            
                switch opcode
                case 0x00 { // OP_STOP
                    break
                }
                case 0x01 { // OP_ADD
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, add(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x02 { // OP_MUL
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, mul(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x03 { // OP_SUB
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sub(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x04 { // OP_DIV
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, div(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x05 { // OP_SDIV
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sdiv(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x06 { // OP_MOD
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, mod(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x07 { // OP_SMOD
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, smod(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x16 { // OP_AND
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, and(a,b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x17 { // OP_OR
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, or(a,b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x0A { // OP_EXP
                    let a, exponent
            
                    a, sp := popStackItem(sp)
                    exponent, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, exp(a, exponent))
            
                    let expSizeByte := 0
                    if exponent {
                        expSizeByte := div(add(exponent, 256), 256)
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, add(10, mul(50, expSizeByte)))
                }
                case 0x0B { // OP_SIGNEXTEND
                    let b, x
            
                    b, sp := popStackItem(sp)
                    x, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, signextend(b, x))
            
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x08 { // OP_ADDMOD
                    let a, b, N
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
                    N, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, addmod(a, b, N))
            
                    evmGasLeft := chargeGas(evmGasLeft, 8)
                }
                case 0x09 { // OP_MULMOD
                    let a, b, N
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
                    N, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, mulmod(a, b, N))
            
                    evmGasLeft := chargeGas(evmGasLeft, 8)
                }
                case 0x10 { // OP_LT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, lt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x11 { // OP_GT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, gt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x12 { // OP_SLT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, slt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x13 { // OP_SGT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sgt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x14 { // OP_EQ
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, eq(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x15 { // OP_ISZERO
                    let a
            
                    a, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, iszero(a))
            
                    //evmGasLeft := chargeGas(evmGasLeft, 3) TODO: Add this back
                }
                case 0x18 { // OP_XOR
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, xor(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x19 { // OP_NOT
                    let a
            
                    a, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, not(a))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1A { // OP_BYTE
                    let i, x
            
                    i, sp := popStackItem(sp)
                    x, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, byte(i, x))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1B { // OP_SHL
                    let shift, value
            
                    shift, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, shl(shift, value))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1C { // OP_SHR
                    let shift, value
            
                    shift, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, shr(shift, value))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1D { // OP_SAR
                    let shift, value
            
                    shift, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sar(shift, value))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
            
                case 0x20 { // OP_KECCAK256
                    let offset, size
            
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, keccak256(add(MEM_OFFSET_INNER(), offset), size))
            
                    // When an offset is first accessed (either read or write), memory may trigger 
                    // an expansion, which costs gas.
                    // dynamic_gas = 6 * minimum_word_size + memory_expansion_cost
                    // minimum_word_size = (size + 31) / 32
                    let minWordSize := shr(5,add(size, 31))
                    let dynamicGas := add(mul(6, minWordSize), expandMemory(add(offset, size)))
                    let usedGas := add(30, dynamicGas)
                    evmGasLeft := chargeGas(evmGasLeft, usedGas)
                }
                case 0x30 { // OP_ADDRESS
                    sp := pushStackItem(sp, address())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x31 { // OP_BALANCE
                    let addr
            
                    addr, sp := popStackItem(sp)
            
                    let wasWarm := warmAddress(addr)
            
                    sp := pushStackItem(sp, balance(addr))
            
                    switch wasWarm
                    case 0 { evmGasLeft := chargeGas(evmGasLeft, 2600) }
                    default { evmGasLeft := chargeGas(evmGasLeft, 100) }
                }
                case 0x32 { // OP_ORIGIN
                    sp := pushStackItem(sp, origin())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x33 { // OP_CALLER
                    sp := pushStackItem(sp, caller())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x34 { // OP_CALLVALUE
                    sp := pushStackItem(sp, callvalue())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x35 { // OP_CALLDATALOAD
                    let i
            
                    i, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, calldataload(i))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x36 { // OP_CALLDATASIZE
                    sp := pushStackItem(sp, calldatasize())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x37 { // OP_CALLDATACOPY
                    let destOffset, offset, size
            
                    destOffset, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
            
                    checkMemOverflow(add(add(destOffset,MEM_OFFSET_INNER()), size))
            
                    evmGasLeft := chargeGas(evmGasLeft, expandMemory(add(destOffset, size)))
                    let minWordSize := shr(5,add(size, 31))
                    evmGasLeft := chargeGas(evmGasLeft, mul(3, minWordSize))
            
                    calldatacopy(add(MEM_OFFSET_INNER(), destOffset), offset, size)
                }
                case 0x38 { // OP_CODESIZE
                    let bytecodeLen := mload(BYTECODE_OFFSET())
                    sp := pushStackItem(sp, bytecodeLen)
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x39 { // OP_CODECOPY
                    let bytecodeLen := mload(BYTECODE_OFFSET())
                    let dst, offset, len
            
                    dst, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    len, sp := popStackItem(sp)
            
                    // dynamic_gas = 3 * minimum_word_size + memory_expansion_cost
                    // let minWordSize := div(add(len, 31), 32) Used inside the mul
                    let dynamicGas := add(mul(3, div(add(len, 31), 32)), expandMemory(add(offset, len)))
                    evmGasLeft := chargeGas(evmGasLeft, add(3, dynamicGas))
            
                    let end := len
                    if lt(bytecodeLen, len) {
                        end := bytecodeLen
                    }
            
                    for { let i := 0 } lt(i, end) { i := add(i, 1) } {
                        mstore8(
                            add(MEM_OFFSET_INNER(), add(dst, i)),
                            shr(248, mload(add(BYTECODE_OFFSET(), add(32, add(offset, i)))))
                        )
                    }
                    for { let i := end } lt(i, len) { i := add(i, 1) } {
                        mstore8(add(MEM_OFFSET_INNER(), add(dst, i)), 0)
                    }
                }
                case 0x3A { // OP_GASPRICE
                    sp := pushStackItem(sp, gasprice())
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x3B { // OP_EXTCODESIZE
                    let addr
                    addr, sp := popStackItem(sp)
            
                    // Check if its warm or cold
                    switch warmAddress(addr)
                        case true {
                            evmGasLeft := chargeGas(evmGasLeft, 100)
                        }
                        default {
                            evmGasLeft := chargeGas(evmGasLeft, 2600)
                        }
            
                    // TODO: check, the .sol uses extcodesize directly, but it doesnt seem to work
                    // if a contract is created it works, but if the address is a zkSync's contract
                    // what happens?
                    switch _isEVM(addr) 
                        case 0  { sp := pushStackItem(sp, extcodesize(addr)) }
                        default { sp := pushStackItem(sp, _fetchDeployedCodeLen(addr)) }
                }
                case 0x3C { // OP_EXTCODECOPY
                    let addr, dest, offset, len
                    addr, sp := popStackItem(sp)
                    dest, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    len, sp := popStackItem(sp)
            
                    // Check if its warm or cold
                    // minimum_word_size = (size + 31) / 32
                    // static_gas = 0
                    // dynamic_gas = 3 * minimum_word_size + memory_expansion_cost + address_access_cost
                    let dynamicGas
                    switch warmAddress(addr)
                        case true {
                            dynamicGas := 100
                        }
                        default {
                            dynamicGas := 2600
                        }
            
                    dynamicGas := add(dynamicGas, add(mul(3, shr(5, add(len, 31))), expandMemory(add(offset, len))))
                    evmGasLeft := chargeGas(evmGasLeft, dynamicGas)
            
                    // TODO: Check if Zeroing out the memory is necessary
                    let _lastByte := add(dest, len)
                    for {let i := dest} lt(i, _lastByte) { i := add(i, 1) } {
                        mstore8(i, 0)
                    }
                    // Gets the code from the addr
                    pop(_fetchDeployedCode(addr, add(offset, MEM_OFFSET_INNER()), len))
                }
                case 0x3D { // OP_RETURNDATASIZE
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    let rdz := mload(LAST_RETURNDATA_SIZE_OFFSET())
                    sp := pushStackItem(sp, rdz)
                }
                case 0x3E { // OP_RETURNDATACOPY
                    let dest, offset, len
                    dest, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    len, sp := popStackItem(sp)
            
            
                    // TODO: check if these conditions are met
                    // The addition offset + size overflows.
                    // offset + size is larger than RETURNDATASIZE.
                    if gt(add(offset, len), LAST_RETURNDATA_SIZE_OFFSET()) {
                        revert(0, 0)
                    }
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), len))
            
                    // minimum_word_size = (size + 31) / 32
                    // dynamic_gas = 6 * minimum_word_size + memory_expansion_cost
                    // static_gas = 0
                    let dynamicGas := add(mul(6, shr(5,add(len, 31))), expandMemory(add(offset, len)))
                    evmGasLeft := chargeGas(evmGasLeft, add(3, dynamicGas))
            
                    copyActivePtrData(add(MEM_OFFSET_INNER(), dest), offset, len)
                }
                case 0x3F { // OP_EXTCODEHASH
                    let addr
                    addr, sp := popStackItem(sp)
            
            
                    switch warmAddress(addr)
                        case 0 { 
                            evmGasLeft := chargeGas(evmGasLeft,2600) 
                        }
                        default { 
                            evmGasLeft := chargeGas(evmGasLeft,100) 
                        }
            
                    sp := pushStackItem(sp, extcodehash(addr))
                }
                case 0x40 { // OP_BLOCKHASH
                    let blockNumber
                    blockNumber, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 20)
                    sp := pushStackItem(sp, blockhash(blockNumber))
                }
                case 0x41 { // OP_COINBASE
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, coinbase())
                }
                case 0x42 { // OP_TIMESTAMP
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, timestamp())
                }
                case 0x43 { // OP_NUMBER
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, number())
                }
                case 0x44 { // OP_PREVRANDAO
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, prevrandao())
                }
                case 0x45 { // OP_GASLIMIT
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, gaslimit())
                }
                case 0x46 { // OP_CHAINID
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, chainid())
                }
                case 0x47 { // OP_SELFBALANCE
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                    sp := pushStackItem(sp, selfbalance())
                }
                case 0x48 { // OP_BASEFEE
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, basefee())
                }
                case 0x50 { // OP_POP
                    let _y
            
                    _y, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x51 { // OP_MLOAD
                    let offset
            
                    offset, sp := popStackItem(sp)
            
                    let expansionGas := expandMemory(offset) // TODO: add +32 here
            
                    let memValue := mload(add(MEM_OFFSET_INNER(), offset))
                    sp := pushStackItem(sp, memValue)
                    evmGasLeft := chargeGas(evmGasLeft, add(3, expansionGas))
                }
                case 0x52 { // OP_MSTORE
                    let offset, value
            
                    offset, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    let expansionGas := expandMemory(offset) // TODO: add +32 here
            
                    mstore(add(MEM_OFFSET_INNER(), offset), value)
                    evmGasLeft := chargeGas(evmGasLeft, add(3, expansionGas))
                }
                case 0x53 { // OP_MSTORE8
                    let offset, value
            
                    offset, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    let expansionGas := expandMemory(offset) // TODO: add +1 here
            
                    mstore8(add(MEM_OFFSET_INNER(), offset), value)
                    evmGasLeft := chargeGas(evmGasLeft, add(3, expansionGas))
                }
                // NOTE: We don't currently do full jumpdest validation
                // (i.e. validating a jumpdest isn't in PUSH data)
                case 0x56 { // OP_JUMP
                    let counter
            
                    counter, sp := popStackItem(sp)
            
                    ip := add(add(BYTECODE_OFFSET(), 32), counter)
            
                    evmGasLeft := chargeGas(evmGasLeft, 8)
            
                    // Check next opcode is JUMPDEST
                    let nextOpcode := readIP(ip)
                    if iszero(eq(nextOpcode, 0x5B)) {
                        revert(0, 0)
                    }
                }
                case 0x57 { // OP_JUMPI
                    let counter, b
            
                    counter, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 10)
            
                    if iszero(b) {
                        continue
                    }
            
                    ip := add(add(BYTECODE_OFFSET(), 32), counter)
            
                    // Check next opcode is JUMPDEST
                    let nextOpcode := readIP(ip)
                    if iszero(eq(nextOpcode, 0x5B)) {
                        revert(0, 0)
                    }
                }
                case 0x54 { // OP_SLOAD
                    let key,value,isWarm
            
                    key, sp := popStackItem(sp)
            
                    isWarm := isSlotWarm(key)
                    switch isWarm
                    case 0 { evmGasLeft := chargeGas(evmGasLeft,2100) }
                    default { evmGasLeft := chargeGas(evmGasLeft,100) }
            
                    value := sload(key)
            
                    sp := pushStackItem(sp,value)
                }
                case 0x55 { // OP_SSTORE
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let key, value,gasSpent
            
                    key, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    {
                        // Here it is okay to read before we charge since we known anyway that
                        // the context has enough funds to compensate at least for the read.
                        // Im not sure if we need this before: require(gasLeft > GAS_CALL_STIPEND);
                        let currentValue := sload(key)
                        let wasWarm,originalValue := warmSlot(key,currentValue)
                        gasSpent := 100
                        if and(not(eq(value,currentValue)),eq(originalValue,currentValue)) {
                            switch originalValue
                            case 0 { gasSpent := 20000}
                            default { gasSpent := 2900}
                        }
                        if iszero(wasWarm) {
                            gasSpent := add(gasSpent,2100)
                        }
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, gasSpent) //gasSpent
                    sstore(key, value)
                }
                case 0x59 { // OP_MSIZE
                    let size
                    evmGasLeft := chargeGas(evmGasLeft,2)
            
                    size := mload(MEM_OFFSET())
                    size := shl(5,size)
                    sp := pushStackItem(sp,size)
            
                }
                case 0x58 { // OP_PC
                    // PC = ip - 32 (bytecode size) - 1 (current instruction)
                    sp := pushStackItem(sp, sub(sub(ip, BYTECODE_OFFSET()), 33))
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x5A { // OP_GAS
                    evmGasLeft := chargeGas(evmGasLeft, 2)
            
                    sp := pushStackItem(sp, evmGasLeft)
                }
                case 0x5B { // OP_JUMPDEST
                    evmGasLeft := chargeGas(evmGasLeft, 1)
                }
                case 0x5F { // OP_PUSH0
                    let value := 0
            
                    sp := pushStackItem(sp, value)
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x60 { // OP_PUSH1
                    let value := readBytes(ip,1)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 1)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x61 { // OP_PUSH2
                    let value := readBytes(ip,2)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 2)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }     
                case 0x62 { // OP_PUSH3
                    let value := readBytes(ip,3)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 3)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x63 { // OP_PUSH4
                    let value := readBytes(ip,4)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 4)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x64 { // OP_PUSH5
                    let value := readBytes(ip,5)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 5)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x65 { // OP_PUSH6
                    let value := readBytes(ip,6)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 6)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x66 { // OP_PUSH7
                    let value := readBytes(ip,7)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 7)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x67 { // OP_PUSH8
                    let value := readBytes(ip,8)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 8)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x68 { // OP_PUSH9
                    let value := readBytes(ip,9)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 9)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x69 { // OP_PUSH10
                    let value := readBytes(ip,10)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 10)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6A { // OP_PUSH11
                    let value := readBytes(ip,11)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 11)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6B { // OP_PUSH12
                    let value := readBytes(ip,12)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 12)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6C { // OP_PUSH13
                    let value := readBytes(ip,13)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 13)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6D { // OP_PUSH14
                    let value := readBytes(ip,14)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 14)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6E { // OP_PUSH15
                    let value := readBytes(ip,15)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 15)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6F { // OP_PUSH16
                    let value := readBytes(ip,16)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 16)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x70 { // OP_PUSH17
                    let value := readBytes(ip,17)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 17)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x71 { // OP_PUSH18
                    let value := readBytes(ip,18)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 18)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x72 { // OP_PUSH19
                    let value := readBytes(ip,19)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 19)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x73 { // OP_PUSH20
                    let value := readBytes(ip,20)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 20)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x74 { // OP_PUSH21
                    let value := readBytes(ip,21)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 21)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x75 { // OP_PUSH22
                    let value := readBytes(ip,22)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 22)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x76 { // OP_PUSH23
                    let value := readBytes(ip,23)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 23)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x77 { // OP_PUSH24
                    let value := readBytes(ip,24)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 24)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x78 { // OP_PUSH25
                    let value := readBytes(ip,25)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 25)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x79 { // OP_PUSH26
                    let value := readBytes(ip,26)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 26)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7A { // OP_PUSH27
                    let value := readBytes(ip,27)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 27)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7B { // OP_PUSH28
                    let value := readBytes(ip,28)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 28)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7C { // OP_PUSH29
                    let value := readBytes(ip,29)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 29)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7D { // OP_PUSH30
                    let value := readBytes(ip,30)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 30)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7E { // OP_PUSH31
                    let value := readBytes(ip,31)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 31)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7F { // OP_PUSH32
                    let value := readBytes(ip,32)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 32)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x80 { // OP_DUP1 
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 1)
                }
                case 0x81 { // OP_DUP2
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 2)
                }
                case 0x82 { // OP_DUP3
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 3)
                }
                case 0x83 { // OP_DUP4    
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 4)
                }
                case 0x84 { // OP_DUP5
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 5)
                }
                case 0x85 { // OP_DUP6
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 6)
                }
                case 0x86 { // OP_DUP7    
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 7)
                }
                case 0x87 { // OP_DUP8
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 8)
                }
                case 0x88 { // OP_DUP9
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 9)
                }
                case 0x89 { // OP_DUP10   
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 10)
                }
                case 0x8A { // OP_DUP11
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 11)
                }
                case 0x8B { // OP_DUP12
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 12)
                }
                case 0x8C { // OP_DUP13
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 13)
                }
                case 0x8D { // OP_DUP14
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 14)
                }
                case 0x8E { // OP_DUP15
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 15)
                }
                case 0x8F { // OP_DUP16
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 16)
                }
                case 0x90 { // OP_SWAP1 
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 1)
                }
                case 0x91 { // OP_SWAP2
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 2)
                }
                case 0x92 { // OP_SWAP3
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 3)
                }
                case 0x93 { // OP_SWAP4    
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 4)
                }
                case 0x94 { // OP_SWAP5
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 5)
                }
                case 0x95 { // OP_SWAP6
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 6)
                }
                case 0x96 { // OP_SWAP7    
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 7)
                }
                case 0x97 { // OP_SWAP8
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 8)
                }
                case 0x98 { // OP_SWAP9
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 9)
                }
                case 0x99 { // OP_SWAP10   
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 10)
                }
                case 0x9A { // OP_SWAP11
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 11)
                }
                case 0x9B { // OP_SWAP12
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 12)
                }
                case 0x9C { // OP_SWAP13
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 13)
                }
                case 0x9D { // OP_SWAP14
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 14)
                }
                case 0x9E { // OP_SWAP15
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 15)
                }
                case 0x9F { // OP_SWAP16
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 16)
                }
                case 0xA0 { // OP_LOG0
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    {
                        let gasUsed := add(add(375, mul(8, size)), expandMemory(add(offset, size)))
                        evmGasLeft := chargeGas(evmGasLeft, gasUsed)
                    }
            
                    log0(add(offset, MEM_OFFSET_INNER()), size)
                }
                case 0xA1 { // OP_LOG1
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size, topic1
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
                    topic1, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(750, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    log1(add(offset, MEM_OFFSET_INNER()), size, topic1)
                }
                case 0xA2 { // OP_LOG2
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(1125, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    {
                        let topic1, topic2
                        topic1, sp := popStackItem(sp)
                        topic2, sp := popStackItem(sp)
                        log2(add(offset, MEM_OFFSET_INNER()), size, topic1, topic2)
                    }
                }
                case 0xA3 { // OP_LOG3
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(1500, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    {
                        let topic1, topic2, topic3
                        topic1, sp := popStackItem(sp)
                        topic2, sp := popStackItem(sp)
                        topic3, sp := popStackItem(sp)
                        log3(add(offset, MEM_OFFSET_INNER()), size, topic1, topic2, topic3)
                    }
                }
                case 0xA4 { // OP_LOG4
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(1875, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    {
                        let topic1, topic2, topic3, topic4
                        topic1, sp := popStackItem(sp)
                        topic2, sp := popStackItem(sp)
                        topic3, sp := popStackItem(sp)
                        topic4, sp := popStackItem(sp)
                        log4(add(offset, MEM_OFFSET_INNER()), size, topic1, topic2, topic3, topic4)
                    }
            
                }
                case 0xF0 { // OP_CREATE
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let value, offset, size
            
                    value, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(MEM_OFFSET_INNER(), add(offset, size)))
            
                    if gt(size, mul(2, MAX_POSSIBLE_BYTECODE())) {
                        revert(0, 0)
                    }
            
                    if gt(value, balance(address())) {
                        revert(0, 0)
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, add(
                        32000, add(
                        expandMemory(add(offset, size)),
                        mul(2, div(add(size, 31), 32))
                        )
                    ))
                    
                    let addr := getNewAddress(address())
            
                    let result
                    result, evmGasLeft := genericCreate(addr, offset, size, sp, value, evmGasLeft) //code_deposit_cost missing
            
                    switch result
                        case 0 { sp := pushStackItem(sp, 0) }
                        default { sp := pushStackItem(sp, addr) }
                }
                case 0xF5 { // OP_CREATE2
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let value, offset, size, salt
            
                    value, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
                    salt, sp := popStackItem(sp)
            
                    checkMemOverflow(add(MEM_OFFSET_INNER(), add(offset, size)))
            
                    if gt(size, mul(2, MAX_POSSIBLE_BYTECODE())) {
                        revert(0, 0)
                    }
            
                    if gt(value, balance(address())) {
                        revert(0, 0)
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, add(
                        32000, add(
                        expandMemory(add(offset, size)),
                        mul(8, div(add(size, 31), 32))
                        )
                    ))
                    {
                        let hashedBytecode := keccak256(add(MEM_OFFSET_INNER(), offset), size)
                        mstore8(0, 0xFF)
                        mstore(0x01, shl(0x60, address()))
                        mstore(0x15, salt)
                        mstore(0x35, hashedBytecode)
                    }
            
                    let addr := and(
                        keccak256(0, 0x55),
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                    )
            
                    let result
                    result, evmGasLeft := genericCreate(addr, offset, size, sp, value, evmGasLeft) //code_deposit_cost missing
            
                    switch result
                        case 0 { sp := pushStackItem(sp, 0) }
                        default { sp := pushStackItem(sp, addr) }
                }
                case 0xF1 { // OP_CALL
                    let gasUsed
            
                    // A function was implemented in order to avoid stack depth errors.
                    gasUsed, sp := performCall(sp, evmGasLeft, isStatic)
                    
                    // Check if the following is ok
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
                }
                case 0xFA { // OP_STATICCALL
                    let gasUsed
                    gasUsed, sp := performStaticCall(sp,evmGasLeft)
                    evmGasLeft := chargeGas(evmGasLeft,gasUsed)
                }
                case 0xF3 { // OP_RETURN
                    let offset,size
            
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    ensureAcceptableMemLocation(offset)
                    ensureAcceptableMemLocation(size)
                    evmGasLeft := chargeGas(evmGasLeft,expandMemory(add(offset,size)))
            
                    returnLen := size
                    returnOffset := add(MEM_OFFSET_INNER(), offset)
                    break
                }
                case 0xF4 { // OP_DELEGATECALL
                    let gasUsed
                    sp, isStatic, gasUsed := delegateCall(sp, isStatic, evmGasLeft)
            
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
                }
                case 0xFD { // OP_REVERT
                    let offset,size
            
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    ensureAcceptableMemLocation(offset)
                    ensureAcceptableMemLocation(size)
                    evmGasLeft := chargeGas(evmGasLeft,expandMemory(add(offset,size)))
            
                    offset := add(offset, MEM_OFFSET_INNER())
                    offset,size := addGasIfEvmRevert(isCallerEVM,offset,size,evmGasLeft)
            
                    revert(offset,size)
                }
                case 0xFE { // OP_INVALID
                    evmGasLeft := 0
            
                    invalid()
                }
                default {
                    printString("INVALID OPCODE")
                    printHex(opcode)
                    revert(0, 0)
                }
            }
            

            retGasLeft := evmGasLeft
        }

        ////////////////////////////////////////////////////////////////
        //                      FALLBACK
        ////////////////////////////////////////////////////////////////

        let evmGasLeft, isStatic, isCallerEVM := consumeEvmFrame()

        if isStatic {
            revert(0, 0)
        }

        getConstructorBytecode()

        if iszero(isCallerEVM) {
            evmGasLeft := getEVMGas()
        }

        let offset, len, gasToReturn := simulate(isCallerEVM, evmGasLeft, false)

        gasToReturn := validateCorrectBytecode(offset, len, gasToReturn)

        offset, len := padBytecode(offset, len)

        setDeployedCode(gasToReturn, offset, len)
    }
    object "EVMInterpreter_deployed" {
        code {
            function SYSTEM_CONTRACTS_OFFSET() -> offset {
                offset := 0x8000
            }
            
            function ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT() -> addr {
                addr := 0x0000000000000000000000000000000000008002
            }
            
            function NONCE_HOLDER_SYSTEM_CONTRACT() -> addr {
                addr := 0x0000000000000000000000000000000000008003
            }
            
            function DEPLOYER_SYSTEM_CONTRACT() -> addr {
                addr :=  0x0000000000000000000000000000000000008006
            }
            
            function CODE_ADDRESS_CALL_ADDRESS() -> addr {
                addr := 0x000000000000000000000000000000000000FFFE
            }
            
            function CODE_ORACLE_SYSTEM_CONTRACT() -> addr {
                addr := 0x0000000000000000000000000000000000008012
            }
            
            function EVM_GAS_MANAGER_CONTRACT() -> addr {   
                addr :=  0x0000000000000000000000000000000000008013
            }
            
            function CALLFLAGS_CALL_ADDRESS() -> addr {
                addr := 0x000000000000000000000000000000000000FFEF
            }
            
            function DEBUG_SLOT_OFFSET() -> offset {
                offset := mul(32, 32)
            }
            
            function LAST_RETURNDATA_SIZE_OFFSET() -> offset {
                offset := add(DEBUG_SLOT_OFFSET(), mul(5, 32))
            }
            
            function STACK_OFFSET() -> offset {
                offset := add(LAST_RETURNDATA_SIZE_OFFSET(), 32)
            }
            
            function BYTECODE_OFFSET() -> offset {
                offset := add(STACK_OFFSET(), mul(1024, 32))
            }
            
            function INF_PASS_GAS() -> inf {
                inf := 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            }
            
            function MAX_POSSIBLE_BYTECODE() -> max {
                max := 32000
            }
            
            function MEM_OFFSET() -> offset {
                offset := add(BYTECODE_OFFSET(), MAX_POSSIBLE_BYTECODE())
            }
            
            function MEM_OFFSET_INNER() -> offset {
                offset := add(MEM_OFFSET(), 32)
            }
            
            function MAX_POSSIBLE_MEM() -> max {
                max := 0x100000 // 1MB
            }
            
            function MAX_MEMORY_FRAME() -> max {
                max := add(MEM_OFFSET_INNER(), MAX_POSSIBLE_MEM())
            }
            
            // It is the responsibility of the caller to ensure that ip >= BYTECODE_OFFSET + 32
            function readIP(ip) -> opcode {
                // TODO: Why not do this at the beginning once instead of every time?
                let bytecodeLen := mload(BYTECODE_OFFSET())
            
                let maxAcceptablePos := add(add(BYTECODE_OFFSET(), bytecodeLen), 31)
                if gt(ip, maxAcceptablePos) {
                    revert(0, 0)
                }
            
                opcode := and(mload(sub(ip, 31)), 0xff)
            }
            
            function readBytes(start, length) -> value {
                let max := add(start, length)
                for {} lt(start, max) { start := add(start, 1) } {
                    let next_byte := readIP(start)
            
                    value := or(shl(8, value), next_byte)
                }
            }
            
            function dupStackItem(sp, evmGas, position) -> newSp, evmGasLeft {
                evmGasLeft := chargeGas(evmGas, 3)
                let tempSp := sub(sp, mul(0x20, sub(position, 1)))
            
                if or(gt(tempSp, BYTECODE_OFFSET()), eq(tempSp, BYTECODE_OFFSET())) {
                    revert(0, 0)
                }
            
                if lt(tempSp, STACK_OFFSET()) {
                    revert(0, 0)
                }
            
                let dup := mload(tempSp)                    
            
                newSp := add(sp, 0x20)
                mstore(newSp, dup)
            }
            
            function swapStackItem(sp, evmGas, position) ->  evmGasLeft {
                evmGasLeft := chargeGas(evmGas, 3)
                let tempSp := sub(sp, mul(0x20, position))
            
                if or(gt(tempSp, BYTECODE_OFFSET()), eq(tempSp, BYTECODE_OFFSET())) {
                    revert(0, 0)
                }
            
                if lt(tempSp, STACK_OFFSET()) {
                    revert(0, 0)
                }
            
            
                let s2 := mload(sp)
                let s1 := mload(tempSp)                    
            
                mstore(sp, s1)
                mstore(tempSp, s2)
            }
            
            function popStackItem(sp) -> a, newSp {
                // We can not return any error here, because it would break compatibility
                if lt(sp, STACK_OFFSET()) {
                    revert(0, 0)
                }
            
                a := mload(sp)
                newSp := sub(sp, 0x20)
            }
            
            function pushStackItem(sp, item) -> newSp {
                if or(gt(sp, BYTECODE_OFFSET()), eq(sp, BYTECODE_OFFSET())) {
                    revert(0, 0)
                }
            
                newSp := add(sp, 0x20)
                mstore(newSp, item)
            }
            
            function getCodeAddress() -> addr {
                addr := verbatim_0i_1o("code_source")
            }
            
            function loadReturndataIntoActivePtr() {
                verbatim_0i_0o("return_data_ptr_to_active")
            }
            
            function loadCalldataIntoActivePtr() {
                verbatim_0i_0o("calldata_ptr_to_active")
            }
            
            function getActivePtrDataSize() -> size {
                size := verbatim_0i_1o("active_ptr_data_size")
            }
            
            function copyActivePtrData(_dest, _source, _size) {
                verbatim_3i_0o("active_ptr_data_copy", _dest, _source, _size)
            }
            
            function ptrAddIntoActive(_dest) {
                verbatim_1i_0o("active_ptr_add_assign", _dest)
            }
            
            function ptrShrinkIntoActive(_dest) {
                verbatim_1i_0o("active_ptr_shrink_assign", _dest)
            }
            
            function _getRawCodeHash(account) -> hash {
                // TODO: Unhardcode this selector
                mstore8(0, 0x4d)
                mstore8(1, 0xe2)
                mstore8(2, 0xe4)
                mstore8(3, 0x68)
                mstore(4, account)
            
                let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                hash := mload(0)
            }
            
            function _getCodeHash(account) -> hash {
                // function getCodeHash(uint256 _input) external view override returns (bytes32)
                // 0xe03fe177
                // TODO: Unhardcode this selector
                mstore8(0, 0xe0)
                mstore8(1, 0x3f)
                mstore8(2, 0xe1)
                mstore8(3, 0x77)
                mstore(4, account)
            
                let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                hash := mload(0)
            }
            
            function getIsStaticFromCallFlags() -> isStatic {
                isStatic := verbatim_0i_1o("get_global::call_flags")
                // TODO: make it a constnat
                isStatic := iszero(iszero(and(isStatic, 0x04)))
            }
            
            // Basically performs an extcodecopy, while returning the length of the bytecode.
            function _fetchDeployedCode(addr, _offset, _len) -> codeLen {
                let codeHash := _getRawCodeHash(addr)
            
                mstore(0, codeHash)
            
                let success := staticcall(gas(), CODE_ORACLE_SYSTEM_CONTRACT(), 0, 32, 0, 0)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                // The first word is the true length of the bytecode
                returndatacopy(0, 0, 32)
                codeLen := mload(0)
            
                if gt(_len, codeLen) {
                    _len := codeLen
                }
            
                returndatacopy(_offset, 32, _len)
            }
            
            // Returns the length of the bytecode.
            function _fetchDeployedCodeLen(addr) -> codeLen {
                let codeHash := _getRawCodeHash(addr)
            
                mstore(0, codeHash)
            
                let success := staticcall(gas(), CODE_ORACLE_SYSTEM_CONTRACT(), 0, 32, 0, 0)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                // The first word is the true length of the bytecode
                returndatacopy(0, 0, 32)
                codeLen := mload(0)
            }
            
            function getDeployedBytecode() {
                let codeLen := _fetchDeployedCode(
                    getCodeAddress(),
                    add(BYTECODE_OFFSET(), 32),
                    MAX_POSSIBLE_BYTECODE()
                )
            
                mstore(BYTECODE_OFFSET(), codeLen)
            }
            
            function consumeEvmFrame() -> passGas, isStatic, callerEVM {
                // function consumeEvmFrame() external returns (uint256 passGas, bool isStatic)
                // TODO: Unhardcode selector
                mstore8(0, 0x04)
                mstore8(1, 0xc1)
                mstore8(2, 0x4e)
                mstore8(3, 0x9e)
            
                let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 4, 0, 64)
            
                if iszero(success) {
                    // Should never happen
                    revert(0, 0)
                }
            
                passGas := mload(0)
                isStatic := mload(32)
            
                if iszero(eq(passGas, INF_PASS_GAS())) {
                    callerEVM := true
                }
            }
            
            function chargeGas(prevGas, toCharge) -> gasRemaining {
                if lt(prevGas, toCharge) {
                    revert(0, 0)
                }
            
                gasRemaining := sub(prevGas, toCharge)
            }
            
            function checkMemOverflow(location) {
                if gt(location, MAX_MEMORY_FRAME()) {
                    revert(0, 0)
                }
            }
            
            // Note, that this function can overflow. It's up to the caller to ensure that it does not.
            function memCost(memSizeWords) -> gasCost {
                // The first term of the sum is the quadratic cost, the second one the linear one.
                gasCost := add(div(mul(memSizeWords, memSizeWords), 512), mul(3, memSizeWords))
            }
            
            // This function can overflow, it is the job of the caller to ensure that it does not.
            // The argument to this function is the offset into the memory region IN BYTES.
            function expandMemory(newSize) -> gasCost {
                let oldSizeInWords := mload(MEM_OFFSET())
            
                // The add 31 here before dividing is there to account for misaligned
                // memory expansions, where someone calls this with a newSize that is not
                // a multiple of 32. For instance, if someone calls it with an offset of 33,
                // the new size in words should be 2, not 1, but dividing by 32 will give 1.
                // Adding 31 solves it.
                let newSizeInWords := div(add(newSize, 31), 32)
            
                if gt(newSizeInWords, oldSizeInWords) {
                    // TODO: Check this, it feels like there might be a more optimized way
                    // of doing this cost calculation.
                    let oldCost := memCost(oldSizeInWords)
                    let newCost := memCost(newSizeInWords)
            
                    gasCost := sub(newCost, oldCost)
                    mstore(MEM_OFFSET(), newSizeInWords)
                }
            }
            
            // Essentially a NOP that will not get optimized away by the compiler
            function $llvm_NoInline_llvm$_unoptimized() {
                pop(1)
            }
            
            function printHex(value) {
                mstore(add(DEBUG_SLOT_OFFSET(), 0x20), 0x00debdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebde)
                mstore(add(DEBUG_SLOT_OFFSET(), 0x40), value)
                mstore(DEBUG_SLOT_OFFSET(), 0x4A15830341869CAA1E99840C97043A1EA15D2444DA366EFFF5C43B4BEF299681)
                $llvm_NoInline_llvm$_unoptimized()
            }
            
            function printString(value) {
                mstore(add(DEBUG_SLOT_OFFSET(), 0x20), 0x00debdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdebdf)
                mstore(add(DEBUG_SLOT_OFFSET(), 0x40), value)
                mstore(DEBUG_SLOT_OFFSET(), 0x4A15830341869CAA1E99840C97043A1EA15D2444DA366EFFF5C43B4BEF299681)
                $llvm_NoInline_llvm$_unoptimized()
            }
            
            function isSlotWarm(key) -> isWarm {
                // TODO: Unhardcode this selector 0x482d2e74
                mstore8(0, 0x48)
                mstore8(1, 0x2d)
                mstore8(2, 0x2e)
                mstore8(3, 0x74)
                mstore(4, key)
            
                let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 36, 0, 32)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                isWarm := mload(0)
            }
            
            function warmSlot(key,currentValue) -> isWarm, originalValue {
                // TODO: Unhardcode this selector 0xbdf78160
                mstore8(0, 0xbd)
                mstore8(1, 0xf7)
                mstore8(2, 0x81)
                mstore8(3, 0x60)
                mstore(4, key)
                mstore(36,currentValue)
            
                let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 68, 0, 64)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                isWarm := mload(0)
                originalValue := mload(32)
            }
            
            function getNewAddress(addr) -> newAddr {
                let digest, nonce, addressEncoded, nonceEncoded, nonceEncodedLength, listLength, listLengthEconded
            
                nonce := getNonce(addr)
            
                addressEncoded := and(
                    add(addr, shl(160, 0x94)),
                    0xffffffffffffffffffffffffffffffffffffffffff
                )
            
                nonceEncoded := nonce
                nonceEncodedLength := 1
                if iszero(nonce) {
                    nonceEncoded := 128
                }
                // The nonce has 4 bytes
                if gt(nonce, 0xFFFFFF) {
                    nonceEncoded := shl(32, 0x84)
                    nonceEncoded := add(nonceEncoded, nonce)
                    nonceEncodedLength := 5
                }
                // The nonce has 3 bytes
                if and(gt(nonce, 0xFFFF), lt(nonce, 0x1000000)) {
                    nonceEncoded := shl(24, 0x83)
                    nonceEncoded := add(nonceEncoded, nonce)
                    nonceEncodedLength := 4
                }
                // The nonce has 2 bytes
                if and(gt(nonce, 0xFF), lt(nonce, 0x10000)) {
                    nonceEncoded := shl(16, 0x82)
                    nonceEncoded := add(nonceEncoded, nonce)
                    nonceEncodedLength := 3
                }
                // The nonce has 1 byte and it's in [0x80, 0xFF]
                if and(gt(nonce, 0x7F), lt(nonce, 0x100)) {
                    nonceEncoded := shl(8, 0x81)
                    nonceEncoded := add(nonceEncoded, nonce)
                    nonceEncodedLength := 2
                }
            
                listLength := add(21, nonceEncodedLength)
                listLengthEconded := add(listLength, 0xC0)
            
                let arrayLength := add(168, mul(8, nonceEncodedLength))
            
                digest := add(
                    shl(arrayLength, listLengthEconded),
                    add(
                        shl(
                            mul(8, nonceEncodedLength),
                            addressEncoded
                        ),
                        nonceEncoded
                    )
                )
            
                mstore(0, shl(sub(248, arrayLength), digest))
            
                newAddr := and(
                    keccak256(0, add(div(arrayLength, 8), 1)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
            
            function incrementNonce(addr) {
                mstore8(0, 0x30)
                mstore8(1, 0x63)
                mstore8(2, 0x95)
                mstore8(3, 0xc6)
                mstore(4, addr)
            
                let result := call(gas(), NONCE_HOLDER_SYSTEM_CONTRACT(), 0, 0, 36, 0, 0)
            
                if iszero(result) {
                    revert(0, 0)
                }
            }
            
            function ensureAcceptableMemLocation(location) {
                if gt(location,MAX_POSSIBLE_MEM()) {
                    revert(0,0) // Check if this is whats needed
                }
            }
            
            function addGasIfEvmRevert(isCallerEVM,offset,size,evmGasLeft) -> newOffset,newSize {
                newOffset := offset
                newSize := size
                if eq(isCallerEVM,1) {
                    // include gas
                    let previousValue := mload(sub(offset,32))
                    mstore(sub(offset,32),evmGasLeft)
                    //mstore(sub(offset,32),previousValue) // Im not sure why this is needed, it was like this in the solidity code,
                    // but it appears to rewrite were we want to store the gas
            
                    newOffset := sub(offset, 32)
                    newSize := add(size, 32)
                }
            }
            
            function warmAddress(addr) -> isWarm {
                // TODO: Unhardcode this selector 0x8db2ba78
                mstore8(0, 0x8d)
                mstore8(1, 0xb2)
                mstore8(2, 0xba)
                mstore8(3, 0x78)
                mstore(4, addr)
            
                let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 36, 0, 32)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                isWarm := mload(0)
            }
            
            function getNonce(addr) -> nonce {
                mstore8(0, 0xfb)
                mstore8(1, 0x1a)
                mstore8(2, 0x9a)
                mstore8(3, 0x57)
                mstore(4, addr)
            
                let result := staticcall(gas(), NONCE_HOLDER_SYSTEM_CONTRACT(), 0, 36, 0, 32)
            
                if iszero(result) {
                    revert(0, 0)
                }
            
                nonce := mload(0)
            }
            
            function _isEVM(_addr) -> isEVM {
                // bytes4 selector = ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT.isAccountEVM.selector; (0x8c040477)
                // function isAccountEVM(address _addr) external view returns (bool);
                // IAccountCodeStorage constant ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT = IAccountCodeStorage(
                //      address(SYSTEM_CONTRACTS_OFFSET + 0x02)
                // );
            
                mstore8(0, 0x8c)
                mstore8(1, 0x04)
                mstore8(2, 0x04)
                mstore8(3, 0x77)
                mstore(4, _addr)
            
                let success := staticcall(gas(), ACCOUNT_CODE_STORAGE_SYSTEM_CONTRACT(), 0, 36, 0, 32)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                isEVM := mload(0)
            }
            
            function _pushEVMFrame(_passGas, _isStatic) {
                // function pushEVMFrame(uint256 _passGas, bool _isStatic) external
                let selector := 0xead77156
            
                mstore8(0, 0xea)
                mstore8(1, 0xd7)
                mstore8(2, 0x71)
                mstore8(3, 0x56)
                mstore(4, _passGas)
                mstore(36, _isStatic)
            
                let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 68, 0, 0)
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            }
            
            function _popEVMFrame() {
                // function popEVMFrame() external
                // 0xe467d2f0
                let selector := 0xe467d2f0
            
                mstore8(0, 0xe4)
                mstore8(1, 0x67)
                mstore8(2, 0xd2)
                mstore8(3, 0xf0)
            
                let success := call(gas(), EVM_GAS_MANAGER_CONTRACT(), 0, 0, 4, 0, 0)
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            }
            
            // Each evm gas is 5 zkEVM one
            // FIXME: change this variable to reflect real ergs : gas ratio
            function GAS_DIVISOR() -> gas_div { gas_div := 5 }
            function EVM_GAS_STIPEND() -> gas_stipend { gas_stipend := shl(30, 1) } // 1 << 30
            function OVERHEAD() -> overhead { overhead := 2000 }
            // From precompiles/CodeOracle
            function DECOMMIT_COST_PER_WORD() -> cost { cost := 4 }
            function UINT32_MAX() -> ret { ret := 4294967295 } // 2^32 - 1
            
            function _calcEVMGas(_zkevmGas) -> calczkevmGas {
                calczkevmGas := div(_zkevmGas, GAS_DIVISOR())
            }
            
            function getEVMGas() -> evmGas {
                let _gas := gas()
                let requiredGas := add(EVM_GAS_STIPEND(), OVERHEAD())
            
                if lt(sub(_gas,shl(30,1)), requiredGas) {
                    // This cheks if enough zkevm gas was provided, we are substracting 2^30 since that's the stipend, 
                    // and we need to make sure that the gas provided over that is enough for security reasons
                    revert(0, 0)
                }
                evmGas := div(sub(_gas, requiredGas), GAS_DIVISOR())
            }
            
            function _getZkEVMGas(addr) -> zkevmGas {
                let byteSize := extcodesize(addr)
                zkevmGas := mul(byteSize, DECOMMIT_COST_PER_WORD())
                if gt(zkevmGas, UINT32_MAX()) {
                    zkevmGas := UINT32_MAX()
                }
            }
            
            function _saveReturndataAfterEVMCall(_outputOffset, _outputLen) -> _gasLeft{
                let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()
                let rtsz := returndatasize()
            
                loadReturndataIntoActivePtr()
            
                // if (rtsz > 31)
                switch gt(rtsz, 31)
                    case 0 {
                        // Unexpected return data.
                        _gasLeft := 0
                        _eraseReturndataPointer()
                    }
                    default {
                        returndatacopy(0, 0, 32)
                        _gasLeft := mload(0)
                        returndatacopy(_outputOffset, 32, _outputLen)
                        mstore(lastRtSzOffset, sub(rtsz, 32))
            
                        // Skip the returnData
                        ptrAddIntoActive(32)
                    }
            }
            
            function _eraseReturndataPointer() {
                let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()
            
                let activePtrSize := getActivePtrDataSize()
                ptrShrinkIntoActive(and(activePtrSize, 0xFFFFFFFF))// uint32(activePtrSize)
                mstore(lastRtSzOffset, 0)
            }
            
            function _saveReturndataAfterZkEVMCall() {
                loadReturndataIntoActivePtr()
                let lastRtSzOffset := LAST_RETURNDATA_SIZE_OFFSET()
            
                mstore(lastRtSzOffset, returndatasize())
            }
            
            function performStaticCall(oldSp,evmGasLeft) -> extraCost, sp {
                let gasToPass,addr, argsOffset, argsSize, retOffset, retSize
            
                gasToPass, sp := popStackItem(oldSp)
                addr, sp := popStackItem(sp)
                argsOffset, sp := popStackItem(sp)
                argsSize, sp := popStackItem(sp)
                retOffset, sp := popStackItem(sp)
                retSize, sp := popStackItem(sp)
            
                switch warmAddress(addr)
                    case 0 { extraCost := 2600 }
                    default { extraCost := 100 }
                {
                    let maxExpand := add(retOffset, retSize)
                    switch lt(maxExpand,add(argsOffset, argsSize))  // Check if this makes sense
                    case 0 {
                        maxExpand := expandMemory(add(argsOffset, argsSize))
                    }
                    default {
                        maxExpand := expandMemory(maxExpand)
                    }
                    extraCost := add(extraCost,maxExpand)
                }
                let maxGasToPass := sub(evmGasLeft, shr(6, evmGasLeft)) // evmGasLeft >> 6 == evmGasLeft/64
                if gt(gasToPass, maxGasToPass) { 
                    gasToPass := maxGasToPass
                }
            
                let frameGasLeft
                let success
                if _isEVM(addr) {
                    _pushEVMFrame(gasToPass, true)
                    // TODO Check the following comment from zkSync .sol.
                    // We can not just pass all gas here to prevert overflow of zkEVM gas counter
                    success := staticcall(gasToPass, addr, add(MEM_OFFSET_INNER(), argsOffset), argsSize, 0, 0)
            
                    frameGasLeft := _saveReturndataAfterEVMCall(add(MEM_OFFSET_INNER(), retOffset), retSize)
                    _popEVMFrame()
                }
            
                // zkEVM native
                if iszero(_isEVM(addr)) {
                    gasToPass := _getZkEVMGas(addr)
                    let zkevmGasBefore := gas()
                    success := staticcall(gasToPass, addr, add(MEM_OFFSET_INNER(), argsOffset), argsSize, add(MEM_OFFSET_INNER(), retOffset), retSize)
                    _saveReturndataAfterZkEVMCall()
            
                    let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))
            
                    frameGasLeft := 0
                    if gt(gasToPass, gasUsed) {
                        frameGasLeft := sub(gasToPass, gasUsed)
                    }
                }
                extraCost := add(extraCost,sub(gasToPass,frameGasLeft))
            
                sp := pushStackItem(sp, success)
            }
            function capGas(evmGasLeft,oldGasToPass) -> gasToPass {
                let maxGasToPass := sub(evmGasLeft, shr(6, evmGasLeft)) // evmGasLeft >> 6 == evmGasLeft/64
                gasToPass := oldGasToPass
                if gt(oldGasToPass, maxGasToPass) { 
                    gasToPass := maxGasToPass
                }
            }
            function performCall(oldSp, evmGasLeft, isStatic) -> extraCost, sp {
                let gasToPass,addr,value,argsOffset,argsSize,retOffset,retSize
            
                gasToPass, sp := popStackItem(oldSp)
                addr, sp := popStackItem(sp)
                value, sp := popStackItem(sp)
                argsOffset, sp := popStackItem(sp)
                argsSize, sp := popStackItem(sp)
                retOffset, sp := popStackItem(sp)
                retSize, sp := popStackItem(sp)
            
            
                // static_gas = 0
                // dynamic_gas = memory_expansion_cost + code_execution_cost + address_access_cost + positive_value_cost + value_to_empty_account_cost
                // code_execution_cost is the cost of the called code execution (limited by the gas parameter).
                // If address is warm, then address_access_cost is 100, otherwise it is 2600. See section access sets.
                // If value is not 0, then positive_value_cost is 9000. In this case there is also a call stipend that is given to make sure that a basic fallback function can be called. 2300 is thus removed from the cost, and also added to the gas input.
                // If value is not 0 and the address given points to an empty account, then value_to_empty_account_cost is 25000. An account is empty if its balance is 0, its nonce is 0 and it has no code.
                
            
                switch warmAddress(addr)
                    case 0 { extraCost := 2600 }
                    default { extraCost := 100 }
                if gt(value, 0) {
                    extraCost := add(extraCost,6700)
                    gasToPass := add(gasToPass,2300)
                }
                if and(isAddrEmpty(addr), gt(value, 0)) {
                    extraCost := add(extraCost,25000)
                }
                {
                    let maxExpand := add(retOffset, retSize)
                    switch lt(maxExpand,add(argsOffset, argsSize)) 
                    case 0 {
                        maxExpand := expandMemory(add(argsOffset, argsSize))
                    }
                    default {
                        maxExpand := expandMemory(maxExpand)
                    }
                    extraCost := add(extraCost,maxExpand)
                }
                gasToPass := capGas(evmGasLeft,gasToPass)
            
                argsOffset := add(argsOffset,MEM_OFFSET_INNER())
                retOffset := add(retOffset,MEM_OFFSET_INNER())
                checkMemOverflow(argsOffset)
                checkMemOverflow(retOffset)
            
                let frameGasLeft
                let success
            
                if isStatic {
                    if value {
                        revert(0, 0)
                    }
                    success, frameGasLeft:= _performStaticCall(
                        _isEVM(addr),
                        gasToPass,
                        addr,
                        argsOffset,
                        argsSize,
                        retOffset,
                        retSize
                    )
                }
            
                if and(_isEVM(addr), iszero(isStatic)) {
                    _pushEVMFrame(gasToPass, isStatic)
                    success := call(gasToPass, addr, value, argsOffset, argsSize, 0, 0)
                    frameGasLeft := _saveReturndataAfterEVMCall(retOffset, retSize)
                    _popEVMFrame()
                }
            
                // zkEVM native
                if and(iszero(_isEVM(addr)), iszero(isStatic)) {
                    gasToPass := _getZkEVMGas(addr)
                    let zkevmGasBefore := gas()
                    success := call(gasToPass, addr, value, argsOffset, argsSize, retOffset, retSize)
                    _saveReturndataAfterZkEVMCall()
                    let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))
            
                    frameGasLeft := 0
                    if gt(gasToPass, gasUsed) {
                        frameGasLeft := sub(gasToPass, gasUsed)
                    }
                }
            
                extraCost := add(extraCost,sub(gasToPass,frameGasLeft))
                sp := pushStackItem(sp,success) 
            }
            
            function delegateCall(oldSp, oldIsStatic, evmGasLeft) -> sp, isStatic, extraCost {
                let addr, gasToPass, argsOffset, argsSize, retOffset, retSize
            
                sp := oldSp
                isStatic := oldIsStatic
            
                gasToPass, sp := popStackItem(sp)
                addr, sp := popStackItem(sp)
                argsOffset, sp := popStackItem(sp)
                argsSize, sp := popStackItem(sp)
                retOffset, sp := popStackItem(sp)
                retSize, sp := popStackItem(sp)
            
                if iszero(_isEVM(addr)) {
                    revert(0, 0)
                }
            
                switch warmAddress(addr)
                    case 0 { extraCost := 2600 }
                    default { extraCost := 100 }
                {
                    let maxExpand := add(retOffset, retSize)
                    switch lt(maxExpand,add(argsOffset, argsSize)) 
                    case 0 {
                        maxExpand := expandMemory(add(argsOffset, argsSize))
                    }
                    default {
                        maxExpand := expandMemory(maxExpand)
                    }
                    extraCost := add(extraCost,maxExpand)
                }
                gasToPass := capGas(evmGasLeft,gasToPass)
            
                // TODO: Do this
                // if warmAccount(addr) {
                //     extraCost = GAS_WARM_ACCESS;
                // } else {
                //     extraCost = GAS_COLD_ACCOUNT_ACCESS;
                // }
            
                _pushEVMFrame(gasToPass, isStatic)
                addr := delegatecall(
                    // We can not just pass all gas here to prevert overflow of zkEVM gas counter
                    gasToPass,
                    addr,
                    add(MEM_OFFSET_INNER(), argsOffset),
                    argsSize,
                    0,
                    0
                )
            
                let frameGasLeft := _saveReturndataAfterEVMCall(add(MEM_OFFSET_INNER(), retOffset), retSize)
            
                _popEVMFrame()
            
                extraCost := add(extraCost,sub(gasToPass,frameGasLeft))
                sp := pushStackItem(sp, addr)
            }
            
            function getMessageCallGas (
                _value,
                _gas,
                _gasLeft,
                _memoryCost,
                _extraGas
            ) -> gasPlusExtra, gasPlusStipend {
                let callStipend := 2300
                if iszero(_value) {
                    callStipend := 0
                }
            
                switch lt(_gasLeft, add(_extraGas, _memoryCost))
                    case 0
                    {
                        let _gasTemp := sub(sub(_gasLeft, _extraGas), _memoryCost)
                        // From the Tangerine Whistle fork, gas is capped at all but one 64th (remaining_gas / 64)
                        // of the remaining gas of the current context. If a call tries to send more, the gas is 
                        // changed to match the maximum allowed.
                        let maxGasToPass := sub(_gasTemp, shr(6, _gasTemp)) // _gas >> 6 == _gas/64
                        if gt(_gas, maxGasToPass) {
                            _gas := maxGasToPass
                        }
                        gasPlusExtra := add(_gas, _extraGas)
                        gasPlusStipend := add(_gas, callStipend)
                    }
                    default {
                        gasPlusExtra := add(_gas, _extraGas)
                        gasPlusStipend := add(_gas, callStipend)
                    }
            }
            
            function _performStaticCall(
                _calleeIsEVM,
                _calleeGas,
                _callee,
                _inputOffset,
                _inputLen,
                _outputOffset,
                _outputLen
            ) ->  success, _gasLeft {
                if _calleeIsEVM {
                    _pushEVMFrame(_calleeGas, true)
                    // TODO Check the following comment from zkSync .sol.
                    // We can not just pass all gas here to prevert overflow of zkEVM gas counter
                    success := staticcall(_calleeGas, _callee, _inputOffset, _inputLen, 0, 0)
            
                    _gasLeft := _saveReturndataAfterEVMCall(_outputOffset, _outputLen)
                    _popEVMFrame()
                }
            
                // zkEVM native
                if iszero(_calleeIsEVM) {
                    _calleeGas := _getZkEVMGas(_callee)
                    let zkevmGasBefore := gas()
                    success := staticcall(_calleeGas, _callee, _inputOffset, _inputLen, _outputOffset, _outputLen)
            
                    _saveReturndataAfterZkEVMCall()
            
                    let gasUsed := _calcEVMGas(sub(zkevmGasBefore, gas()))
            
                    _gasLeft := 0
                    if gt(_calleeGas, gasUsed) {
                        _gasLeft := sub(_calleeGas, gasUsed)
                    }
                }
            }
            
            function isAddrEmpty(addr) -> isEmpty {
                isEmpty := 0
                if  and( and( 
                        iszero(balance(addr)), 
                        iszero(extcodesize(addr)) ),
                        iszero(getNonce(addr))
                    ) {
                    isEmpty := 1
                }
            }
            
            function _fetchConstructorReturnGas() -> gasLeft {
                //selector is 0x24e5ab4a
            
                mstore8(0, 0x24)
                mstore8(1, 0xe5)
                mstore8(2, 0xab)
                mstore8(3, 0x4a)
            
                let success := staticcall(gas(), DEPLOYER_SYSTEM_CONTRACT(), 0, 4, 0, 32)
            
                if iszero(success) {
                    // This error should never happen
                    revert(0, 0)
                }
            
                gasLeft := mload(0)
            }
            
            function genericCreate(addr, offset, size, sp, value, evmGasLeftOld) -> result, evmGasLeft {
                pop(warmAddress(addr))
            
                _eraseReturndataPointer()
            
                let gasForTheCall := capGas(evmGasLeftOld,INF_PASS_GAS())
            
                if lt(balance(addr),value) {
                    revert(0,0)
                }
            
                let nonceNewAddr := getNonce(addr)
                let bytecodeNewAddr := extcodesize(addr)
                if or(gt(nonceNewAddr, 0), gt(bytecodeNewAddr, 0)) {
                    incrementNonce(address())
                    revert(0, 0)
                }
            
                offset := add(MEM_OFFSET_INNER(), offset)
            
                sp := pushStackItem(sp, mload(sub(offset, 0x80)))
                sp := pushStackItem(sp, mload(sub(offset, 0x60)))
                sp := pushStackItem(sp, mload(sub(offset, 0x40)))
                sp := pushStackItem(sp, mload(sub(offset, 0x20)))
            
                // Selector
                mstore(sub(offset, 0x80), 0x5b16a23c)
                // Arg1: address
                mstore(sub(offset, 0x60), addr)
                // Arg2: init code
                // Where the arg starts (third word)
                mstore(sub(offset, 0x40), 0x40)
                // Length of the init code
                mstore(sub(offset, 0x20), size)
            
                _pushEVMFrame(gasForTheCall, false)
            
                result := call(INF_PASS_GAS(), DEPLOYER_SYSTEM_CONTRACT(), value, sub(offset, 0x64), add(size, 0x64), 0, 0)
            
                let gasLeft
                switch result
                    case 0 {
                        gasLeft := _saveReturndataAfterEVMCall(0, 0)
                    }
                    default {
                        gasLeft := _fetchConstructorReturnGas()
                    }
                    
                let gasUsed := sub(gasForTheCall, gasLeft)
                evmGasLeft := chargeGas(evmGasLeftOld, gasUsed)
            
                _popEVMFrame()
            
                incrementNonce(address())
            
                let back
            
                back, sp := popStackItem(sp)
                mstore(sub(offset, 0x20), back)
                back, sp := popStackItem(sp)
                mstore(sub(offset, 0x40), back)
                back, sp := popStackItem(sp)
                mstore(sub(offset, 0x60), back)
                back, sp := popStackItem(sp)
                mstore(sub(offset, 0x80), back)
            }
            

            ////////////////////////////////////////////////////////////////
            //                      FALLBACK
            ////////////////////////////////////////////////////////////////

            let evmGasLeft, isStatic, isCallerEVM := consumeEvmFrame()

            if iszero(isCallerEVM) {
                evmGasLeft := getEVMGas()
                isStatic := getIsStaticFromCallFlags()
            }

            // First, copy the contract's bytecode to be executed into tEdhe `BYTECODE_OFFSET`
            // segment of memory.
            getDeployedBytecode()

            let returnOffset := MEM_OFFSET_INNER()
            let returnLen := 0

            pop(warmAddress(address()))

            // stack pointer - index to first stack element; empty stack = -1
            let sp := sub(STACK_OFFSET(), 32)
            // instruction pointer - index to next instruction. Not called pc because it's an
            // actual yul/evm instruction.
            let ip := add(BYTECODE_OFFSET(), 32)
            let opcode
            
            for { } true { } {
                opcode := readIP(ip)
            
                ip := add(ip, 1)
            
                switch opcode
                case 0x00 { // OP_STOP
                    break
                }
                case 0x01 { // OP_ADD
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, add(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x02 { // OP_MUL
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, mul(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x03 { // OP_SUB
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sub(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x04 { // OP_DIV
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, div(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x05 { // OP_SDIV
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sdiv(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x06 { // OP_MOD
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, mod(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x07 { // OP_SMOD
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, smod(a, b))
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x16 { // OP_AND
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, and(a,b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x17 { // OP_OR
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, or(a,b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x0A { // OP_EXP
                    let a, exponent
            
                    a, sp := popStackItem(sp)
                    exponent, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, exp(a, exponent))
            
                    let expSizeByte := 0
                    if exponent {
                        expSizeByte := div(add(exponent, 256), 256)
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, add(10, mul(50, expSizeByte)))
                }
                case 0x0B { // OP_SIGNEXTEND
                    let b, x
            
                    b, sp := popStackItem(sp)
                    x, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, signextend(b, x))
            
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                }
                case 0x08 { // OP_ADDMOD
                    let a, b, N
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
                    N, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, addmod(a, b, N))
            
                    evmGasLeft := chargeGas(evmGasLeft, 8)
                }
                case 0x09 { // OP_MULMOD
                    let a, b, N
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
                    N, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, mulmod(a, b, N))
            
                    evmGasLeft := chargeGas(evmGasLeft, 8)
                }
                case 0x10 { // OP_LT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, lt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x11 { // OP_GT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, gt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x12 { // OP_SLT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, slt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x13 { // OP_SGT
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sgt(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x14 { // OP_EQ
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, eq(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x15 { // OP_ISZERO
                    let a
            
                    a, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, iszero(a))
            
                    //evmGasLeft := chargeGas(evmGasLeft, 3) TODO: Add this back
                }
                case 0x18 { // OP_XOR
                    let a, b
            
                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, xor(a, b))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x19 { // OP_NOT
                    let a
            
                    a, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, not(a))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1A { // OP_BYTE
                    let i, x
            
                    i, sp := popStackItem(sp)
                    x, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, byte(i, x))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1B { // OP_SHL
                    let shift, value
            
                    shift, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, shl(shift, value))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1C { // OP_SHR
                    let shift, value
            
                    shift, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, shr(shift, value))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x1D { // OP_SAR
                    let shift, value
            
                    shift, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, sar(shift, value))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
            
                case 0x20 { // OP_KECCAK256
                    let offset, size
            
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, keccak256(add(MEM_OFFSET_INNER(), offset), size))
            
                    // When an offset is first accessed (either read or write), memory may trigger 
                    // an expansion, which costs gas.
                    // dynamic_gas = 6 * minimum_word_size + memory_expansion_cost
                    // minimum_word_size = (size + 31) / 32
                    let minWordSize := shr(5,add(size, 31))
                    let dynamicGas := add(mul(6, minWordSize), expandMemory(add(offset, size)))
                    let usedGas := add(30, dynamicGas)
                    evmGasLeft := chargeGas(evmGasLeft, usedGas)
                }
                case 0x30 { // OP_ADDRESS
                    sp := pushStackItem(sp, address())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x31 { // OP_BALANCE
                    let addr
            
                    addr, sp := popStackItem(sp)
            
                    let wasWarm := warmAddress(addr)
            
                    sp := pushStackItem(sp, balance(addr))
            
                    switch wasWarm
                    case 0 { evmGasLeft := chargeGas(evmGasLeft, 2600) }
                    default { evmGasLeft := chargeGas(evmGasLeft, 100) }
                }
                case 0x32 { // OP_ORIGIN
                    sp := pushStackItem(sp, origin())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x33 { // OP_CALLER
                    sp := pushStackItem(sp, caller())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x34 { // OP_CALLVALUE
                    sp := pushStackItem(sp, callvalue())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x35 { // OP_CALLDATALOAD
                    let i
            
                    i, sp := popStackItem(sp)
            
                    sp := pushStackItem(sp, calldataload(i))
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x36 { // OP_CALLDATASIZE
                    sp := pushStackItem(sp, calldatasize())
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x37 { // OP_CALLDATACOPY
                    let destOffset, offset, size
            
                    destOffset, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
            
                    checkMemOverflow(add(add(destOffset,MEM_OFFSET_INNER()), size))
            
                    evmGasLeft := chargeGas(evmGasLeft, expandMemory(add(destOffset, size)))
                    let minWordSize := shr(5,add(size, 31))
                    evmGasLeft := chargeGas(evmGasLeft, mul(3, minWordSize))
            
                    calldatacopy(add(MEM_OFFSET_INNER(), destOffset), offset, size)
                }
                case 0x38 { // OP_CODESIZE
                    let bytecodeLen := mload(BYTECODE_OFFSET())
                    sp := pushStackItem(sp, bytecodeLen)
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x39 { // OP_CODECOPY
                    let bytecodeLen := mload(BYTECODE_OFFSET())
                    let dst, offset, len
            
                    dst, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    len, sp := popStackItem(sp)
            
                    // dynamic_gas = 3 * minimum_word_size + memory_expansion_cost
                    // let minWordSize := div(add(len, 31), 32) Used inside the mul
                    let dynamicGas := add(mul(3, div(add(len, 31), 32)), expandMemory(add(offset, len)))
                    evmGasLeft := chargeGas(evmGasLeft, add(3, dynamicGas))
            
                    let end := len
                    if lt(bytecodeLen, len) {
                        end := bytecodeLen
                    }
            
                    for { let i := 0 } lt(i, end) { i := add(i, 1) } {
                        mstore8(
                            add(MEM_OFFSET_INNER(), add(dst, i)),
                            shr(248, mload(add(BYTECODE_OFFSET(), add(32, add(offset, i)))))
                        )
                    }
                    for { let i := end } lt(i, len) { i := add(i, 1) } {
                        mstore8(add(MEM_OFFSET_INNER(), add(dst, i)), 0)
                    }
                }
                case 0x3A { // OP_GASPRICE
                    sp := pushStackItem(sp, gasprice())
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x3B { // OP_EXTCODESIZE
                    let addr
                    addr, sp := popStackItem(sp)
            
                    // Check if its warm or cold
                    switch warmAddress(addr)
                        case true {
                            evmGasLeft := chargeGas(evmGasLeft, 100)
                        }
                        default {
                            evmGasLeft := chargeGas(evmGasLeft, 2600)
                        }
            
                    // TODO: check, the .sol uses extcodesize directly, but it doesnt seem to work
                    // if a contract is created it works, but if the address is a zkSync's contract
                    // what happens?
                    switch _isEVM(addr) 
                        case 0  { sp := pushStackItem(sp, extcodesize(addr)) }
                        default { sp := pushStackItem(sp, _fetchDeployedCodeLen(addr)) }
                }
                case 0x3C { // OP_EXTCODECOPY
                    let addr, dest, offset, len
                    addr, sp := popStackItem(sp)
                    dest, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    len, sp := popStackItem(sp)
            
                    // Check if its warm or cold
                    // minimum_word_size = (size + 31) / 32
                    // static_gas = 0
                    // dynamic_gas = 3 * minimum_word_size + memory_expansion_cost + address_access_cost
                    let dynamicGas
                    switch warmAddress(addr)
                        case true {
                            dynamicGas := 100
                        }
                        default {
                            dynamicGas := 2600
                        }
            
                    dynamicGas := add(dynamicGas, add(mul(3, shr(5, add(len, 31))), expandMemory(add(offset, len))))
                    evmGasLeft := chargeGas(evmGasLeft, dynamicGas)
            
                    // TODO: Check if Zeroing out the memory is necessary
                    let _lastByte := add(dest, len)
                    for {let i := dest} lt(i, _lastByte) { i := add(i, 1) } {
                        mstore8(i, 0)
                    }
                    // Gets the code from the addr
                    pop(_fetchDeployedCode(addr, add(offset, MEM_OFFSET_INNER()), len))
                }
                case 0x3D { // OP_RETURNDATASIZE
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    let rdz := mload(LAST_RETURNDATA_SIZE_OFFSET())
                    sp := pushStackItem(sp, rdz)
                }
                case 0x3E { // OP_RETURNDATACOPY
                    let dest, offset, len
                    dest, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    len, sp := popStackItem(sp)
            
            
                    // TODO: check if these conditions are met
                    // The addition offset + size overflows.
                    // offset + size is larger than RETURNDATASIZE.
                    if gt(add(offset, len), LAST_RETURNDATA_SIZE_OFFSET()) {
                        revert(0, 0)
                    }
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), len))
            
                    // minimum_word_size = (size + 31) / 32
                    // dynamic_gas = 6 * minimum_word_size + memory_expansion_cost
                    // static_gas = 0
                    let dynamicGas := add(mul(6, shr(5,add(len, 31))), expandMemory(add(offset, len)))
                    evmGasLeft := chargeGas(evmGasLeft, add(3, dynamicGas))
            
                    copyActivePtrData(add(MEM_OFFSET_INNER(), dest), offset, len)
                }
                case 0x3F { // OP_EXTCODEHASH
                    let addr
                    addr, sp := popStackItem(sp)
            
            
                    switch warmAddress(addr)
                        case 0 { 
                            evmGasLeft := chargeGas(evmGasLeft,2600) 
                        }
                        default { 
                            evmGasLeft := chargeGas(evmGasLeft,100) 
                        }
            
                    sp := pushStackItem(sp, extcodehash(addr))
                }
                case 0x40 { // OP_BLOCKHASH
                    let blockNumber
                    blockNumber, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 20)
                    sp := pushStackItem(sp, blockhash(blockNumber))
                }
                case 0x41 { // OP_COINBASE
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, coinbase())
                }
                case 0x42 { // OP_TIMESTAMP
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, timestamp())
                }
                case 0x43 { // OP_NUMBER
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, number())
                }
                case 0x44 { // OP_PREVRANDAO
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, prevrandao())
                }
                case 0x45 { // OP_GASLIMIT
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, gaslimit())
                }
                case 0x46 { // OP_CHAINID
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, chainid())
                }
                case 0x47 { // OP_SELFBALANCE
                    evmGasLeft := chargeGas(evmGasLeft, 5)
                    sp := pushStackItem(sp, selfbalance())
                }
                case 0x48 { // OP_BASEFEE
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                    sp := pushStackItem(sp, basefee())
                }
                case 0x50 { // OP_POP
                    let _y
            
                    _y, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x51 { // OP_MLOAD
                    let offset
            
                    offset, sp := popStackItem(sp)
            
                    let expansionGas := expandMemory(offset) // TODO: add +32 here
            
                    let memValue := mload(add(MEM_OFFSET_INNER(), offset))
                    sp := pushStackItem(sp, memValue)
                    evmGasLeft := chargeGas(evmGasLeft, add(3, expansionGas))
                }
                case 0x52 { // OP_MSTORE
                    let offset, value
            
                    offset, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    let expansionGas := expandMemory(offset) // TODO: add +32 here
            
                    mstore(add(MEM_OFFSET_INNER(), offset), value)
                    evmGasLeft := chargeGas(evmGasLeft, add(3, expansionGas))
                }
                case 0x53 { // OP_MSTORE8
                    let offset, value
            
                    offset, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    let expansionGas := expandMemory(offset) // TODO: add +1 here
            
                    mstore8(add(MEM_OFFSET_INNER(), offset), value)
                    evmGasLeft := chargeGas(evmGasLeft, add(3, expansionGas))
                }
                // NOTE: We don't currently do full jumpdest validation
                // (i.e. validating a jumpdest isn't in PUSH data)
                case 0x56 { // OP_JUMP
                    let counter
            
                    counter, sp := popStackItem(sp)
            
                    ip := add(add(BYTECODE_OFFSET(), 32), counter)
            
                    evmGasLeft := chargeGas(evmGasLeft, 8)
            
                    // Check next opcode is JUMPDEST
                    let nextOpcode := readIP(ip)
                    if iszero(eq(nextOpcode, 0x5B)) {
                        revert(0, 0)
                    }
                }
                case 0x57 { // OP_JUMPI
                    let counter, b
            
                    counter, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)
            
                    evmGasLeft := chargeGas(evmGasLeft, 10)
            
                    if iszero(b) {
                        continue
                    }
            
                    ip := add(add(BYTECODE_OFFSET(), 32), counter)
            
                    // Check next opcode is JUMPDEST
                    let nextOpcode := readIP(ip)
                    if iszero(eq(nextOpcode, 0x5B)) {
                        revert(0, 0)
                    }
                }
                case 0x54 { // OP_SLOAD
                    let key,value,isWarm
            
                    key, sp := popStackItem(sp)
            
                    isWarm := isSlotWarm(key)
                    switch isWarm
                    case 0 { evmGasLeft := chargeGas(evmGasLeft,2100) }
                    default { evmGasLeft := chargeGas(evmGasLeft,100) }
            
                    value := sload(key)
            
                    sp := pushStackItem(sp,value)
                }
                case 0x55 { // OP_SSTORE
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let key, value,gasSpent
            
                    key, sp := popStackItem(sp)
                    value, sp := popStackItem(sp)
            
                    {
                        // Here it is okay to read before we charge since we known anyway that
                        // the context has enough funds to compensate at least for the read.
                        // Im not sure if we need this before: require(gasLeft > GAS_CALL_STIPEND);
                        let currentValue := sload(key)
                        let wasWarm,originalValue := warmSlot(key,currentValue)
                        gasSpent := 100
                        if and(not(eq(value,currentValue)),eq(originalValue,currentValue)) {
                            switch originalValue
                            case 0 { gasSpent := 20000}
                            default { gasSpent := 2900}
                        }
                        if iszero(wasWarm) {
                            gasSpent := add(gasSpent,2100)
                        }
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, gasSpent) //gasSpent
                    sstore(key, value)
                }
                case 0x59 { // OP_MSIZE
                    let size
                    evmGasLeft := chargeGas(evmGasLeft,2)
            
                    size := mload(MEM_OFFSET())
                    size := shl(5,size)
                    sp := pushStackItem(sp,size)
            
                }
                case 0x58 { // OP_PC
                    // PC = ip - 32 (bytecode size) - 1 (current instruction)
                    sp := pushStackItem(sp, sub(sub(ip, BYTECODE_OFFSET()), 33))
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x5A { // OP_GAS
                    evmGasLeft := chargeGas(evmGasLeft, 2)
            
                    sp := pushStackItem(sp, evmGasLeft)
                }
                case 0x5B { // OP_JUMPDEST
                    evmGasLeft := chargeGas(evmGasLeft, 1)
                }
                case 0x5F { // OP_PUSH0
                    let value := 0
            
                    sp := pushStackItem(sp, value)
            
                    evmGasLeft := chargeGas(evmGasLeft, 2)
                }
                case 0x60 { // OP_PUSH1
                    let value := readBytes(ip,1)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 1)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x61 { // OP_PUSH2
                    let value := readBytes(ip,2)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 2)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }     
                case 0x62 { // OP_PUSH3
                    let value := readBytes(ip,3)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 3)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x63 { // OP_PUSH4
                    let value := readBytes(ip,4)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 4)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x64 { // OP_PUSH5
                    let value := readBytes(ip,5)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 5)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x65 { // OP_PUSH6
                    let value := readBytes(ip,6)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 6)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x66 { // OP_PUSH7
                    let value := readBytes(ip,7)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 7)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x67 { // OP_PUSH8
                    let value := readBytes(ip,8)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 8)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x68 { // OP_PUSH9
                    let value := readBytes(ip,9)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 9)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x69 { // OP_PUSH10
                    let value := readBytes(ip,10)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 10)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6A { // OP_PUSH11
                    let value := readBytes(ip,11)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 11)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6B { // OP_PUSH12
                    let value := readBytes(ip,12)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 12)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6C { // OP_PUSH13
                    let value := readBytes(ip,13)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 13)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6D { // OP_PUSH14
                    let value := readBytes(ip,14)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 14)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6E { // OP_PUSH15
                    let value := readBytes(ip,15)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 15)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x6F { // OP_PUSH16
                    let value := readBytes(ip,16)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 16)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x70 { // OP_PUSH17
                    let value := readBytes(ip,17)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 17)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x71 { // OP_PUSH18
                    let value := readBytes(ip,18)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 18)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x72 { // OP_PUSH19
                    let value := readBytes(ip,19)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 19)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x73 { // OP_PUSH20
                    let value := readBytes(ip,20)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 20)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x74 { // OP_PUSH21
                    let value := readBytes(ip,21)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 21)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x75 { // OP_PUSH22
                    let value := readBytes(ip,22)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 22)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x76 { // OP_PUSH23
                    let value := readBytes(ip,23)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 23)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x77 { // OP_PUSH24
                    let value := readBytes(ip,24)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 24)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x78 { // OP_PUSH25
                    let value := readBytes(ip,25)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 25)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x79 { // OP_PUSH26
                    let value := readBytes(ip,26)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 26)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7A { // OP_PUSH27
                    let value := readBytes(ip,27)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 27)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7B { // OP_PUSH28
                    let value := readBytes(ip,28)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 28)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7C { // OP_PUSH29
                    let value := readBytes(ip,29)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 29)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7D { // OP_PUSH30
                    let value := readBytes(ip,30)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 30)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7E { // OP_PUSH31
                    let value := readBytes(ip,31)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 31)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x7F { // OP_PUSH32
                    let value := readBytes(ip,32)
            
                    sp := pushStackItem(sp, value)
                    ip := add(ip, 32)
            
                    evmGasLeft := chargeGas(evmGasLeft, 3)
                }
                case 0x80 { // OP_DUP1 
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 1)
                }
                case 0x81 { // OP_DUP2
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 2)
                }
                case 0x82 { // OP_DUP3
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 3)
                }
                case 0x83 { // OP_DUP4    
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 4)
                }
                case 0x84 { // OP_DUP5
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 5)
                }
                case 0x85 { // OP_DUP6
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 6)
                }
                case 0x86 { // OP_DUP7    
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 7)
                }
                case 0x87 { // OP_DUP8
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 8)
                }
                case 0x88 { // OP_DUP9
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 9)
                }
                case 0x89 { // OP_DUP10   
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 10)
                }
                case 0x8A { // OP_DUP11
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 11)
                }
                case 0x8B { // OP_DUP12
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 12)
                }
                case 0x8C { // OP_DUP13
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 13)
                }
                case 0x8D { // OP_DUP14
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 14)
                }
                case 0x8E { // OP_DUP15
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 15)
                }
                case 0x8F { // OP_DUP16
                    sp, evmGasLeft := dupStackItem(sp, evmGasLeft, 16)
                }
                case 0x90 { // OP_SWAP1 
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 1)
                }
                case 0x91 { // OP_SWAP2
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 2)
                }
                case 0x92 { // OP_SWAP3
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 3)
                }
                case 0x93 { // OP_SWAP4    
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 4)
                }
                case 0x94 { // OP_SWAP5
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 5)
                }
                case 0x95 { // OP_SWAP6
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 6)
                }
                case 0x96 { // OP_SWAP7    
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 7)
                }
                case 0x97 { // OP_SWAP8
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 8)
                }
                case 0x98 { // OP_SWAP9
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 9)
                }
                case 0x99 { // OP_SWAP10   
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 10)
                }
                case 0x9A { // OP_SWAP11
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 11)
                }
                case 0x9B { // OP_SWAP12
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 12)
                }
                case 0x9C { // OP_SWAP13
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 13)
                }
                case 0x9D { // OP_SWAP14
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 14)
                }
                case 0x9E { // OP_SWAP15
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 15)
                }
                case 0x9F { // OP_SWAP16
                    evmGasLeft := swapStackItem(sp, evmGasLeft, 16)
                }
                case 0xA0 { // OP_LOG0
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    {
                        let gasUsed := add(add(375, mul(8, size)), expandMemory(add(offset, size)))
                        evmGasLeft := chargeGas(evmGasLeft, gasUsed)
                    }
            
                    log0(add(offset, MEM_OFFSET_INNER()), size)
                }
                case 0xA1 { // OP_LOG1
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size, topic1
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
                    topic1, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(750, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    log1(add(offset, MEM_OFFSET_INNER()), size, topic1)
                }
                case 0xA2 { // OP_LOG2
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(1125, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    {
                        let topic1, topic2
                        topic1, sp := popStackItem(sp)
                        topic2, sp := popStackItem(sp)
                        log2(add(offset, MEM_OFFSET_INNER()), size, topic1, topic2)
                    }
                }
                case 0xA3 { // OP_LOG3
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(1500, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    {
                        let topic1, topic2, topic3
                        topic1, sp := popStackItem(sp)
                        topic2, sp := popStackItem(sp)
                        topic3, sp := popStackItem(sp)
                        log3(add(offset, MEM_OFFSET_INNER()), size, topic1, topic2, topic3)
                    }
                }
                case 0xA4 { // OP_LOG4
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let offset, size
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(offset, MEM_OFFSET_INNER()))
                    checkMemOverflow(add(add(offset, MEM_OFFSET_INNER()), size))
            
                    let gasUsed := add(add(1875, mul(8, size)), expandMemory(add(offset, size)))
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
            
                    {
                        let topic1, topic2, topic3, topic4
                        topic1, sp := popStackItem(sp)
                        topic2, sp := popStackItem(sp)
                        topic3, sp := popStackItem(sp)
                        topic4, sp := popStackItem(sp)
                        log4(add(offset, MEM_OFFSET_INNER()), size, topic1, topic2, topic3, topic4)
                    }
            
                }
                case 0xF0 { // OP_CREATE
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let value, offset, size
            
                    value, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    checkMemOverflow(add(MEM_OFFSET_INNER(), add(offset, size)))
            
                    if gt(size, mul(2, MAX_POSSIBLE_BYTECODE())) {
                        revert(0, 0)
                    }
            
                    if gt(value, balance(address())) {
                        revert(0, 0)
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, add(
                        32000, add(
                        expandMemory(add(offset, size)),
                        mul(2, div(add(size, 31), 32))
                        )
                    ))
                    
                    let addr := getNewAddress(address())
            
                    let result
                    result, evmGasLeft := genericCreate(addr, offset, size, sp, value, evmGasLeft) //code_deposit_cost missing
            
                    switch result
                        case 0 { sp := pushStackItem(sp, 0) }
                        default { sp := pushStackItem(sp, addr) }
                }
                case 0xF5 { // OP_CREATE2
                    if isStatic {
                        revert(0, 0)
                    }
            
                    let value, offset, size, salt
            
                    value, sp := popStackItem(sp)
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
                    salt, sp := popStackItem(sp)
            
                    checkMemOverflow(add(MEM_OFFSET_INNER(), add(offset, size)))
            
                    if gt(size, mul(2, MAX_POSSIBLE_BYTECODE())) {
                        revert(0, 0)
                    }
            
                    if gt(value, balance(address())) {
                        revert(0, 0)
                    }
            
                    evmGasLeft := chargeGas(evmGasLeft, add(
                        32000, add(
                        expandMemory(add(offset, size)),
                        mul(8, div(add(size, 31), 32))
                        )
                    ))
                    {
                        let hashedBytecode := keccak256(add(MEM_OFFSET_INNER(), offset), size)
                        mstore8(0, 0xFF)
                        mstore(0x01, shl(0x60, address()))
                        mstore(0x15, salt)
                        mstore(0x35, hashedBytecode)
                    }
            
                    let addr := and(
                        keccak256(0, 0x55),
                        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                    )
            
                    let result
                    result, evmGasLeft := genericCreate(addr, offset, size, sp, value, evmGasLeft) //code_deposit_cost missing
            
                    switch result
                        case 0 { sp := pushStackItem(sp, 0) }
                        default { sp := pushStackItem(sp, addr) }
                }
                case 0xF1 { // OP_CALL
                    let gasUsed
            
                    // A function was implemented in order to avoid stack depth errors.
                    gasUsed, sp := performCall(sp, evmGasLeft, isStatic)
                    
                    // Check if the following is ok
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
                }
                case 0xFA { // OP_STATICCALL
                    let gasUsed
                    gasUsed, sp := performStaticCall(sp,evmGasLeft)
                    evmGasLeft := chargeGas(evmGasLeft,gasUsed)
                }
                case 0xF3 { // OP_RETURN
                    let offset,size
            
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    ensureAcceptableMemLocation(offset)
                    ensureAcceptableMemLocation(size)
                    evmGasLeft := chargeGas(evmGasLeft,expandMemory(add(offset,size)))
            
                    returnLen := size
                    returnOffset := add(MEM_OFFSET_INNER(), offset)
                    break
                }
                case 0xF4 { // OP_DELEGATECALL
                    let gasUsed
                    sp, isStatic, gasUsed := delegateCall(sp, isStatic, evmGasLeft)
            
                    evmGasLeft := chargeGas(evmGasLeft, gasUsed)
                }
                case 0xFD { // OP_REVERT
                    let offset,size
            
                    offset, sp := popStackItem(sp)
                    size, sp := popStackItem(sp)
            
                    ensureAcceptableMemLocation(offset)
                    ensureAcceptableMemLocation(size)
                    evmGasLeft := chargeGas(evmGasLeft,expandMemory(add(offset,size)))
            
                    offset := add(offset, MEM_OFFSET_INNER())
                    offset,size := addGasIfEvmRevert(isCallerEVM,offset,size,evmGasLeft)
            
                    revert(offset,size)
                }
                case 0xFE { // OP_INVALID
                    evmGasLeft := 0
            
                    invalid()
                }
                default {
                    printString("INVALID OPCODE")
                    printHex(opcode)
                    revert(0, 0)
                }
            }
            

            if eq(isCallerEVM, 1) {
                // Includes gas
                returnOffset := sub(returnOffset, 32)
                returnLen := add(returnLen, 32)

                mstore(returnOffset, evmGasLeft)
            }

            return(returnOffset, returnLen)
        }
    }
}
