// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IModule {
    function execute(address to, uint256 value, bytes calldata data) external returns (bool);
}

interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4);
}

contract MultisigWallet {
    event ExecuteTransaction(address indexed owner, address indexed to, uint256 value, bytes data, bool success);
    event Deposit(address indexed sender, uint256 value);
    event ModuleAdded(address module);
    event ModuleRemoved(address module);

    mapping(address => bool) public owners;
    mapping(address => bool) public modules;
    uint256 public required;
    uint256 public nonce;
    address[] public ownerList;

    modifier onlyOwner() {
        require(owners[msg.sender], "Not an owner");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number of confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!owners[owner], "Owner not unique");

            owners[owner] = true;
            ownerList.push(owner);
        }
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function addModule(address module) external onlyOwner {
        require(module != address(0), "Invalid module address");
        modules[module] = true;
        emit ModuleAdded(module);
    }

    function removeModule(address module) external onlyOwner {
        require(modules[module], "Module not exists");
        modules[module] = false;
        emit ModuleRemoved(module);
    }

    function executeTransaction(
        address to,
        uint256 value,
        bytes memory data,
        bytes[] memory signatures
    ) public returns (bool) {
        require(signatures.length >= required, "Not enough signatures");

        bytes32 txHash = keccak256(abi.encodePacked(nonce, to, value, data));
        nonce++;

        for (uint256 i = 0; i < signatures.length; i++) {
            address signer = recoverSigner(txHash, signatures[i]);
            require(owners[signer], "Invalid signer");
        }

        (bool success,) = to.call{value: value}(data);
        emit ExecuteTransaction(msg.sender, to, value, data, success);
        return success;
    }

    function executeModuleTransaction(
        address module,
        address to,
        uint256 value,
        bytes memory data
    ) public onlyOwner returns (bool) {
        require(modules[module], "Module not enabled");
        bool success = IModule(module).execute(to, value, data);
        emit ExecuteTransaction(msg.sender, to, value, data, success);
        return success;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4) {
        address signer = recoverSigner(hash, signature);
        if (owners[signer]) {
            return bytes4(keccak256("isValidSignature(bytes32,bytes)"));
        } else {
            return 0xffffffff;
        }
    }

    function recoverSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address) {
        require(_signature.length == 65, "Invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := byte(0, mload(add(_signature, 0x60)))
        }
        return ecrecover(_hash, v, r, s);
    }
}