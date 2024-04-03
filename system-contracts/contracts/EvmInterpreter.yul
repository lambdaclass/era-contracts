object "EVMInterpreter" {
    code { }
    object "EVMInterpreter_deployed" {
        code {
            function DEBUG_SLOT_OFFSET() -> offset {
                offset := mul(32, 32)
            }

            function LAST_RETURNDATA_SIZE_OFFSET() -> offset {
                offset := mul(add(DEBUG_SLOT_OFFSET(), 5), 32)
            }

            function STACK_OFFSET() -> offset {
                offset := add(LAST_RETURNDATA_SIZE_OFFSET(), 32)
            }

            function BYTECODE_OFFSET() -> offset {
                offset := mul(add(STACK_OFFSET(), 1024), 32)
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
    
            // It is the responsibility of the caller to ensure that ip >= BYTECODE_OFFSET + 32
            function readIP(ip) -> opcode {
                // TODO: Why not do this at the beginning once instead of every time?
                let bytecodeLen := mload(BYTECODE_OFFSET())

                let maxAcceptablePos := add(add(BYTECODE_OFFSET(), bytecodeLen), 31)
                revert(gt(ip, maxAcceptablePos), "Ip past max acceptable position")

                opcode := and(mload(sub(ip, 31)), 0xff)
            }

            function popStackItem(sp) -> a, newSp {
                // We can not return any error here, because it would break compatibility
                revert(lt(sp, STACK_OFFSET()), "Stack pointer went over the stack")

                a := mload(sp)
                newSp := sub(sp, 0x20)
            }

            function pushStackItem(sp, item) -> newSp {
                revert(or(gt(sp, BYTECODE_OFFSET()),eq(sp, BYTECODE_OFFSET())), "Stack pointer went under the bytecode offset")

                newSp := add(tos, 0x20)
                mstore(NewSp, item)
            }

            ////////////////////////////////////////////////////////////////
            //                      FALLBACK
            ////////////////////////////////////////////////////////////////

            // top of stack - index to first stack element; empty stack = -1
            // (this is simpler than tos = stack.length, cleaner code)
            // note it is technically possible to underflow due to the unchecked
            // but that will immediately revert due to out of bounds memory access -> out of gas
            let sp := sub(STACK_OFFSET(), 32)

            for { let ip := add(BYTECODE_OFFSET(), 32) } true { ip := add(ip, 1) } {
                let opcode := readIP(ip)

                sstore(0, opcode)
                return(0, 64)

                switch opcode
                case 0x00 { // OP_STOP
                    // TODO: This is not actually what stop does
                    continue
                }
                case 0x01 { // OP_ADD
                    let a, b

                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)

                    pushStackItem(sp, add(a, b))
                    // TODO: Charge for gas
                    continue
                }
                case 0x02 { // OP_MUL
                    let a, b

                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)

                    pushStackItem(sp, mul(a, b))
                    continue
                }
                case 0x03 { // OP_SUB
                    let a, b

                    a, sp := popStackItem(sp)
                    b, sp := popStackItem(sp)

                    pushStackItem(sp, sub(a, b))
                    continue
                }
                case 0x55 { // OP_SSTORE
                    sstore(0, 1)
                    return(0, 64)

                    continue
                }
                case 0x7F { // OP_PUSH32
                    
                }
                // TODO REST OF OPCODES
                default {
                    // revert(true, "Unrecognized EVM opcode")
                    continue
                }
            }

            return(0, 64)
        }
    }
}
