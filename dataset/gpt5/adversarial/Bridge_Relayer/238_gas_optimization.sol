// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BridgeRelayer {
    // Storage
    address public owner;
    address public signer;
    mapping(bytes32 => uint256) public executed; // 1 if executed

    // Errors
    error NotOwner();
    error NotAuthorized();
    error AlreadyExecuted();
    error BadSignatureLength();
    error InvalidValue();

    // Events
    event OwnerUpdated(address indexed owner);
    event SignerUpdated(address indexed signer);
    event Relayed(bytes32 indexed id, address indexed target, uint256 value);

    constructor(address _owner, address _signer) {
        owner = _owner == address(0) ? msg.sender : _owner;
        signer = _signer;
        emit OwnerUpdated(owner);
        emit SignerUpdated(signer);
    }

    // Admin
    function setOwner(address _owner) external {
        if (msg.sender != owner) revert NotOwner();
        owner = _owner;
        emit OwnerUpdated(_owner);
    }

    function setSigner(address _signer) external {
        if (msg.sender != owner) revert NotOwner();
        signer = _signer;
        emit SignerUpdated(_signer);
    }

    // Relay a message authorized by the current signer
    function relay(address target, uint256 value, bytes32 salt, bytes calldata data, bytes calldata signature) external payable {
        if (msg.value != value) revert InvalidValue();
        if (signature.length != 65) revert BadSignatureLength();

        bytes32 id = keccak256(
            abi.encodePacked(address(this), uint256(block.chainid), target, value, keccak256(data), salt)
        );

        if (executed[id] != 0) revert AlreadyExecuted();

        // Recover signer
        bytes32 ethHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", id)
        );

        address recovered;
        unchecked {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                // signature is in calldata, load r, s, v
                let sigPtr := signature.offset
                r := calldataload(sigPtr)
                s := calldataload(add(sigPtr, 0x20))
                v := byte(0, calldataload(add(sigPtr, 0x40)))
            }
            recovered = ecrecover(ethHash, v, r, s);
        }
        if (recovered == address(0) || recovered != signer) revert NotAuthorized();

        // Effects first to prevent reentrancy on the same id
        executed[id] = 1;

        // Interaction
        (bool ok, bytes memory ret) = target.call{value: value}(data);
        if (!ok) {
            assembly {
                if gt(mload(ret), 0) {
                    revert(add(ret, 32), mload(ret))
                }
                revert(0, 0)
            }
        }

        emit Relayed(id, target, value);
    }

    // Helpers
    function isExecuted(bytes32 id) external view returns (bool) {
        return executed[id] != 0;
    }

    function computeMessageId(address target, uint256 value, bytes32 salt, bytes calldata data) external view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), uint256(block.chainid), target, value, keccak256(data), salt));
    }

    // Admin rescue
    function sweep(address to) external {
        if (msg.sender != owner) revert NotOwner();
        (bool ok, ) = to.call{value: address(this).balance}("");
        require(ok);
    }

    receive() external payable {}
}