// Source: Etherscan Verified (forge-flattened)
// Address: 0x4dceb440657f21083db8add07665f8ddbe1dcfc0
// Name: RollupProxy
// Compiler: v0.8.17+commit.8df45f5f

// SPDX-License-Identifier: BUSL-1.1
pragma solidity <0.9.0 >=0.4.21 >=0.6.9 ^0.8.0 ^0.8.1 ^0.8.17 ^0.8.2;
pragma experimental ABIEncoderV2;

// @openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// src/challengeV2/libraries/Enums.sol
// Copyright 2023, Offchain Labs, Inc.
// For license information, see https://github.com/offchainlabs/bold/blob/main/LICENSE

//

/// @notice The status of the edge
/// - Pending: Yet to be confirmed. Not all edges can be confirmed.
/// - Confirmed: Once confirmed it cannot transition back to pending
enum EdgeStatus {
    Pending,
    Confirmed
}

/// @notice The type of the edge. Challenges are decomposed into 3 types of subchallenge
///         represented here by the edge type. Edges are initially created of type Block
///         and are then bisected until they have length one. After that new BigStep edges are
///         added that claim a Block type edge, and are then bisected until they have length one.
///         Then a SmallStep edge is added that claims a length one BigStep edge, and these
///         SmallStep edges are bisected until they reach length one. A length one small step edge
///         can then be directly executed using a one-step proof.
enum EdgeType {
    Block,
    BigStep,
    SmallStep
}

// src/state/GlobalState.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct GlobalState {
    bytes32[2] bytes32Vals;
    uint64[2] u64Vals;
}

library GlobalStateLib {
    using GlobalStateLib for GlobalState;

    uint16 internal constant BYTES32_VALS_NUM = 2;
    uint16 internal constant U64_VALS_NUM = 2;

    function hash(
        GlobalState memory state
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "Global state:",
                state.bytes32Vals[0],
                state.bytes32Vals[1],
                state.u64Vals[0],
                state.u64Vals[1]
            )
        );
    }

    function getBlockHash(
        GlobalState memory state
    ) internal pure returns (bytes32) {
        return state.bytes32Vals[0];
    }

    function getSendRoot(
        GlobalState memory state
    ) internal pure returns (bytes32) {
        return state.bytes32Vals[1];
    }

    function getInboxPosition(
        GlobalState memory state
    ) internal pure returns (uint64) {
        return state.u64Vals[0];
    }

    function getPositionInMessage(
        GlobalState memory state
    ) internal pure returns (uint64) {
        return state.u64Vals[1];
    }

    function isEmpty(
        GlobalState calldata state
    ) internal pure returns (bool) {
        return (
            state.bytes32Vals[0] == bytes32(0) && state.bytes32Vals[1] == bytes32(0)
                && state.u64Vals[0] == 0 && state.u64Vals[1] == 0
        );
    }

    function comparePositions(
        GlobalState calldata a,
        GlobalState calldata b
    ) internal pure returns (int256) {
        uint64 aPos = a.getInboxPosition();
        uint64 bPos = b.getInboxPosition();
        if (aPos < bPos) {
            return -1;
        } else if (aPos > bPos) {
            return 1;
        } else {
            uint64 aMsg = a.getPositionInMessage();
            uint64 bMsg = b.getPositionInMessage();
            if (aMsg < bMsg) {
                return -1;
            } else if (aMsg > bMsg) {
                return 1;
            } else {
                return 0;
            }
        }
    }

    function comparePositionsAgainstStartOfBatch(
        GlobalState calldata a,
        uint256 bPos
    ) internal pure returns (int256) {
        uint64 aPos = a.getInboxPosition();
        if (aPos < bPos) {
            return -1;
        } else if (aPos > bPos) {
            return 1;
        } else {
            if (a.getPositionInMessage() > 0) {
                return 1;
            } else {
                return 0;
            }
        }
    }
}

// @openzeppelin/contracts/proxy/beacon/IBeacon.sol

// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// src/bridge/IDelayedMessageProvider.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

interface IDelayedMessageProvider {
    /// @dev event emitted when a inbox message is added to the Bridge's delayed accumulator
    event InboxMessageDelivered(uint256 indexed messageNum, bytes data);

    /// @dev event emitted when a inbox message is added to the Bridge's delayed accumulator
    /// same as InboxMessageDelivered but the batch data is available in tx.input
    event InboxMessageDeliveredFromOrigin(uint256 indexed messageNum);
}

// @openzeppelin/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// src/libraries/IGasRefunder.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

interface IGasRefunder {
    function onGasSpent(
        address payable spender,
        uint256 gasUsed,
        uint256 calldataSize
    ) external returns (bool success);
}

// src/bridge/IOwnable.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

interface IOwnable {
    function owner() external view returns (address);
}

// src/state/Instructions.sol
// Copyright 2021-2023, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct Instruction {
    uint16 opcode;
    uint256 argumentData;
}

library Instructions {
    uint16 internal constant UNREACHABLE = 0x00;
    uint16 internal constant NOP = 0x01;
    uint16 internal constant RETURN = 0x0F;
    uint16 internal constant CALL = 0x10;
    uint16 internal constant CALL_INDIRECT = 0x11;
    uint16 internal constant LOCAL_GET = 0x20;
    uint16 internal constant LOCAL_SET = 0x21;
    uint16 internal constant GLOBAL_GET = 0x23;
    uint16 internal constant GLOBAL_SET = 0x24;

    uint16 internal constant I32_LOAD = 0x28;
    uint16 internal constant I64_LOAD = 0x29;
    uint16 internal constant F32_LOAD = 0x2A;
    uint16 internal constant F64_LOAD = 0x2B;
    uint16 internal constant I32_LOAD8_S = 0x2C;
    uint16 internal constant I32_LOAD8_U = 0x2D;
    uint16 internal constant I32_LOAD16_S = 0x2E;
    uint16 internal constant I32_LOAD16_U = 0x2F;
    uint16 internal constant I64_LOAD8_S = 0x30;
    uint16 internal constant I64_LOAD8_U = 0x31;
    uint16 internal constant I64_LOAD16_S = 0x32;
    uint16 internal constant I64_LOAD16_U = 0x33;
    uint16 internal constant I64_LOAD32_S = 0x34;
    uint16 internal constant I64_LOAD32_U = 0x35;

    uint16 internal constant I32_STORE = 0x36;
    uint16 internal constant I64_STORE = 0x37;
    uint16 internal constant F32_STORE = 0x38;
    uint16 internal constant F64_STORE = 0x39;
    uint16 internal constant I32_STORE8 = 0x3A;
    uint16 internal constant I32_STORE16 = 0x3B;
    uint16 internal constant I64_STORE8 = 0x3C;
    uint16 internal constant I64_STORE16 = 0x3D;
    uint16 internal constant I64_STORE32 = 0x3E;

    uint16 internal constant MEMORY_SIZE = 0x3F;
    uint16 internal constant MEMORY_GROW = 0x40;

    uint16 internal constant DROP = 0x1A;
    uint16 internal constant SELECT = 0x1B;
    uint16 internal constant I32_CONST = 0x41;
    uint16 internal constant I64_CONST = 0x42;
    uint16 internal constant F32_CONST = 0x43;
    uint16 internal constant F64_CONST = 0x44;
    uint16 internal constant I32_EQZ = 0x45;
    uint16 internal constant I32_RELOP_BASE = 0x46;
    uint16 internal constant IRELOP_EQ = 0;
    uint16 internal constant IRELOP_NE = 1;
    uint16 internal constant IRELOP_LT_S = 2;
    uint16 internal constant IRELOP_LT_U = 3;
    uint16 internal constant IRELOP_GT_S = 4;
    uint16 internal constant IRELOP_GT_U = 5;
    uint16 internal constant IRELOP_LE_S = 6;
    uint16 internal constant IRELOP_LE_U = 7;
    uint16 internal constant IRELOP_GE_S = 8;
    uint16 internal constant IRELOP_GE_U = 9;
    uint16 internal constant IRELOP_LAST = IRELOP_GE_U;

    uint16 internal constant I64_EQZ = 0x50;
    uint16 internal constant I64_RELOP_BASE = 0x51;

    uint16 internal constant I32_UNOP_BASE = 0x67;
    uint16 internal constant IUNOP_CLZ = 0;
    uint16 internal constant IUNOP_CTZ = 1;
    uint16 internal constant IUNOP_POPCNT = 2;
    uint16 internal constant IUNOP_LAST = IUNOP_POPCNT;

    uint16 internal constant I32_ADD = 0x6A;
    uint16 internal constant I32_SUB = 0x6B;
    uint16 internal constant I32_MUL = 0x6C;
    uint16 internal constant I32_DIV_S = 0x6D;
    uint16 internal constant I32_DIV_U = 0x6E;
    uint16 internal constant I32_REM_S = 0x6F;
    uint16 internal constant I32_REM_U = 0x70;
    uint16 internal constant I32_AND = 0x71;
    uint16 internal constant I32_OR = 0x72;
    uint16 internal constant I32_XOR = 0x73;
    uint16 internal constant I32_SHL = 0x74;
    uint16 internal constant I32_SHR_S = 0x75;
    uint16 internal constant I32_SHR_U = 0x76;
    uint16 internal constant I32_ROTL = 0x77;
    uint16 internal constant I32_ROTR = 0x78;

    uint16 internal constant I64_UNOP_BASE = 0x79;

    uint16 internal constant I64_ADD = 0x7C;
    uint16 internal constant I64_SUB = 0x7D;
    uint16 internal constant I64_MUL = 0x7E;
    uint16 internal constant I64_DIV_S = 0x7F;
    uint16 internal constant I64_DIV_U = 0x80;
    uint16 internal constant I64_REM_S = 0x81;
    uint16 internal constant I64_REM_U = 0x82;
    uint16 internal constant I64_AND = 0x83;
    uint16 internal constant I64_OR = 0x84;
    uint16 internal constant I64_XOR = 0x85;
    uint16 internal constant I64_SHL = 0x86;
    uint16 internal constant I64_SHR_S = 0x87;
    uint16 internal constant I64_SHR_U = 0x88;
    uint16 internal constant I64_ROTL = 0x89;
    uint16 internal constant I64_ROTR = 0x8A;

    uint16 internal constant I32_WRAP_I64 = 0xA7;
    uint16 internal constant I64_EXTEND_I32_S = 0xAC;
    uint16 internal constant I64_EXTEND_I32_U = 0xAD;

    uint16 internal constant I32_REINTERPRET_F32 = 0xBC;
    uint16 internal constant I64_REINTERPRET_F64 = 0xBD;
    uint16 internal constant F32_REINTERPRET_I32 = 0xBE;
    uint16 internal constant F64_REINTERPRET_I64 = 0xBF;

    uint16 internal constant I32_EXTEND_8S = 0xC0;
    uint16 internal constant I32_EXTEND_16S = 0xC1;
    uint16 internal constant I64_EXTEND_8S = 0xC2;
    uint16 internal constant I64_EXTEND_16S = 0xC3;
    uint16 internal constant I64_EXTEND_32S = 0xC4;

    uint16 internal constant INIT_FRAME = 0x8002;
    uint16 internal constant ARBITRARY_JUMP = 0x8003;
    uint16 internal constant ARBITRARY_JUMP_IF = 0x8004;
    uint16 internal constant MOVE_FROM_STACK_TO_INTERNAL = 0x8005;
    uint16 internal constant MOVE_FROM_INTERNAL_TO_STACK = 0x8006;
    uint16 internal constant DUP = 0x8008;
    uint16 internal constant CROSS_MODULE_CALL = 0x8009;
    uint16 internal constant CALLER_MODULE_INTERNAL_CALL = 0x800A;
    uint16 internal constant CROSS_MODULE_FORWARD = 0x800B;
    uint16 internal constant CROSS_MODULE_INTERNAL_CALL = 0x800C;

    uint16 internal constant GET_GLOBAL_STATE_BYTES32 = 0x8010;
    uint16 internal constant SET_GLOBAL_STATE_BYTES32 = 0x8011;
    uint16 internal constant GET_GLOBAL_STATE_U64 = 0x8012;
    uint16 internal constant SET_GLOBAL_STATE_U64 = 0x8013;

    uint16 internal constant READ_PRE_IMAGE = 0x8020;
    uint16 internal constant READ_INBOX_MESSAGE = 0x8021;
    uint16 internal constant HALT_AND_SET_FINISHED = 0x8022;
    uint16 internal constant LINK_MODULE = 0x8023;
    uint16 internal constant UNLINK_MODULE = 0x8024;

    uint16 internal constant NEW_COTHREAD = 0x8030;
    uint16 internal constant POP_COTHREAD = 0x8031;
    uint16 internal constant SWITCH_COTHREAD = 0x8032;

    uint256 internal constant INBOX_INDEX_SEQUENCER = 0;
    uint256 internal constant INBOX_INDEX_DELAYED = 1;

    function hash(
        Instruction[] memory code
    ) internal pure returns (bytes32) {
        // To avoid quadratic expense, we declare a `bytes` early and populate its contents.
        bytes memory data = new bytes(13 + 1 + 34 * code.length);
        assembly {
            // Represents the string "Instructions:", which we place after the length word.
            mstore(
                add(data, 32), 0x496e737472756374696f6e733a00000000000000000000000000000000000000
            )
        }

        // write the instruction count
        uint256 offset = 13;
        data[offset] = bytes1(uint8(code.length));
        offset++;

        // write each instruction
        for (uint256 i = 0; i < code.length; i++) {
            Instruction memory inst = code[i];
            data[offset] = bytes1(uint8(inst.opcode >> 8));
            data[offset + 1] = bytes1(uint8(inst.opcode));
            offset += 2;
            uint256 argumentData = inst.argumentData;
            assembly {
                mstore(add(add(data, 32), offset), argumentData)
            }
            offset += 32;
        }
        return keccak256(data);
    }
}

// src/bridge/Messages.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

library Messages {
    struct Message {
        uint8 kind;
        address sender;
        uint64 blockNumber;
        uint64 timestamp;
        uint256 inboxSeqNum;
        uint256 baseFeeL1;
        bytes32 messageDataHash;
    }

    function messageHash(
        Message memory message
    ) internal pure returns (bytes32) {
        return messageHash(
            message.kind,
            message.sender,
            message.blockNumber,
            message.timestamp,
            message.inboxSeqNum,
            message.baseFeeL1,
            message.messageDataHash
        );
    }

    function messageHash(
        uint8 kind,
        address sender,
        uint64 blockNumber,
        uint64 timestamp,
        uint256 inboxSeqNum,
        uint256 baseFeeL1,
        bytes32 messageDataHash
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                kind, sender, blockNumber, timestamp, inboxSeqNum, baseFeeL1, messageDataHash
            )
        );
    }

    function accumulateInboxMessage(
        bytes32 prevAcc,
        bytes32 message
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(prevAcc, message));
    }

    /// @dev   Validates a delayed accumulator preimage
    /// @param delayedAcc The delayed accumulator to validate against
    /// @param beforeDelayedAcc The previous delayed accumulator
    /// @param message The message to validate
    function isValidDelayedAccPreimage(
        bytes32 delayedAcc,
        bytes32 beforeDelayedAcc,
        Message memory message
    ) internal pure returns (bool) {
        return delayedAcc == accumulateInboxMessage(beforeDelayedAcc, messageHash(message));
    }
}

// src/state/ModuleMemoryCompact.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct ModuleMemory {
    uint64 size;
    uint64 maxSize;
    bytes32 merkleRoot;
}

library ModuleMemoryCompactLib {
    function hash(
        ModuleMemory memory mem
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("Memory:", mem.size, mem.maxSize, mem.merkleRoot));
    }
}

// src/state/MultiStack.sol
// Copyright 2021-2024, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct MultiStack {
    bytes32 inactiveStackHash; // NO_STACK_HASH if no stack, 0 if empty stack
    bytes32 remainingHash; // 0 if less than 2 cothreads exist
}

library MultiStackLib {
    bytes32 internal constant NO_STACK_HASH = ~bytes32(0);

    function hash(
        MultiStack memory multi,
        bytes32 activeStackHash,
        bool cothread
    ) internal pure returns (bytes32) {
        require(activeStackHash != NO_STACK_HASH, "MULTISTACK_NOSTACK_ACTIVE");
        if (cothread) {
            require(multi.inactiveStackHash != NO_STACK_HASH, "MULTISTACK_NOSTACK_MAIN");
            return keccak256(
                abi.encodePacked(
                    "multistack:", multi.inactiveStackHash, activeStackHash, multi.remainingHash
                )
            );
        } else {
            return keccak256(
                abi.encodePacked(
                    "multistack:", activeStackHash, multi.inactiveStackHash, multi.remainingHash
                )
            );
        }
    }

    function setEmpty(
        MultiStack memory multi
    ) internal pure {
        multi.inactiveStackHash = NO_STACK_HASH;
        multi.remainingHash = 0;
    }

    function pushNew(
        MultiStack memory multi
    ) internal pure {
        if (multi.inactiveStackHash != NO_STACK_HASH) {
            multi.remainingHash = keccak256(
                abi.encodePacked("cothread:", multi.inactiveStackHash, multi.remainingHash)
            );
        }
        multi.inactiveStackHash = 0;
    }
}

// @openzeppelin/contracts/proxy/Proxy.sol

// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// @openzeppelin/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// src/state/Value.sol
// Copyright 2021-2023, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

enum ValueType {
    I32,
    I64,
    F32,
    F64,
    REF_NULL,
    FUNC_REF,
    INTERNAL_REF
}

struct Value {
    ValueType valueType;
    uint256 contents;
}

library ValueLib {
    function hash(
        Value memory val
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("Value:", val.valueType, val.contents));
    }

    function maxValueType() internal pure returns (ValueType) {
        return ValueType.INTERNAL_REF;
    }

    function assumeI32(
        Value memory val
    ) internal pure returns (uint32) {
        uint256 uintval = uint256(val.contents);
        require(val.valueType == ValueType.I32, "NOT_I32");
        require(uintval < (1 << 32), "BAD_I32");
        return uint32(uintval);
    }

    function assumeI64(
        Value memory val
    ) internal pure returns (uint64) {
        uint256 uintval = uint256(val.contents);
        require(val.valueType == ValueType.I64, "NOT_I64");
        require(uintval < (1 << 64), "BAD_I64");
        return uint64(uintval);
    }

    function newRefNull() internal pure returns (Value memory) {
        return Value({valueType: ValueType.REF_NULL, contents: 0});
    }

    function newI32(
        uint32 x
    ) internal pure returns (Value memory) {
        return Value({valueType: ValueType.I32, contents: uint256(x)});
    }

    function newI64(
        uint64 x
    ) internal pure returns (Value memory) {
        return Value({valueType: ValueType.I64, contents: uint256(x)});
    }

    function newBoolean(
        bool x
    ) internal pure returns (Value memory) {
        if (x) {
            return newI32(uint32(1));
        } else {
            return newI32(uint32(0));
        }
    }

    function newPc(
        uint32 funcPc,
        uint32 func,
        uint32 module
    ) internal pure returns (Value memory) {
        uint256 data = 0;
        data |= funcPc;
        data |= uint256(func) << 32;
        data |= uint256(module) << 64;
        return Value({valueType: ValueType.INTERNAL_REF, contents: data});
    }
}

// @openzeppelin/contracts/interfaces/draft-IERC1822.sol

// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// src/bridge/DelayBufferTypes.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

/// @notice Delay buffer and delay threshold settings
/// @param threshold The maximum amount of blocks that a message is expected to be delayed
/// @param max The maximum buffer in blocks
/// @param replenishRateInBasis The amount to replenish the buffer per block in basis points.
struct BufferConfig {
    uint64 threshold;
    uint64 max;
    uint64 replenishRateInBasis;
}

/// @notice The delay buffer data.
/// @param bufferBlocks The buffer in blocks.
/// @param max The maximum buffer in blocks
/// @param threshold The maximum amount of blocks that a message is expected to be delayed
/// @param prevBlockNumber The blocknumber of the last included delay message.
/// @param replenishRateInBasis The amount to replenish the buffer per block in basis points.
/// @param prevSequencedBlockNumber The blocknumber when last included delay message was sequenced.
struct BufferData {
    uint64 bufferBlocks;
    uint64 max;
    uint64 threshold;
    uint64 prevBlockNumber;
    uint64 replenishRateInBasis;
    uint64 prevSequencedBlockNumber;
}

struct DelayProof {
    bytes32 beforeDelayedAcc;
    Messages.Message delayedMessage;
}

// src/bridge/IBridge.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

interface IBridge {
    /// @dev This is an instruction to offchain readers to inform them where to look
    ///      for sequencer inbox batch data. This is not the type of data (eg. das, brotli encoded, or blob versioned hash)
    ///      and this enum is not used in the state transition function, rather it informs an offchain
    ///      reader where to find the data so that they can supply it to the replay binary
    enum BatchDataLocation {
        /// @notice The data can be found in the transaction call data
        TxInput,
        /// @notice The data can be found in an event emitted during the transaction
        SeparateBatchEvent,
        /// @notice This batch contains no data
        NoData,
        /// @notice The data can be found in the 4844 data blobs on this transaction
        Blob
    }

    struct TimeBounds {
        uint64 minTimestamp;
        uint64 maxTimestamp;
        uint64 minBlockNumber;
        uint64 maxBlockNumber;
    }

    event MessageDelivered(
        uint256 indexed messageIndex,
        bytes32 indexed beforeInboxAcc,
        address inbox,
        uint8 kind,
        address sender,
        bytes32 messageDataHash,
        uint256 baseFeeL1,
        uint64 timestamp
    );

    event BridgeCallTriggered(
        address indexed outbox, address indexed to, uint256 value, bytes data
    );

    event InboxToggle(address indexed inbox, bool enabled);

    event OutboxToggle(address indexed outbox, bool enabled);

    event SequencerInboxUpdated(address newSequencerInbox);

    event RollupUpdated(address rollup);

    function allowedDelayedInboxList(
        uint256
    ) external returns (address);

    function allowedOutboxList(
        uint256
    ) external returns (address);

    /// @dev Accumulator for delayed inbox messages; tail represents hash of the current state; each element represents the inclusion of a new message.
    function delayedInboxAccs(
        uint256
    ) external view returns (bytes32);

    /// @dev Accumulator for sequencer inbox messages; tail represents hash of the current state; each element represents the inclusion of a new message.
    function sequencerInboxAccs(
        uint256
    ) external view returns (bytes32);

    function rollup() external view returns (IOwnable);

    function sequencerInbox() external view returns (address);

    function activeOutbox() external view returns (address);

    function allowedDelayedInboxes(
        address inbox
    ) external view returns (bool);

    function allowedOutboxes(
        address outbox
    ) external view returns (bool);

    function sequencerReportedSubMessageCount() external view returns (uint256);

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool success, bytes memory returnData);

    function delayedMessageCount() external view returns (uint256);

    function sequencerMessageCount() external view returns (uint256);

    // ---------- onlySequencerInbox functions ----------

    function enqueueSequencerMessage(
        bytes32 dataHash,
        uint256 afterDelayedMessagesRead,
        uint256 prevMessageCount,
        uint256 newMessageCount
    )
        external
        returns (uint256 seqMessageIndex, bytes32 beforeAcc, bytes32 delayedAcc, bytes32 acc);

    /**
     * @dev Allows the sequencer inbox to submit a delayed message of the batchPostingReport type
     *      This is done through a separate function entrypoint instead of allowing the sequencer inbox
     *      to call `enqueueDelayedMessage` to avoid the gas overhead of an extra SLOAD in either
     *      every delayed inbox or every sequencer inbox call.
     */
    function submitBatchSpendingReport(
        address batchPoster,
        bytes32 dataHash
    ) external returns (uint256 msgNum);

    // ---------- onlyRollupOrOwner functions ----------

    function setSequencerInbox(
        address _sequencerInbox
    ) external;

    function setDelayedInbox(address inbox, bool enabled) external;

    function setOutbox(address inbox, bool enabled) external;

    function updateRollupAddress(
        IOwnable _rollup
    ) external;
}

// src/state/Module.sol
// Copyright 2021-2023, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct Module {
    bytes32 globalsMerkleRoot;
    ModuleMemory moduleMemory;
    bytes32 tablesMerkleRoot;
    bytes32 functionsMerkleRoot;
    bytes32 extraHash;
    uint32 internalsOffset;
}

library ModuleLib {
    using ModuleMemoryCompactLib for ModuleMemory;

    function hash(
        Module memory mod
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "Module:",
                mod.globalsMerkleRoot,
                mod.moduleMemory.hash(),
                mod.tablesMerkleRoot,
                mod.functionsMerkleRoot,
                mod.extraHash,
                mod.internalsOffset
            )
        );
    }
}

// src/state/StackFrame.sol
// Copyright 2021-2023, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct StackFrame {
    Value returnPc;
    bytes32 localsMerkleRoot;
    uint32 callerModule;
    uint32 callerModuleInternals;
}

struct StackFrameWindow {
    StackFrame[] proved;
    bytes32 remainingHash;
}

library StackFrameLib {
    using ValueLib for Value;

    function hash(
        StackFrame memory frame
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "Stack frame:",
                frame.returnPc.hash(),
                frame.localsMerkleRoot,
                frame.callerModule,
                frame.callerModuleInternals
            )
        );
    }

    function hash(
        StackFrameWindow memory window
    ) internal pure returns (bytes32 h) {
        h = window.remainingHash;
        for (uint256 i = 0; i < window.proved.length; i++) {
            h = keccak256(abi.encodePacked("Stack frame stack:", hash(window.proved[i]), h));
        }
    }

    function peek(
        StackFrameWindow memory window
    ) internal pure returns (StackFrame memory) {
        require(window.proved.length == 1, "BAD_WINDOW_LENGTH");
        return window.proved[0];
    }

    function pop(
        StackFrameWindow memory window
    ) internal pure returns (StackFrame memory frame) {
        require(window.proved.length == 1, "BAD_WINDOW_LENGTH");
        frame = window.proved[0];
        window.proved = new StackFrame[](0);
    }

    function push(StackFrameWindow memory window, StackFrame memory frame) internal pure {
        StackFrame[] memory newProved = new StackFrame[](window.proved.length + 1);
        for (uint256 i = 0; i < window.proved.length; i++) {
            newProved[i] = window.proved[i];
        }
        newProved[window.proved.length] = frame;
        window.proved = newProved;
    }

    function overwrite(StackFrameWindow memory window, bytes32 root) internal pure {
        window.remainingHash = root;
        delete window.proved;
    }
}

// src/state/ValueArray.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct ValueArray {
    Value[] inner;
}

library ValueArrayLib {
    function get(ValueArray memory arr, uint256 index) internal pure returns (Value memory) {
        return arr.inner[index];
    }

    function set(ValueArray memory arr, uint256 index, Value memory val) internal pure {
        arr.inner[index] = val;
    }

    function length(
        ValueArray memory arr
    ) internal pure returns (uint256) {
        return arr.inner.length;
    }

    function push(ValueArray memory arr, Value memory val) internal pure {
        Value[] memory newInner = new Value[](arr.inner.length + 1);
        for (uint256 i = 0; i < arr.inner.length; i++) {
            newInner[i] = arr.inner[i];
        }
        newInner[arr.inner.length] = val;
        arr.inner = newInner;
    }

    function pop(
        ValueArray memory arr
    ) internal pure returns (Value memory popped) {
        popped = arr.inner[arr.inner.length - 1];
        Value[] memory newInner = new Value[](arr.inner.length - 1);
        for (uint256 i = 0; i < newInner.length; i++) {
            newInner[i] = arr.inner[i];
        }
        arr.inner = newInner;
    }
}

// src/bridge/IOutbox.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

interface IOutbox {
    event SendRootUpdated(bytes32 indexed outputRoot, bytes32 indexed l2BlockHash);
    event OutBoxTransactionExecuted(
        address indexed to, address indexed l2Sender, uint256 indexed zero, uint256 transactionIndex
    );

    function initialize(
        IBridge _bridge
    ) external;

    function rollup() external view returns (address); // the rollup contract

    function bridge() external view returns (IBridge); // the bridge contract

    function spent(
        uint256
    ) external view returns (bytes32); // packed spent bitmap

    function roots(
        bytes32
    ) external view returns (bytes32); // maps root hashes => L2 block hash

    // solhint-disable-next-line func-name-mixedcase
    function OUTBOX_VERSION() external view returns (uint128); // the outbox version

    function updateSendRoot(bytes32 sendRoot, bytes32 l2BlockHash) external;

    function updateRollupAddress() external;

    /// @notice When l2ToL1Sender returns a nonzero address, the message was originated by an L2 account
    ///         When the return value is zero, that means this is a system message
    /// @dev the l2ToL1Sender behaves as the tx.origin, the msg.sender should be validated to protect against reentrancies
    function l2ToL1Sender() external view returns (address);

    /// @return l2Block return L2 block when the L2 tx was initiated or 0 if no L2 to L1 transaction is active
    function l2ToL1Block() external view returns (uint256);

    /// @return l1Block return L1 block when the L2 tx was initiated or 0 if no L2 to L1 transaction is active
    function l2ToL1EthBlock() external view returns (uint256);

    /// @return timestamp return L2 timestamp when the L2 tx was initiated or 0 if no L2 to L1 transaction is active
    function l2ToL1Timestamp() external view returns (uint256);

    /// @return outputId returns the unique output identifier of the L2 to L1 tx or 0 if no L2 to L1 transaction is active
    function l2ToL1OutputId() external view returns (bytes32);

    /**
     * @notice Executes a messages in an Outbox entry.
     * @dev Reverts if dispute period hasn't expired, since the outbox entry
     *      is only created once the rollup confirms the respective assertion.
     * @dev it is not possible to execute any L2-to-L1 transaction which contains data
     *      to a contract address without any code (as enforced by the Bridge contract).
     * @param proof Merkle proof of message inclusion in send root
     * @param index Merkle path to message
     * @param l2Sender sender if original message (i.e., caller of ArbSys.sendTxToL1)
     * @param to destination address for L1 contract call
     * @param l2Block l2 block number at which sendTxToL1 call was made
     * @param l1Block l1 block number at which sendTxToL1 call was made
     * @param l2Timestamp l2 Timestamp at which sendTxToL1 call was made
     * @param value wei in L1 message
     * @param data abi-encoded L1 message data
     */
    function executeTransaction(
        bytes32[] calldata proof,
        uint256 index,
        address l2Sender,
        address to,
        uint256 l2Block,
        uint256 l1Block,
        uint256 l2Timestamp,
        uint256 value,
        bytes calldata data
    ) external;

    /**
     *  @dev function used to simulate the result of a particular function call from the outbox
     *       it is useful for things such as gas estimates. This function includes all costs except for
     *       proof validation (which can be considered offchain as a somewhat of a fixed cost - it's
     *       not really a fixed cost, but can be treated as so with a fixed overhead for gas estimation).
     *       We can't include the cost of proof validation since this is intended to be used to simulate txs
     *       that are included in yet-to-be confirmed merkle roots. The simulation entrypoint could instead pretend
     *       to confirm a pending merkle root, but that would be less practical for integrating with tooling.
     *       It is only possible to trigger it when the msg sender is address zero, which should be impossible
     *       unless under simulation in an eth_call or eth_estimateGas
     */
    function executeTransactionSimulation(
        uint256 index,
        address l2Sender,
        address to,
        uint256 l2Block,
        uint256 l1Block,
        uint256 l2Timestamp,
        uint256 value,
        bytes calldata data
    ) external;

    /**
     * @param index Merkle path to message
     * @return true if the message has been spent
     */
    function isSpent(
        uint256 index
    ) external view returns (bool);

    function calculateItemHash(
        address l2Sender,
        address to,
        uint256 l2Block,
        uint256 l1Block,
        uint256 l2Timestamp,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes32);

    function calculateMerkleRoot(
        bytes32[] memory proof,
        uint256 path,
        bytes32 item
    ) external pure returns (bytes32);

    /**
     * @dev function to be called one time during the outbox upgrade process
     *      this is used to fix the storage slots
     */
    function postUpgradeInit() external;
}

// src/rollup/IRollupEventInbox.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

interface IRollupEventInbox {
    function bridge() external view returns (IBridge);

    function initialize(
        IBridge _bridge
    ) external;

    function rollup() external view returns (address);

    function updateRollupAddress() external;

    function rollupInitialized(uint256 chainId, string calldata chainConfig) external;
}

// src/state/ValueStack.sol
// Copyright 2021-2023, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct ValueStack {
    ValueArray proved;
    bytes32 remainingHash;
}

library ValueStackLib {
    using ValueLib for Value;
    using ValueArrayLib for ValueArray;

    function hash(
        ValueStack memory stack
    ) internal pure returns (bytes32 h) {
        h = stack.remainingHash;
        uint256 len = stack.proved.length();
        for (uint256 i = 0; i < len; i++) {
            h = keccak256(abi.encodePacked("Value stack:", stack.proved.get(i).hash(), h));
        }
    }

    function peek(
        ValueStack memory stack
    ) internal pure returns (Value memory) {
        uint256 len = stack.proved.length();
        return stack.proved.get(len - 1);
    }

    function pop(
        ValueStack memory stack
    ) internal pure returns (Value memory) {
        return stack.proved.pop();
    }

    function push(ValueStack memory stack, Value memory val) internal pure {
        return stack.proved.push(val);
    }

    function overwrite(ValueStack memory stack, bytes32 root) internal pure {
        stack.remainingHash = root;
        delete stack.proved;
    }
}

// @openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol

// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// src/libraries/AdminFallbackProxy.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

/// @notice An extension to OZ's ERC1967Upgrade implementation to support two logic contracts
abstract contract DoubleLogicERC1967Upgrade is ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.implementation.secondary" subtracted by 1
    bytes32 internal constant _IMPLEMENTATION_SECONDARY_SLOT =
        0x2b1dbce74324248c222f0ec2d5ed7bd323cfc425b336f0253c5ccfda7265546d;

    // This is the keccak-256 hash of "eip1967.proxy.rollback.secondary" subtracted by 1
    bytes32 private constant _ROLLBACK_SECONDARY_SLOT =
        0x49bd798cd84788856140a4cd5030756b4d08a9e4d55db725ec195f232d262a89;

    /**
     * @dev Emitted when the secondary implementation is upgraded.
     */
    event UpgradedSecondary(address indexed implementation);

    /**
     * @dev Returns the current secondary implementation address.
     */
    function _getSecondaryImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SECONDARY_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setSecondaryImplementation(
        address newImplementation
    ) private {
        require(
            Address.isContract(newImplementation),
            "ERC1967: new secondary implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SECONDARY_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform secondary implementation upgrade
     *
     * Emits an {UpgradedSecondary} event.
     */
    function _upgradeSecondaryTo(
        address newImplementation
    ) internal {
        _setSecondaryImplementation(newImplementation);
        emit UpgradedSecondary(newImplementation);
    }

    /**
     * @dev Perform secondary implementation upgrade with additional setup call.
     *
     * Emits an {UpgradedSecondary} event.
     */
    function _upgradeSecondaryToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeSecondaryTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform secondary implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {UpgradedSecondary} event.
     */
    function _upgradeSecondaryToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SECONDARY_SLOT).value) {
            _setSecondaryImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(
                    slot == _IMPLEMENTATION_SECONDARY_SLOT,
                    "ERC1967Upgrade: unsupported secondary proxiableUUID"
                );
            } catch {
                revert("ERC1967Upgrade: new secondary implementation is not UUPS");
            }
            _upgradeSecondaryToAndCall(newImplementation, data, forceCall);
        }
    }
}

/// @notice similar to TransparentUpgradeableProxy but allows the admin to fallback to a separate logic contract using DoubleLogicERC1967Upgrade
/// @dev this follows the UUPS pattern for upgradeability - read more at https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v4.5.0/contracts/proxy#transparent-vs-uups-proxies
contract AdminFallbackProxy is Proxy, DoubleLogicERC1967Upgrade {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `adminLogic` and a secondary
     * logic implementation specified by `userLogic`
     *
     * Only the `adminAddr` is able to use the `adminLogic` functions
     * All other addresses can interact with the `userLogic` functions
     */
    function _initialize(
        address adminLogic,
        bytes memory adminData,
        address userLogic,
        bytes memory userData,
        address adminAddr
    ) internal {
        assert(_ADMIN_SLOT == bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1));
        assert(
            _IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );
        assert(
            _IMPLEMENTATION_SECONDARY_SLOT
                == bytes32(uint256(keccak256("eip1967.proxy.implementation.secondary")) - 1)
        );
        _changeAdmin(adminAddr);
        _upgradeToAndCall(adminLogic, adminData, false);
        _upgradeSecondaryToAndCall(userLogic, userData, false);
    }

    /// @inheritdoc Proxy
    function _implementation() internal view override returns (address) {
        require(msg.data.length >= 4, "NO_FUNC_SIG");
        // if the sender is the proxy's admin, delegate to admin logic
        // if the admin is disabled, all calls will be forwarded to user logic
        // admin affordances can be disabled by setting to a no-op smart contract
        // since there is a check for contract code before updating the value
        address target = _getAdmin() != msg.sender
            ? DoubleLogicERC1967Upgrade._getSecondaryImplementation()
            : ERC1967Upgrade._getImplementation();
        // implementation setters do an existence check, but we protect against selfdestructs this way
        require(Address.isContract(target), "TARGET_NOT_CONTRACT");
        return target;
    }

    /**
     * @dev unlike transparent upgradeable proxies, this does allow the admin to fallback to a logic contract
     * the admin is expected to interact only with the primary logic contract, which handles contract
     * upgrades using the UUPS approach
     */
    function _beforeFallback() internal override {
        super._beforeFallback();
    }
}

// src/bridge/ISequencerInbox.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

interface ISequencerInbox is IDelayedMessageProvider {
    /// @notice The maximum amount of time variatin between a message being posted on the L1 and being executed on the L2
    /// @param delayBlocks The max amount of blocks in the past that a message can be received on L2
    /// @param futureBlocks The max amount of blocks in the future that a message can be received on L2
    /// @param delaySeconds The max amount of seconds in the past that a message can be received on L2
    /// @param futureSeconds The max amount of seconds in the future that a message can be received on L2
    struct MaxTimeVariation {
        uint256 delayBlocks;
        uint256 futureBlocks;
        uint256 delaySeconds;
        uint256 futureSeconds;
    }

    event SequencerBatchDelivered(
        uint256 indexed batchSequenceNumber,
        bytes32 indexed beforeAcc,
        bytes32 indexed afterAcc,
        bytes32 delayedAcc,
        uint256 afterDelayedMessagesRead,
        IBridge.TimeBounds timeBounds,
        IBridge.BatchDataLocation dataLocation
    );

    event OwnerFunctionCalled(uint256 indexed id);

    /// @dev a separate event that emits batch data when this isn't easily accessible in the tx.input
    event SequencerBatchData(uint256 indexed batchSequenceNumber, bytes data);

    /// @dev a valid keyset was added
    event SetValidKeyset(bytes32 indexed keysetHash, bytes keysetBytes);

    /// @dev a keyset was invalidated
    event InvalidateKeyset(bytes32 indexed keysetHash);

    /// @dev Owner set max time variation.
    ///      This event may have been introduced in an upgrade and therefore might not give the full history.
    ///      To get the full history, search for `OwnerFunctionCalled(0)` events.
    event MaxTimeVariationSet(MaxTimeVariation maxTimeVariation);

    /// @dev Owner set a batch poster.
    ///      This event may have been introduced in an upgrade and therefore might not give the full history.
    ///      To get the full history, search for `OwnerFunctionCalled(1)` events.
    event BatchPosterSet(address batchPoster, bool isBatchPoster);

    /// @dev Owner or batch poster manager set a sequencer.
    ///      This event may have been introduced in an upgrade and therefore might not give the full history.
    ///      To get the full history, search for `OwnerFunctionCalled(4)` events.
    event SequencerSet(address addr, bool isSequencer);

    /// @dev Owner set the batch poster manager.
    ///      This event may have been introduced in an upgrade and therefore might not give the full history.
    ///      To get the full history, search for `OwnerFunctionCalled(5)` events.
    event BatchPosterManagerSet(address newBatchPosterManager);

    /// @dev Owner set the buffer config.
    event BufferConfigSet(BufferConfig bufferConfig);

    function totalDelayedMessagesRead() external view returns (uint256);

    function bridge() external view returns (IBridge);

    /// @dev The size of the batch header
    // solhint-disable-next-line func-name-mixedcase
    function HEADER_LENGTH() external view returns (uint256);

    /// @dev If the first batch data byte after the header has this bit set,
    ///      the sequencer inbox has authenticated the data. Currently only used for 4844 blob support.
    ///      See: https://github.com/OffchainLabs/nitro/blob/69de0603abf6f900a4128cab7933df60cad54ded/arbstate/das_reader.go
    // solhint-disable-next-line func-name-mixedcase
    function DATA_AUTHENTICATED_FLAG() external view returns (bytes1);

    /// @dev If the first data byte after the header has this bit set,
    ///      then the batch data is to be found in 4844 data blobs
    ///      See: https://github.com/OffchainLabs/nitro/blob/69de0603abf6f900a4128cab7933df60cad54ded/arbstate/das_reader.go
    // solhint-disable-next-line func-name-mixedcase
    function DATA_BLOB_HEADER_FLAG() external view returns (bytes1);

    /// @dev If the first data byte after the header has this bit set,
    ///      then the batch data is a das message
    ///      See: https://github.com/OffchainLabs/nitro/blob/69de0603abf6f900a4128cab7933df60cad54ded/arbstate/das_reader.go
    // solhint-disable-next-line func-name-mixedcase
    function DAS_MESSAGE_HEADER_FLAG() external view returns (bytes1);

    /// @dev If the first data byte after the header has this bit set,
    ///      then the batch data is a das message that employs a merklesization strategy
    ///      See: https://github.com/OffchainLabs/nitro/blob/69de0603abf6f900a4128cab7933df60cad54ded/arbstate/das_reader.go
    // solhint-disable-next-line func-name-mixedcase
    function TREE_DAS_MESSAGE_HEADER_FLAG() external view returns (bytes1);

    /// @dev If the first data byte after the header has this bit set,
    ///      then the batch data has been brotli compressed
    ///      See: https://github.com/OffchainLabs/nitro/blob/69de0603abf6f900a4128cab7933df60cad54ded/arbstate/das_reader.go
    // solhint-disable-next-line func-name-mixedcase
    function BROTLI_MESSAGE_HEADER_FLAG() external view returns (bytes1);

    /// @dev If the first data byte after the header has this bit set,
    ///      then the batch data uses a zero heavy encoding
    ///      See: https://github.com/OffchainLabs/nitro/blob/69de0603abf6f900a4128cab7933df60cad54ded/arbstate/das_reader.go
    // solhint-disable-next-line func-name-mixedcase
    function ZERO_HEAVY_MESSAGE_HEADER_FLAG() external view returns (bytes1);

    function rollup() external view returns (IOwnable);

    function isBatchPoster(
        address
    ) external view returns (bool);

    function isSequencer(
        address
    ) external view returns (bool);

    /// @notice True is the sequencer inbox is delay bufferable
    function isDelayBufferable() external view returns (bool);

    function maxDataSize() external view returns (uint256);

    /// @notice The batch poster manager has the ability to change the batch poster addresses
    ///         This enables the batch poster to do key rotation
    function batchPosterManager() external view returns (address);

    struct DasKeySetInfo {
        bool isValidKeyset;
        uint64 creationBlock;
    }

    /// @dev returns 4 uint256 to be compatible with older version
    function maxTimeVariation()
        external
        view
        returns (
            uint256 delayBlocks,
            uint256 futureBlocks,
            uint256 delaySeconds,
            uint256 futureSeconds
        );

    function dasKeySetInfo(
        bytes32
    ) external view returns (bool, uint64);

    /// @notice Remove force inclusion delay after a L1 chainId fork
    function removeDelayAfterFork() external;

    /// @notice Force messages from the delayed inbox to be included in the chain
    ///         Callable by any address, but message can only be force-included after maxTimeVariation.delayBlocks
    ///         has elapsed. As part of normal behaviour the sequencer will include these
    ///         messages so it's only necessary to call this if the sequencer is down, or not including any delayed messages.
    /// @param _totalDelayedMessagesRead The total number of messages to read up to
    /// @param kind The kind of the last message to be included
    /// @param l1BlockAndTime The l1 block and the l1 timestamp of the last message to be included
    /// @param baseFeeL1 The l1 gas price of the last message to be included
    /// @param sender The sender of the last message to be included
    /// @param messageDataHash The messageDataHash of the last message to be included
    function forceInclusion(
        uint256 _totalDelayedMessagesRead,
        uint8 kind,
        uint64[2] calldata l1BlockAndTime,
        uint256 baseFeeL1,
        address sender,
        bytes32 messageDataHash
    ) external;

    function inboxAccs(
        uint256 index
    ) external view returns (bytes32);

    function batchCount() external view returns (uint256);

    function isValidKeysetHash(
        bytes32 ksHash
    ) external view returns (bool);

    /// @notice the creation block is intended to still be available after a keyset is deleted
    function getKeysetCreationBlock(
        bytes32 ksHash
    ) external view returns (uint256);

    /// @dev    The delay buffer can change due to pending depletion/replenishment.
    ///         This function applies pending buffer changes to proactively calculate the force inclusion deadline.
    ///         This is only relevant when the buffer is less than the delayBlocks (unhappy case), otherwise force inclusion deadline is fixed at delayBlocks.
    /// @notice Calculates the upper bounds of the delay buffer
    /// @param blockNumber The block number when a delayed message was created
    /// @return blockNumberDeadline The block number at when the message can be force included
    function forceInclusionDeadline(
        uint64 blockNumber
    ) external view returns (uint64 blockNumberDeadline);

    // ---------- BatchPoster functions ----------

    /// @dev Deprecated, kept for abi generation and will be removed in the future
    function addSequencerL2BatchFromOrigin(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder
    ) external;

    /// @dev Will be deprecated due to EIP-3074, use `addSequencerL2Batch` instead
    function addSequencerL2BatchFromOrigin(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount
    ) external;

    function addSequencerL2Batch(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount
    ) external;

    function addSequencerL2BatchFromBlobs(
        uint256 sequenceNumber,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount
    ) external;

    /// @dev    Proves message delays, updates delay buffers, and posts an L2 batch with blob data.
    ///         DelayProof proves the delay of the message and syncs the delay buffer.
    function addSequencerL2BatchFromBlobsDelayProof(
        uint256 sequenceNumber,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount,
        DelayProof calldata delayProof
    ) external;

    /// @dev    Proves message delays, updates delay buffers, and posts an L2 batch with calldata posted from an EOA.
    ///         DelayProof proves the delay of the message and syncs the delay buffer.
    ///         Will be deprecated due to EIP-3074, use `addSequencerL2BatchDelayProof` instead
    function addSequencerL2BatchFromOriginDelayProof(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount,
        DelayProof calldata delayProof
    ) external;

    /// @dev    Proves message delays, updates delay buffers, and posts an L2 batch with calldata.
    ///         delayProof is used to prove the delay of the message and syncs the delay buffer.
    function addSequencerL2BatchDelayProof(
        uint256 sequenceNumber,
        bytes calldata data,
        uint256 afterDelayedMessagesRead,
        IGasRefunder gasRefunder,
        uint256 prevMessageCount,
        uint256 newMessageCount,
        DelayProof calldata delayProof
    ) external;

    // ---------- onlyRollupOrOwner functions ----------

    /**
     * @notice Set max delay for sequencer inbox
     * @param maxTimeVariation_ the maximum time variation parameters
     */
    function setMaxTimeVariation(
        MaxTimeVariation memory maxTimeVariation_
    ) external;

    /**
     * @notice Updates whether an address is authorized to be a batch poster at the sequencer inbox
     * @param addr the address
     * @param isBatchPoster_ if the specified address should be authorized as a batch poster
     */
    function setIsBatchPoster(address addr, bool isBatchPoster_) external;

    /**
     * @notice Makes Data Availability Service keyset valid
     * @param keysetBytes bytes of the serialized keyset
     */
    function setValidKeyset(
        bytes calldata keysetBytes
    ) external;

    /**
     * @notice Invalidates a Data Availability Service keyset
     * @param ksHash hash of the keyset
     */
    function invalidateKeysetHash(
        bytes32 ksHash
    ) external;

    /**
     * @notice Updates whether an address is authorized to be a sequencer.
     * @dev The IsSequencer information is used only off-chain by the nitro node to validate sequencer feed signer.
     * @param addr the address
     * @param isSequencer_ if the specified address should be authorized as a sequencer
     */
    function setIsSequencer(address addr, bool isSequencer_) external;

    /**
     * @notice Updates the batch poster manager, the address which has the ability to rotate batch poster keys
     * @param newBatchPosterManager The new batch poster manager to be set
     */
    function setBatchPosterManager(
        address newBatchPosterManager
    ) external;

    /// @notice Allows the rollup owner to sync the rollup address
    function updateRollupAddress() external;

    // ---------- initializer ----------

    function initialize(
        IBridge bridge_,
        MaxTimeVariation calldata maxTimeVariation_,
        BufferConfig calldata bufferConfig_
    ) external;
}

// src/state/Machine.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

enum MachineStatus {
    RUNNING,
    FINISHED,
    ERRORED
}

struct Machine {
    MachineStatus status;
    ValueStack valueStack;
    MultiStack valueMultiStack;
    ValueStack internalStack;
    StackFrameWindow frameStack;
    MultiStack frameMultiStack;
    bytes32 globalStateHash;
    uint32 moduleIdx;
    uint32 functionIdx;
    uint32 functionPc;
    bytes32 recoveryPc;
    bytes32 modulesRoot;
}

library MachineLib {
    using StackFrameLib for StackFrameWindow;
    using ValueStackLib for ValueStack;
    using MultiStackLib for MultiStack;

    bytes32 internal constant NO_RECOVERY_PC = ~bytes32(0);

    function hash(
        Machine memory mach
    ) internal pure returns (bytes32) {
        // Warning: the non-running hashes are replicated in Challenge
        if (mach.status == MachineStatus.RUNNING) {
            bytes32 valueMultiHash =
                mach.valueMultiStack.hash(mach.valueStack.hash(), mach.recoveryPc != NO_RECOVERY_PC);
            bytes32 frameMultiHash =
                mach.frameMultiStack.hash(mach.frameStack.hash(), mach.recoveryPc != NO_RECOVERY_PC);
            bytes memory preimage = abi.encodePacked(
                "Machine running:",
                valueMultiHash,
                mach.internalStack.hash(),
                frameMultiHash,
                mach.globalStateHash,
                mach.moduleIdx,
                mach.functionIdx,
                mach.functionPc,
                mach.recoveryPc,
                mach.modulesRoot
            );
            return keccak256(preimage);
        } else if (mach.status == MachineStatus.FINISHED) {
            return keccak256(abi.encodePacked("Machine finished:", mach.globalStateHash));
        } else if (mach.status == MachineStatus.ERRORED) {
            return keccak256(abi.encodePacked("Machine errored:", mach.globalStateHash));
        } else {
            revert("BAD_MACH_STATUS");
        }
    }

    function switchCoThreadStacks(
        Machine memory mach
    ) internal pure {
        bytes32 newActiveValue = mach.valueMultiStack.inactiveStackHash;
        bytes32 newActiveFrame = mach.frameMultiStack.inactiveStackHash;
        if (
            newActiveFrame == MultiStackLib.NO_STACK_HASH
                || newActiveValue == MultiStackLib.NO_STACK_HASH
        ) {
            mach.status = MachineStatus.ERRORED;
            return;
        }
        mach.frameMultiStack.inactiveStackHash = mach.frameStack.hash();
        mach.valueMultiStack.inactiveStackHash = mach.valueStack.hash();
        mach.frameStack.overwrite(newActiveFrame);
        mach.valueStack.overwrite(newActiveValue);
    }

    function setPcFromData(Machine memory mach, uint256 data) internal pure returns (bool) {
        if (data >> 96 != 0) {
            return false;
        }

        mach.functionPc = uint32(data);
        mach.functionIdx = uint32(data >> 32);
        mach.moduleIdx = uint32(data >> 64);
        return true;
    }

    function setPcFromRecovery(
        Machine memory mach
    ) internal pure returns (bool) {
        if (!setPcFromData(mach, uint256(mach.recoveryPc))) {
            return false;
        }
        mach.recoveryPc = NO_RECOVERY_PC;
        return true;
    }

    function setRecoveryFromPc(Machine memory mach, uint32 offset) internal pure returns (bool) {
        if (mach.recoveryPc != NO_RECOVERY_PC) {
            return false;
        }

        uint256 result;
        result = uint256(mach.moduleIdx) << 64;
        result = result | (uint256(mach.functionIdx) << 32);
        result = result | uint256(mach.functionPc + offset - 1);
        mach.recoveryPc = bytes32(result);
        return true;
    }

    function setPc(Machine memory mach, Value memory pc) internal pure {
        if (pc.valueType == ValueType.REF_NULL) {
            mach.status = MachineStatus.ERRORED;
            return;
        }
        if (pc.valueType != ValueType.INTERNAL_REF) {
            mach.status = MachineStatus.ERRORED;
            return;
        }
        if (!setPcFromData(mach, pc.contents)) {
            mach.status = MachineStatus.ERRORED;
            return;
        }
    }
}

// src/bridge/IInboxBase.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

// solhint-disable-next-line compiler-version

interface IInboxBase is IDelayedMessageProvider {
    function bridge() external view returns (IBridge);

    function sequencerInbox() external view returns (ISequencerInbox);

    function maxDataSize() external view returns (uint256);

    /**
     * @notice Send a generic L2 message to the chain
     * @dev This method is an optimization to avoid having to emit the entirety of the messageData in a log. Instead validators are expected to be able to parse the data from the transaction's input
     * @param messageData Data of the message being sent
     */
    function sendL2MessageFromOrigin(
        bytes calldata messageData
    ) external returns (uint256);

    /**
     * @notice Send a generic L2 message to the chain
     * @dev This method can be used to send any type of message that doesn't require L1 validation
     * @param messageData Data of the message being sent
     */
    function sendL2Message(
        bytes calldata messageData
    ) external returns (uint256);

    function sendUnsignedTransaction(
        uint256 gasLimit,
        uint256 maxFeePerGas,
        uint256 nonce,
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (uint256);

    function sendContractTransaction(
        uint256 gasLimit,
        uint256 maxFeePerGas,
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (uint256);

    /**
     * @notice Get the L1 fee for submitting a retryable
     * @dev This fee can be paid by funds already in the L2 aliased address or by the current message value
     * @dev This formula may change in the future, to future proof your code query this method instead of inlining!!
     * @param dataLength The length of the retryable's calldata, in bytes
     * @param baseFee The block basefee when the retryable is included in the chain, if 0 current block.basefee will be used
     */
    function calculateRetryableSubmissionFee(
        uint256 dataLength,
        uint256 baseFee
    ) external view returns (uint256);

    // ---------- onlyRollupOrOwner functions ----------

    /// @notice pauses all inbox functionality
    function pause() external;

    /// @notice unpauses all inbox functionality
    function unpause() external;

    /// @notice add or remove users from allowList
    function setAllowList(address[] memory user, bool[] memory val) external;

    /// @notice enable or disable allowList
    function setAllowListEnabled(
        bool _allowListEnabled
    ) external;

    /// @notice check if user is in allowList
    function isAllowed(
        address user
    ) external view returns (bool);

    /// @notice check if allowList is enabled
    function allowListEnabled() external view returns (bool);

    function initialize(IBridge _bridge, ISequencerInbox _sequencerInbox) external;

    /// @notice returns the current admin
    function getProxyAdmin() external view returns (address);
}

// src/osp/IOneStepProver.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct ExecutionContext {
    uint256 maxInboxMessagesRead;
    IBridge bridge;
    bytes32 initialWasmModuleRoot;
}

abstract contract IOneStepProver {
    function executeOneStep(
        ExecutionContext memory execCtx,
        Machine calldata mach,
        Module calldata mod,
        Instruction calldata instruction,
        bytes calldata proof
    ) external view virtual returns (Machine memory result, Module memory resultMod);
}

// src/osp/IOneStepProofEntry.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

library OneStepProofEntryLib {
    uint256 internal constant MAX_STEPS = 1 << 43;
}

struct ExecutionState {
    GlobalState globalState;
    MachineStatus machineStatus;
}

interface IOneStepProofEntry {
    function getStartMachineHash(
        bytes32 globalStateHash,
        bytes32 wasmModuleRoot
    ) external pure returns (bytes32);

    function proveOneStep(
        ExecutionContext calldata execCtx,
        uint256 machineStep,
        bytes32 beforeHash,
        bytes calldata proof
    ) external view returns (bytes32 afterHash);

    function getMachineHash(
        ExecutionState calldata execState
    ) external pure returns (bytes32);
}

// src/rollup/AssertionState.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct AssertionState {
    GlobalState globalState;
    MachineStatus machineStatus;
    bytes32 endHistoryRoot;
}

library AssertionStateLib {
    function toExecutionState(
        AssertionState memory state
    ) internal pure returns (ExecutionState memory) {
        return ExecutionState(state.globalState, state.machineStatus);
    }

    function hash(
        AssertionState memory state
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(state));
    }
}

// src/rollup/Assertion.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

enum AssertionStatus {
    // No assertion at this index
    NoAssertion,
    // Assertion is being computed
    Pending,
    // Assertion is confirmed
    Confirmed
}

struct AssertionNode {
    // This value starts at zero and is set to a value when the first child is created. After that it is constant until the assertion is destroyed or the owner destroys pending assertions
    uint64 firstChildBlock;
    // This value starts at zero and is set to a value when the second child is created. After that it is constant until the assertion is destroyed or the owner destroys pending assertions
    uint64 secondChildBlock;
    // The block number when this assertion was created
    uint64 createdAtBlock;
    // True if this assertion is the first child of its prev
    bool isFirstChild;
    // Status of the Assertion
    AssertionStatus status;
    // A hash of the context available at the time of this assertions creation. It should contain information that is not specific
    // to this assertion, but instead to the environment at the time of creation. This is necessary to store on the assertion
    // as this environment can change and we need to know what it was like at the time this assertion was created. An example
    // of this is the wasm module root which determines the state transition function on the L2. If the wasm module root
    // changes we need to know that previous assertions were made under a different root, so that we can understand that they
    // were valid at the time. So when resolving a challenge by one step, the edge challenge manager finds the wasm module root
    // that was recorded on the prev of the assertions being disputed and uses it to resolve the one step proof.
    bytes32 configHash;
}

struct BeforeStateData {
    // The assertion hash of the prev of the beforeState(prev)
    bytes32 prevPrevAssertionHash;
    // The sequencer inbox accumulator asserted by the beforeState(prev)
    bytes32 sequencerBatchAcc;
    // below are the components of config hash
    ConfigData configData;
}

struct AssertionInputs {
    // Additional data used to validate the before state
    BeforeStateData beforeStateData;
    AssertionState beforeState;
    AssertionState afterState;
}

struct ConfigData {
    bytes32 wasmModuleRoot;
    uint256 requiredStake;
    address challengeManager;
    uint64 confirmPeriodBlocks;
    uint64 nextInboxPosition;
}

/**
 * @notice Utility functions for Assertion
 */
library AssertionNodeLib {
    /**
     * @notice Initialize a Assertion
     */
    function createAssertion(
        bool _isFirstChild,
        bytes32 _configHash
    ) internal view returns (AssertionNode memory) {
        AssertionNode memory assertion;
        assertion.createdAtBlock = uint64(block.number);
        assertion.isFirstChild = _isFirstChild;
        assertion.configHash = _configHash;
        assertion.status = AssertionStatus.Pending;
        return assertion;
    }

    /**
     * @notice Update child properties
     */
    function childCreated(
        AssertionNode storage self
    ) internal {
        if (self.firstChildBlock == 0) {
            self.firstChildBlock = uint64(block.number);
        } else if (self.secondChildBlock == 0) {
            self.secondChildBlock = uint64(block.number);
        }
    }

    function requireExists(
        AssertionNode memory self
    ) internal pure {
        require(self.status != AssertionStatus.NoAssertion, "ASSERTION_NOT_EXIST");
    }
}

// src/challengeV2/IAssertionChain.sol
// Copyright 2023, Offchain Labs, Inc.
// For license information, see https://github.com/offchainlabs/bold/blob/main/LICENSE

//

/// @title  Assertion chain interface
/// @notice The interface required by the EdgeChallengeManager for requesting assertion data from the AssertionChain
interface IAssertionChain {
    function bridge() external view returns (IBridge);
    function validateAssertionHash(
        bytes32 assertionHash,
        AssertionState calldata state,
        bytes32 prevAssertionHash,
        bytes32 inboxAcc
    ) external view;
    function validateConfig(bytes32 assertionHash, ConfigData calldata configData) external view;
    function getFirstChildCreationBlock(
        bytes32 assertionHash
    ) external view returns (uint64);
    function getSecondChildCreationBlock(
        bytes32 assertionHash
    ) external view returns (uint64);
    function isFirstChild(
        bytes32 assertionHash
    ) external view returns (bool);
    function isPending(
        bytes32 assertionHash
    ) external view returns (bool);
    function isValidator(
        address
    ) external view returns (bool);
    function getValidators() external view returns (address[] memory);
    function validatorWhitelistDisabled() external view returns (bool);
}

// src/challengeV2/libraries/Structs.sol
// Copyright 2023, Offchain Labs, Inc.
// For license information, see https://github.com/offchainlabs/bold/blob/main/LICENSE

//

/// @notice An execution state and proof to show that it's valid
struct AssertionStateData {
    /// @notice An execution state
    AssertionState assertionState;
    /// @notice assertion Hash of the prev assertion
    bytes32 prevAssertionHash;
    /// @notice Inbox accumulator of the assertion
    bytes32 inboxAcc;
}

/// @notice Data for creating a layer zero edge
struct CreateEdgeArgs {
    /// @notice The level of edge to be created. Challenges are decomposed into multiple levels.
    ///         The first (level 0) being of type Block, followed by n (set by NUM_BIGSTEP_LEVEL) levels of type BigStep, and finally
    ///         followed by a single level of type SmallStep. Each level is bisected until an edge
    ///         of length one is reached before proceeding to the next level. The first edge in each level (the layer zero edge)
    ///         makes a claim about an assertion or assertion in the lower level.
    ///         Finally in the last level, a SmallStep edge is added that claims a lower level length one BigStep edge, and these
    ///         SmallStep edges are bisected until they reach length one. A length one small step edge
    ///         can then be directly executed using a one-step proof.
    uint8 level;
    /// @notice The end history root of the edge to be created
    bytes32 endHistoryRoot;
    /// @notice The end height of the edge to be created.
    /// @dev    End height is deterministic for different levels but supplying it here gives the
    ///         caller a bit of extra security that they are supplying data for the correct level of edge
    uint256 endHeight;
    /// @notice The edge, or assertion, that is being claimed correct by the newly created edge.
    bytes32 claimId;
    /// @notice Proof that the start history root commits to a prefix of the states that
    ///         end history root commits to
    bytes prefixProof;
    /// @notice Edge type specific data
    ///         For Block type edges this is the abi encoding of:
    ///         bytes32[]: Inclusion proof - proof to show that the end state is the last state in the end history root
    ///         AssertionStateData: the before state of the edge
    ///         AssertionStateData: the after state of the edge
    ///         bytes32 predecessorId: id of the prev assertion
    ///         bytes32 inboxAcc:  the inbox accumulator of the assertion
    ///         For BigStep and SmallStep edges this is the abi encoding of:
    ///         bytes32: Start state - first state the edge commits to
    ///         bytes32: End state - last state the edge commits to
    ///         bytes32[]: Claim start inclusion proof - proof to show the start state is the first state in the claim edge
    ///         bytes32[]: Claim end inclusion proof - proof to show the end state is the last state in the claim edge
    ///         bytes32[]: Inclusion proof - proof to show that the end state is the last state in the end history root
    bytes proof;
}

/// @notice Data parsed raw proof data
struct ProofData {
    /// @notice The first state being committed to by an edge
    bytes32 startState;
    /// @notice The last state being committed to by an edge
    bytes32 endState;
    /// @notice A proof that the end state is included in the edge
    bytes32[] inclusionProof;
}

/// @notice Stores all edges and their rival status
struct EdgeStore {
    /// @notice A mapping of edge id to edges. Edges are never deleted, only created, and potentially confirmed.
    mapping(bytes32 => ChallengeEdge) edges;
    /// @notice A mapping of mutualId to edge id. Rivals share the same mutual id, and here we
    ///         store the edge id of the second edge that was created with the same mutual id - the first rival
    ///         When only one edge exists for a specific mutual id then a special magic string hash is stored instead
    ///         of the first rival id, to signify that a single edge does exist with this mutual id
    mapping(bytes32 => bytes32) firstRivals;
    /// @notice A mapping of mutualId to the edge id of the confirmed rival with that mutualId
    /// @dev    Each group of rivals (edges sharing mutual id) can only have at most one confirmed edge
    mapping(bytes32 => bytes32) confirmedRivals;
    /// @notice A mapping of account -> mutualId -> bool indicating if the account has created a layer zero edge with a mutual id
    mapping(address => mapping(bytes32 => bool)) hasMadeLayerZeroRival;
}

/// @notice Input data to a one step proof
struct OneStepData {
    /// @notice The hash of the state that's being executed from
    bytes32 beforeHash;
    /// @notice Proof data to accompany the execution context
    bytes proof;
}

/// @notice Data about a recently added edge
struct EdgeAddedData {
    bytes32 edgeId;
    bytes32 mutualId;
    bytes32 originId;
    bytes32 claimId;
    uint256 length;
    uint8 level;
    bool hasRival;
    bool isLayerZero;
}

/// @notice Data about an assertion that is being claimed by an edge
/// @dev    This extra information that is needed in order to verify that a block edge can be created
struct AssertionReferenceData {
    /// @notice The id of the assertion - will be used in a sanity check
    bytes32 assertionHash;
    /// @notice The predecessor of the assertion
    bytes32 predecessorId;
    /// @notice Is the assertion pending
    bool isPending;
    /// @notice Does the assertion have a sibling
    bool hasSibling;
    /// @notice The execution state of the predecessor assertion
    AssertionState startState;
    /// @notice The execution state of the assertion being claimed
    AssertionState endState;
}

/// @notice An edge committing to a range of states. These edges will be bisected, slowly
///         reducing them in length until they reach length one. At that point new edges of a different
///         level will be added that claim the result of this edge, or a one step proof will be calculated
///         if the edge level is already of type SmallStep.
struct ChallengeEdge {
    /// @notice The origin id is a link from the edge to an edge or assertion at a lower level.
    ///         Intuitively all edges with the same origin id agree on the information committed to in the origin id
    ///         For a SmallStep edge the origin id is the 'mutual' id of the length one BigStep edge being claimed by the zero layer ancestors of this edge
    ///         For a BigStep edge the origin id is the 'mutual' id of the length one Block edge being claimed by the zero layer ancestors of this edge
    ///         For a Block edge the origin id is the assertion hash of the assertion that is the root of the challenge - all edges in this challenge agree
    ///         that that assertion hash is valid.
    ///         The purpose of the origin id is to ensure that only edges that agree on a common start position
    ///         are being compared against one another.
    bytes32 originId;
    /// @notice A root of all the states in the history up to the startHeight
    bytes32 startHistoryRoot;
    /// @notice The height of the start history root
    uint256 startHeight;
    /// @notice A root of all the states in the history up to the endHeight. Since endHeight > startHeight, the startHistoryRoot must
    ///         commit to a prefix of the states committed to by the endHistoryRoot
    bytes32 endHistoryRoot;
    /// @notice The height of the end history root
    uint256 endHeight;
    /// @notice Edges can be bisected into two children. If this edge has been bisected the id of the
    ///         lower child is populated here, until that time this value is 0. The lower child has startHistoryRoot and startHeight
    ///         equal to this edge, but endHistoryRoot and endHeight equal to some prefix of the endHistoryRoot of this edge
    bytes32 lowerChildId;
    /// @notice Edges can be bisected into two children. If this edge has been bisected the id of the
    ///         upper child is populated here, until that time this value is 0. The upper child has startHistoryRoot and startHeight
    ///         equal to some prefix of the endHistoryRoot of this edge, and endHistoryRoot and endHeight equal to this edge
    bytes32 upperChildId;
    /// @notice The edge or assertion in the upper level that this edge claims to be true.
    ///         Only populated on zero layer edges
    bytes32 claimId;
    /// @notice The entity that supplied a mini-stake accompanying this edge
    ///         Only populated on zero layer edges
    address staker;
    /// @notice The block number when this edge was created
    uint64 createdAtBlock;
    /// @notice The block number at which this edge was confirmed
    ///         Zero if not confirmed
    uint64 confirmedAtBlock;
    /// @notice Current status of this edge. All edges are created Pending, and may be updated to Confirmed
    ///         Once Confirmed they cannot transition back to Pending
    EdgeStatus status;
    /// @notice The level of this edge.
    ///         Level 0 is type Block
    ///         Last level (defined by NUM_BIGSTEP_LEVEL + 1) is type SmallStep
    ///         All levels in between are of type BigStep
    uint8 level;
    /// @notice Set to true when the staker has been refunded. Can only be set to true if the status is Confirmed
    ///         and the staker is non zero.
    bool refunded;
    /// @notice TODO
    uint64 totalTimeUnrivaledCache;
}

// src/challengeV2/IEdgeChallengeManager.sol
// Copyright 2023, Offchain Labs, Inc.
// For license information, see https://github.com/offchainlabs/bold/blob/main/LICENSE

//

/// @title EdgeChallengeManager interface
interface IEdgeChallengeManager {
    /// @notice Initialize the EdgeChallengeManager. EdgeChallengeManagers are upgradeable
    ///         so use the initializer paradigm
    /// @param _assertionChain              The assertion chain contract
    /// @param _challengePeriodBlocks       The amount of cumulative time an edge must spend unrivaled before it can be confirmed
    ///                                     This should be the censorship period + the cumulative amount of time needed to do any
    ///                                     offchain calculation. We currently estimate around 10 mins for each layer zero edge and 1
    ///                                     one minute for each other edge.
    /// @param _oneStepProofEntry           The one step proof logic
    /// @param layerZeroBlockEdgeHeight     The end height of layer zero edges of type Block
    /// @param layerZeroBigStepEdgeHeight   The end height of layer zero edges of type BigStep
    /// @param layerZeroSmallStepEdgeHeight The end height of layer zero edges of type SmallStep
    /// @param _stakeToken                  The token that stake will be provided in when creating zero layer block edges
    /// @param _excessStakeReceiver         The address that excess stake will be sent to when 2nd+ block edge is created
    /// @param _numBigStepLevel             The number of bigstep levels
    /// @param _stakeAmounts                The stake amount for each level. (first element is for block level)
    function initialize(
        IAssertionChain _assertionChain,
        uint64 _challengePeriodBlocks,
        IOneStepProofEntry _oneStepProofEntry,
        uint256 layerZeroBlockEdgeHeight,
        uint256 layerZeroBigStepEdgeHeight,
        uint256 layerZeroSmallStepEdgeHeight,
        IERC20 _stakeToken,
        address _excessStakeReceiver,
        uint8 _numBigStepLevel,
        uint256[] calldata _stakeAmounts
    ) external;

    function stakeToken() external view returns (IERC20);

    function stakeAmounts(
        uint256
    ) external view returns (uint256);

    function challengePeriodBlocks() external view returns (uint64);

    /// @notice The one step proof resolver used to decide between rival SmallStep edges of length 1
    function oneStepProofEntry() external view returns (IOneStepProofEntry);

    /// @notice Performs necessary checks and creates a new layer zero edge
    /// @param args             Edge creation args
    function createLayerZeroEdge(
        CreateEdgeArgs calldata args
    ) external returns (bytes32);

    /// @notice Bisect an edge. This creates two child edges:
    ///         lowerChild: has the same start root and height as this edge, but a different end root and height
    ///         upperChild: has the same end root and height as this edge, but a different start root and height
    ///         The lower child end root and height are equal to the upper child start root and height. This height
    ///         is the mandatoryBisectionHeight.
    ///         The lower child may already exist, however it's not possible for the upper child to exist as that would
    ///         mean that the edge has already been bisected
    /// @param edgeId               Edge to bisect
    /// @param bisectionHistoryRoot The new history root to be used in the lower and upper children
    /// @param prefixProof          A proof to show that the bisectionHistoryRoot commits to a prefix of the current endHistoryRoot
    /// @return lowerChildId        The id of the newly created lower child edge
    /// @return upperChildId        The id of the newly created upper child edge
    function bisectEdge(
        bytes32 edgeId,
        bytes32 bisectionHistoryRoot,
        bytes calldata prefixProof
    ) external returns (bytes32, bytes32);

    /// @notice An edge can be confirmed if the total amount of time it and a single chain of its direct ancestors
    ///         has spent unrivaled is greater than the challenge period.
    /// @dev    Edges inherit time from their parents, so the sum of unrivaled timers is compared against the threshold.
    ///         Given that an edge cannot become unrivaled after becoming rivaled, once the threshold is passed
    ///         it will always remain passed. The direct ancestors of an edge are linked by parent-child links for edges
    ///         of the same level, and claimId-edgeId links for zero layer edges that claim an edge in the level below.
    ///         This method also includes the amount of time the assertion being claimed spent without a sibling
    /// @param edgeId                   The id of the edge to confirm
    function confirmEdgeByTime(
        bytes32 edgeId,
        AssertionStateData calldata claimStateData
    ) external;

    /// @notice Update multiple edges' timer cache by their children. Equivalent to calling updateTimerCacheByChildren for each edge.
    ///         May update timer cache above maximum if the last edge's timer cache was below maximumCachedTime.
    ///         Revert when the last edge's timer cache is already equal to or above maximumCachedTime.
    /// @param edgeIds           The ids of the edges to update
    /// @param maximumCachedTime The maximum amount of cached time allowed on the last edge (β∗)
    function multiUpdateTimeCacheByChildren(
        bytes32[] calldata edgeIds,
        uint256 maximumCachedTime
    ) external;

    /// @notice Update an edge's timer cache by its children.
    ///         Sets the edge's timer cache to its timeUnrivaled + (minimum timer cache of its children).
    ///         May update timer cache above maximum if the last edge's timer cache was below maximumCachedTime.
    ///         Revert when the edge's timer cache is already equal to or above maximumCachedTime.
    /// @param edgeId            The id of the edge to update
    /// @param maximumCachedTime The maximum amount of cached time allowed on the edge (β∗)
    function updateTimerCacheByChildren(bytes32 edgeId, uint256 maximumCachedTime) external;

    /// @notice Given a one step fork edge and an edge with matching claim id,
    ///         set the one step fork edge's timer cache to its timeUnrivaled + claiming edge's timer cache.
    ///         May update timer cache above maximum if the last edge's timer cache was below maximumCachedTime.
    ///         Revert when the edge's timer cache is already equal to or above maximumCachedTime.
    /// @param edgeId            The id of the edge to update
    /// @param claimingEdgeId    The id of the edge which has a claimId equal to edgeId
    /// @param maximumCachedTime The maximum amount of cached time allowed on the edge (β∗)
    function updateTimerCacheByClaim(
        bytes32 edgeId,
        bytes32 claimingEdgeId,
        uint256 maximumCachedTime
    ) external;

    /// @notice Confirm an edge by executing a one step proof
    /// @dev    One step proofs can only be executed against edges that have length one and of type SmallStep
    /// @param edgeId                       The id of the edge to confirm
    /// @param oneStepData                  Input data to the one step proof
    /// @param prevConfig                     Data about the config set in prev
    /// @param beforeHistoryInclusionProof  Proof that the state which is the start of the edge is committed to by the startHistoryRoot
    /// @param afterHistoryInclusionProof   Proof that the state which is the end of the edge is committed to by the endHistoryRoot
    function confirmEdgeByOneStepProof(
        bytes32 edgeId,
        OneStepData calldata oneStepData,
        ConfigData calldata prevConfig,
        bytes32[] calldata beforeHistoryInclusionProof,
        bytes32[] calldata afterHistoryInclusionProof
    ) external;

    /// @notice When zero layer block edges are created a stake is also provided
    ///         The stake on this edge can be refunded if the edge is confirme
    function refundStake(
        bytes32 edgeId
    ) external;

    /// @notice Zero layer edges have to be a fixed height.
    ///         This function returns the end height for a given edge type
    function getLayerZeroEndHeight(
        EdgeType eType
    ) external view returns (uint256);

    /// @notice Calculate the unique id of an edge
    /// @param level            The level of the edge
    /// @param originId         The origin id of the edge
    /// @param startHeight      The start height of the edge
    /// @param startHistoryRoot The start history root of the edge
    /// @param endHeight        The end height of the edge
    /// @param endHistoryRoot   The end history root of the edge
    function calculateEdgeId(
        uint8 level,
        bytes32 originId,
        uint256 startHeight,
        bytes32 startHistoryRoot,
        uint256 endHeight,
        bytes32 endHistoryRoot
    ) external pure returns (bytes32);

    /// @notice Calculate the mutual id of the edge
    ///         Edges that are rivals share the same mutual id
    /// @param level            The level of the edge
    /// @param originId         The origin id of the edge
    /// @param startHeight      The start height of the edge
    /// @param startHistoryRoot The start history root of the edge
    /// @param endHeight        The end height of the edge
    function calculateMutualId(
        uint8 level,
        bytes32 originId,
        uint256 startHeight,
        bytes32 startHistoryRoot,
        uint256 endHeight
    ) external pure returns (bytes32);

    /// @notice Has the edge already been stored in the manager
    function edgeExists(
        bytes32 edgeId
    ) external view returns (bool);

    /// @notice Get full edge data for an edge
    function getEdge(
        bytes32 edgeId
    ) external view returns (ChallengeEdge memory);

    /// @notice The length of the edge, from start height to end height
    function edgeLength(
        bytes32 edgeId
    ) external view returns (uint256);

    /// @notice Does this edge currently have one or more rivals
    ///         Rival edges share the same mutual id
    function hasRival(
        bytes32 edgeId
    ) external view returns (bool);

    /// @notice The confirmed rival of this mutual id
    ///         Returns 0 if one does not exist
    function confirmedRival(
        bytes32 mutualId
    ) external view returns (bytes32);

    /// @notice Does the edge have at least one rival, and it has length one
    function hasLengthOneRival(
        bytes32 edgeId
    ) external view returns (bool);

    /// @notice The amount of time this edge has spent without rivals
    ///         This value is increasing whilst an edge is unrivaled, once a rival is created
    ///         it is fixed. If an edge has rivals from the moment it is created then it will have
    ///         a zero time unrivaled
    function timeUnrivaled(
        bytes32 edgeId
    ) external view returns (uint256);

    /// @notice Get the id of the prev assertion that this edge is originates from
    /// @dev    Uses the parent chain to traverse upwards SmallStep->BigStep->Block->Assertion
    ///         until it gets to the origin assertion
    function getPrevAssertionHash(
        bytes32 edgeId
    ) external view returns (bytes32);

    /// @notice Fetch the raw first rival record for the given mutual id
    /// @dev    Returns 0 if there is no edge with the given mutual id
    ///         Returns a magic value if there is one edge but it is unrivaled
    ///         Returns the id of the second edge created with the mutual id, if > 1 exists
    function firstRival(
        bytes32 mutualId
    ) external view returns (bytes32);

    /// @notice True if an account has made a layer zero edge with the given mutual id.
    ///         This is only tracked when the validator whitelist is enabled
    function hasMadeLayerZeroRival(
        address account,
        bytes32 mutualId
    ) external view returns (bool);
}

// src/rollup/IRollupCore.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

interface IRollupCore is IAssertionChain {
    struct Staker {
        uint256 amountStaked;
        bytes32 latestStakedAssertion;
        uint64 index;
        bool isStaked;
        address withdrawalAddress;
    }

    event RollupInitialized(bytes32 machineHash, uint256 chainId);

    event AssertionCreated(
        bytes32 indexed assertionHash,
        bytes32 indexed parentAssertionHash,
        AssertionInputs assertion,
        bytes32 afterInboxBatchAcc,
        uint256 inboxMaxCount,
        bytes32 wasmModuleRoot,
        uint256 requiredStake,
        address challengeManager,
        uint64 confirmPeriodBlocks
    );

    event AssertionConfirmed(bytes32 indexed assertionHash, bytes32 blockHash, bytes32 sendRoot);

    event RollupChallengeStarted(
        uint64 indexed challengeIndex,
        address asserter,
        address challenger,
        uint64 challengedAssertion
    );

    event UserStakeUpdated(
        address indexed user,
        address indexed withdrawalAddress,
        uint256 initialBalance,
        uint256 finalBalance
    );

    event UserWithdrawableFundsUpdated(
        address indexed user, uint256 initialBalance, uint256 finalBalance
    );

    function confirmPeriodBlocks() external view returns (uint64);

    function validatorAfkBlocks() external view returns (uint64);

    function chainId() external view returns (uint256);

    function baseStake() external view returns (uint256);

    function wasmModuleRoot() external view returns (bytes32);

    function bridge() external view returns (IBridge);

    function sequencerInbox() external view returns (ISequencerInbox);

    function outbox() external view returns (IOutbox);

    function rollupEventInbox() external view returns (IRollupEventInbox);

    function challengeManager() external view returns (IEdgeChallengeManager);

    function loserStakeEscrow() external view returns (address);

    function stakeToken() external view returns (address);

    function minimumAssertionPeriod() external view returns (uint256);

    function genesisAssertionHash() external pure returns (bytes32);

    /**
     * @notice Get the Assertion for the given id.
     */
    function getAssertion(
        bytes32 assertionHash
    ) external view returns (AssertionNode memory);

    /**
     * @notice Returns the block in which the given assertion was created for looking up its creation event.
     * Unlike the assertion's createdAtBlock field, this will be the ArbSys blockNumber if the host chain is an Arbitrum chain.
     * That means that the block number returned for this is usable for event queries.
     * This function will revert if the given assertion hash does not exist.
     * @dev This function is meant for internal use only and has no stability guarantees.
     */
    function getAssertionCreationBlockForLogLookup(
        bytes32 assertionHash
    ) external view returns (uint256);

    /**
     * @notice Get the address of the staker at the given index
     * @param stakerNum Index of the staker
     * @return Address of the staker
     */
    function getStakerAddress(
        uint64 stakerNum
    ) external view returns (address);

    /**
     * @notice Check whether the given staker is staked
     * @param staker Staker address to check
     * @return True or False for whether the staker was staked
     */
    function isStaked(
        address staker
    ) external view returns (bool);

    /**
     * @notice Get the latest staked assertion of the given staker
     * @param staker Staker address to lookup
     * @return Latest assertion staked of the staker
     */
    function latestStakedAssertion(
        address staker
    ) external view returns (bytes32);

    /**
     * @notice Get the amount staked of the given staker
     * @param staker Staker address to lookup
     * @return Amount staked of the staker
     */
    function amountStaked(
        address staker
    ) external view returns (uint256);

    /**
     * @notice Get the withdrawal address of the given staker
     * @param staker Staker address to lookup
     * @return Withdrawal address of the staker
     */
    function withdrawalAddress(
        address staker
    ) external view returns (address);

    /**
     * @notice Retrieves stored information about a requested staker
     * @param staker Staker address to retrieve
     * @return A structure with information about the requested staker
     */
    function getStaker(
        address staker
    ) external view returns (Staker memory);

    /**
     * @notice Get the amount of funds withdrawable by the given address
     * @param owner Address to check the funds of
     * @return Amount of funds withdrawable by owner
     */
    function withdrawableFunds(
        address owner
    ) external view returns (uint256);
    /// @return Hash of the latest confirmed assertion
    function latestConfirmed() external view returns (bytes32);

    /// @return Number of active stakers currently staked
    function stakerCount() external view returns (uint64);
}

// src/rollup/IRollupLogic.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

interface IRollupUser is IRollupCore, IOwnable {
    /// @dev the user logic just validated configuration and shouldn't write to state during init
    /// this allows the admin logic to ensure consistency on parameters.
    function initialize(
        address stakeToken
    ) external view;

    function removeWhitelistAfterFork() external;

    function removeWhitelistAfterValidatorAfk() external;

    function confirmAssertion(
        bytes32 assertionHash,
        bytes32 prevAssertionHash,
        AssertionState calldata confirmState,
        bytes32 winningEdgeId,
        ConfigData calldata prevConfig,
        bytes32 inboxAcc
    ) external;

    function stakeOnNewAssertion(
        AssertionInputs calldata assertion,
        bytes32 expectedAssertionHash
    ) external;

    function returnOldDeposit() external;

    function returnOldDepositFor(
        address stakerAddress
    ) external;

    function reduceDeposit(
        uint256 target
    ) external;

    function withdrawStakerFunds() external returns (uint256);

    function newStakeOnNewAssertion(
        uint256 tokenAmount,
        AssertionInputs calldata assertion,
        bytes32 expectedAssertionHash
    ) external;

    function newStakeOnNewAssertion(
        uint256 tokenAmount,
        AssertionInputs calldata assertion,
        bytes32 expectedAssertionHash,
        address withdrawalAddress
    ) external;

    function newStake(uint256 tokenAmount, address withdrawalAddress) external;

    function addToDeposit(
        address stakerAddress,
        address expectedWithdrawalAddress,
        uint256 tokenAmount
    ) external;
}

// src/rollup/Config.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

struct Config {
    uint64 confirmPeriodBlocks;
    address stakeToken;
    uint256 baseStake;
    bytes32 wasmModuleRoot;
    address owner;
    address loserStakeEscrow;
    uint256 chainId;
    string chainConfig;
    uint256 minimumAssertionPeriod;
    uint64 validatorAfkBlocks;
    uint256[] miniStakeValues;
    ISequencerInbox.MaxTimeVariation sequencerInboxMaxTimeVariation;
    uint256 layerZeroBlockEdgeHeight;
    uint256 layerZeroBigStepEdgeHeight;
    uint256 layerZeroSmallStepEdgeHeight;
    /// @notice The execution state to be used in the genesis assertion
    AssertionState genesisAssertionState;
    /// @notice The inbox size at the time the genesis execution state was created
    uint256 genesisInboxCount;
    address anyTrustFastConfirmer;
    uint8 numBigStepLevel;
    uint64 challengeGracePeriodBlocks;
    BufferConfig bufferConfig;
}

struct ContractDependencies {
    IBridge bridge;
    ISequencerInbox sequencerInbox;
    IInboxBase inbox;
    IOutbox outbox;
    IRollupEventInbox rollupEventInbox;
    IEdgeChallengeManager challengeManager;
    address rollupAdminLogic; // this cannot be IRollupAdmin because of circular dependencies
    IRollupUser rollupUserLogic;
    address validatorWalletCreator;
}

// src/rollup/IRollupAdmin.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

interface IRollupAdmin {
    /// @dev Outbox address was set
    event OutboxSet(address outbox);

    /// @dev Old outbox was removed
    event OldOutboxRemoved(address outbox);

    /// @dev Inbox was enabled or disabled
    event DelayedInboxSet(address inbox, bool enabled);

    /// @dev A list of validators was set
    event ValidatorsSet(address[] validators, bool[] enabled);

    /// @dev A new minimum assertion period was set
    event MinimumAssertionPeriodSet(uint256 newPeriod);

    /// @dev A new validator afk blocks was set
    event ValidatorAfkBlocksSet(uint256 newPeriod);

    /// @dev New confirm period blocks was set
    event ConfirmPeriodBlocksSet(uint64 newConfirmPeriod);

    /// @dev Base stake was set
    event BaseStakeSet(uint256 newBaseStake);

    /// @dev Stakers were force refunded
    event StakersForceRefunded(address[] staker);

    /// @dev An assertion was force created
    event AssertionForceCreated(bytes32 indexed assertionHash);

    /// @dev An assertion was force confirmed
    event AssertionForceConfirmed(bytes32 indexed assertionHash);

    /// @dev New loser stake escrow set
    event LoserStakeEscrowSet(address newLoserStakerEscrow);

    /// @dev New wasm module root was set
    event WasmModuleRootSet(bytes32 newWasmModuleRoot);

    /// @dev New sequencer inbox was set
    event SequencerInboxSet(address newSequencerInbox);

    /// @dev New inbox set
    event InboxSet(address inbox);

    /// @dev Validator whitelist was disabled or enabled
    event ValidatorWhitelistDisabledSet(bool _validatorWhitelistDisabled);

    /// @dev AnyTrust fast confirmer was set
    event AnyTrustFastConfirmerSet(address anyTrustFastConfirmer);

    /// @dev Challenge manager was set
    event ChallengeManagerSet(address challengeManager);

    function initialize(
        Config calldata config,
        ContractDependencies calldata connectedContracts
    ) external;

    /**
     * @notice Add a contract authorized to put messages into this rollup's inbox
     * @param _outbox Outbox contract to add
     */
    function setOutbox(
        IOutbox _outbox
    ) external;

    /**
     * @notice Disable an old outbox from interacting with the bridge
     * @param _outbox Outbox contract to remove
     */
    function removeOldOutbox(
        address _outbox
    ) external;

    /**
     * @notice Enable or disable an inbox contract
     * @param _inbox Inbox contract to add or remove
     * @param _enabled New status of inbox
     */
    function setDelayedInbox(address _inbox, bool _enabled) external;

    /**
     * @notice Pause interaction with the rollup contract
     */
    function pause() external;

    /**
     * @notice Resume interaction with the rollup contract
     */
    function resume() external;

    /**
     * @notice Set the addresses of the validator whitelist
     * @dev It is expected that both arrays are same length, and validator at
     * position i corresponds to the value at position i
     * @param _validator addresses to set in the whitelist
     * @param _val value to set in the whitelist for corresponding address
     */
    function setValidator(address[] memory _validator, bool[] memory _val) external;

    /**
     * @notice Set a new owner address for the rollup proxy
     * @param newOwner address of new rollup owner
     */
    function setOwner(
        address newOwner
    ) external;

    /**
     * @notice Set minimum assertion period for the rollup
     * @param newPeriod new minimum period for assertions
     */
    function setMinimumAssertionPeriod(
        uint256 newPeriod
    ) external;

    /**
     * @notice Set validator afk blocks for the rollup
     * @param  newAfkBlocks new number of blocks before a validator is considered afk (0 to disable)
     * @dev    ValidatorAfkBlocks is the number of blocks since the last confirmed
     *         assertion (or its first child) before the validator whitelist is removed.
     *         It's important that this time is greater than the max amount of time it can take to
     *         to confirm an assertion via the normal method. Therefore we need it to be greater
     *         than max(2* confirmPeriod, 2 * challengePeriod) with some additional margin.
     */
    function setValidatorAfkBlocks(
        uint64 newAfkBlocks
    ) external;

    /**
     * @notice Set number of blocks until a assertion is considered confirmed
     * @param newConfirmPeriod new number of blocks until a assertion is confirmed
     */
    function setConfirmPeriodBlocks(
        uint64 newConfirmPeriod
    ) external;

    /**
     * @notice Set base stake required for an assertion
     * @param newBaseStake maximum avmgas to be used per block
     */
    function setBaseStake(
        uint256 newBaseStake
    ) external;

    function forceRefundStaker(
        address[] memory stacker
    ) external;

    function forceCreateAssertion(
        bytes32 prevAssertionHash,
        AssertionInputs calldata assertion,
        bytes32 expectedAssertionHash
    ) external;

    function forceConfirmAssertion(
        bytes32 assertionHash,
        bytes32 parentAssertionHash,
        AssertionState calldata confirmState,
        bytes32 inboxAcc
    ) external;

    function setLoserStakeEscrow(
        address newLoserStakerEscrow
    ) external;

    /**
     * @notice Set the proving WASM module root
     * @param newWasmModuleRoot new module root
     */
    function setWasmModuleRoot(
        bytes32 newWasmModuleRoot
    ) external;

    /**
     * @notice set a new sequencer inbox contract
     * @param _sequencerInbox new address of sequencer inbox
     */
    function setSequencerInbox(
        address _sequencerInbox
    ) external;

    /**
     * @notice set the validatorWhitelistDisabled flag
     * @param _validatorWhitelistDisabled new value of validatorWhitelistDisabled, i.e. true = disabled
     */
    function setValidatorWhitelistDisabled(
        bool _validatorWhitelistDisabled
    ) external;

    /**
     * @notice set the anyTrustFastConfirmer address
     * @param _anyTrustFastConfirmer new value of anyTrustFastConfirmer
     */
    function setAnyTrustFastConfirmer(
        address _anyTrustFastConfirmer
    ) external;

    /**
     * @notice set a new challengeManager contract
     * @param _challengeManager new value of challengeManager
     */
    function setChallengeManager(
        address _challengeManager
    ) external;
}

// src/rollup/RollupProxy.sol
// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/OffchainLabs/nitro-contracts/blob/main/LICENSE

contract RollupProxy is AdminFallbackProxy {
    function initializeProxy(
        Config memory config,
        ContractDependencies memory connectedContracts
    ) external {
        if (
            _getAdmin() == address(0) && _getImplementation() == address(0)
                && _getSecondaryImplementation() == address(0)
        ) {
            _initialize(
                address(connectedContracts.rollupAdminLogic),
                abi.encodeCall(IRollupAdmin.initialize, (config, connectedContracts)),
                address(connectedContracts.rollupUserLogic),
                abi.encodeCall(IRollupUser.initialize, (config.stakeToken)),
                config.owner
            );
        } else {
            _fallback();
        }
    }
}