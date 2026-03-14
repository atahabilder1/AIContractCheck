// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ISignatureValidator {
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

contract MultiSigWallet is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ECDSA for bytes32;

    EnumerableSet.AddressSet private owners;
    uint256 private required;
    mapping(bytes32 => bool) private executed;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event Execution(address indexed sender, address indexed to, uint256 value, bytes data);
    event ExecutionFailed(address indexed to, uint256 value, bytes data);
    event OwnerAdded(address owner);
    event OwnerRemoved(address owner);

    modifier onlyOwner() {
        require(owners.contains(msg.sender), "MultiSigWallet: caller is not an owner");
        _;
    }

    modifier onlyValidSignature(bytes32 hash, bytes memory signature) {
        require(ISignatureValidator(msg.sender).isValidSignature(hash, signature) == 0x1626ba7e, "MultiSigWallet: signature is not valid");
        _;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "MultiSigWallet: at least one owner is required");
        require(_required > 0 && _required <= _owners.length, "MultiSigWallet: invalid required number of owners");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "MultiSigWallet: owner is the zero address");
            require(!owners.contains(owner), "MultiSigWallet: owner is already added");
            owners.add(owner);
        }

        required = _required;
    }

    function addOwner(address owner) public onlyOwner {
        require(owner != address(0), "MultiSigWallet: owner is the zero address");
        require(!owners.contains(owner), "MultiSigWallet: owner is already added");
        owners.add(owner);
        emit OwnerAdded(owner);
    }

    function removeOwner(address owner) public onlyOwner {
        require(owners.contains(owner), "MultiSigWallet: owner is not in the list");
        require(owners.length - 1 >= required, "MultiSigWallet: number of owners is less than required");
        owners.remove(owner);
        emit OwnerRemoved(owner);
    }

    function setRequired(uint256 _required) public onlyOwner {
        require(_required > 0 && _required <= owners.length, "MultiSigWallet: invalid required number of owners");
        required = _required;
    }

    function execute(address to, uint256 value, bytes memory data, bytes[] memory signatures) public payable onlyOwner returns (bytes memory) {
        require(to != address(0), "MultiSigWallet: to is the zero address");
        require(!executed[keccak256(abi.encode(to, value, data))], "MultiSigWallet: transaction is already executed");
        require(signatures.length >= required, "MultiSigWallet: not enough signatures");

        bytes32 hash = keccak256(abi.encodePacked(to, value, data));
        uint256 count = 0;

        for (uint256 i = 0; i < signatures.length; i++) {
            require(owners.contains(ecrecover(hash, signatures[i][64], signatures[i][0], signatures[i][32])), "MultiSigWallet: invalid signature");
            if (ecrecover(hash, signatures[i][64], signatures[i][0], signatures[i][32]) == msg.sender) {
                count++;
            }
        }

        require(count >= required, "MultiSigWallet: not enough owner signatures");

        executed[hash] = true;
        (bool success, bytes memory result) = to.call{value: value}(data);
        if (success) {
            emit Execution(msg.sender, to, value, data);
            return result;
        } else {
            emit ExecutionFailed(to, value, data);
            return abi.encodePacked(bytes4(0), "MultiSigWallet: execution failed");
        }
    }

    function getOwners() public view returns (address[] memory) {
        return owners.values();
    }

    function getRequired() public view returns (uint256) {
        return required;
    }
}