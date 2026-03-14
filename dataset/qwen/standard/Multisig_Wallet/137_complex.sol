// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

contract MultiSigWallet {
    event ExecutionSuccess(bytes32 indexed txHash, uint256 payment);
    event ExecutionFailure(bytes32 indexed txHash);
    event SafeSetup(address indexed initializer, uint256 threshold);
    event AddedOwner(address indexed owner);
    event RemovedOwner(address indexed owner);
    event ChangedThreshold(uint256 threshold);
    event EnabledModule(address indexed module);
    event DisabledModule(address indexed module);

    uint256 public nonce;
    uint256 public threshold;
    mapping(address => bool) public isOwner;
    address[] public owners;
    mapping(address => bool) public isModuleEnabled;
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = keccak256("EIP712Domain(uint256 chainId,address verifyingContract)");
    bytes32 private constant SAFE_TX_TYPEHASH = keccak256("SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)");
    bytes32 private domainSeparator;

    struct SafeTx {
        address to;
        uint256 value;
        bytes data;
        uint8 operation;
        uint256 safeTxGas;
        uint256 baseGas;
        uint256 gasPrice;
        address gasToken;
        address refundReceiver;
        uint256 nonce;
    }

    modifier onlySelf() {
        require(msg.sender == address(this), "External calls not allowed");
        _;
    }

    modifier onlyModule() {
        require(isModuleEnabled[msg.sender], "Module not enabled");
        _;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length > 0, "Owners required");
        require(_threshold > 0 && _threshold <= _owners.length, "Threshold out of bounds");

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Owner cannot be 0");
            require(!isOwner[owner], "Owner already added");
            isOwner[owner] = true;
            owners.push(owner);
        }
        threshold = _threshold;
        domainSeparator = keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, block.chainid, address(this)));
        emit SafeSetup(msg.sender, threshold);
    }

    function addOwnerWithThreshold(address owner, uint256 _threshold) external onlySelf {
        require(owner != address(0), "Owner cannot be 0");
        require(!isOwner[owner], "Owner already added");
        isOwner[owner] = true;
        owners.push(owner);
        changeThreshold(_threshold);
    }

    function removeOwner(address prevOwner, address owner, uint256 _threshold) external onlySelf {
        require(isOwner[owner], "Owner not found");
        require(isOwner[prevOwner], "Prev owner not found");
        require(owner != prevOwner, "Prev owner and owner cannot be the same");

        uint256 ownerIndex = owners.length;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == owner) {
                ownerIndex = i;
                break;
            }
        }
        require(ownerIndex < owners.length, "Owner not found");

        if (ownerIndex < owners.length - 1) {
            owners[ownerIndex] = owners[owners.length - 1];
        }
        owners.pop();

        isOwner[owner] = false;

        changeThreshold(_threshold);
    }

    function changeThreshold(uint256 _threshold) public onlySelf {
        require(_threshold > 0 && _threshold <= owners.length, "Threshold out of bounds");
        threshold = _threshold;
        emit ChangedThreshold(threshold);
    }

    function setupModules(address[] calldata modules) external onlySelf {
        for (uint256 i = 0; i < modules.length; i++) {
            enableModule(modules[i]);
        }
    }

    function enableModule(address module) public onlySelf {
        require(module != address(0), "Module cannot be 0");
        require(!isModuleEnabled[module], "Module already enabled");
        isModuleEnabled[module] = true;
        emit EnabledModule(module);
    }

    function disableModule(address prevModule, address module) public onlySelf {
        require(isModuleEnabled[module], "Module not enabled");
        require(isModuleEnabled[prevModule], "Prev module not enabled");
        require(module != prevModule, "Prev module and module cannot be the same");

        uint256 moduleIndex = owners.length;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == module) {
                moduleIndex = i;
                break;
            }
        }
        require(moduleIndex < owners.length, "Module not found");

        if (moduleIndex < owners.length - 1) {
            owners[moduleIndex] = owners[owners.length - 1];
        }
        owners.pop();

        isModuleEnabled[module] = false;
        emit DisabledModule(module);
    }

    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) public returns (bool success) {
        bytes32 txHash = encodeTransactionData(
            SafeTx({
                to: to,
                value: value,
                data: data,
                operation: operation,
                safeTxGas: safeTxGas,
                baseGas: baseGas,
                gasPrice: gasPrice,
                gasToken: gasToken,
                refundReceiver: refundReceiver,
                nonce: nonce
            })
        );
        require(checkSignatures(txHash, to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, signatures), "Invalid signatures");
        nonce++;

        if (gasPrice > 0) {
            require(gasleft() >= safeTxGas + baseGas, "Not enough gas");
        }

        uint256 gasUsed = gasleft();
        success = execute(to, value, data, operation);
        gasUsed = gasUsed.sub(gasleft());

        uint256 payment = 0;
        if (gasPrice > 0) {
            payment = gasUsed.add(baseGas).mul(gasPrice);
            if (gasToken != address(0)) {
                require(IToken(gasToken).transfer(msg.sender, payment), "Could not pay gas costs with token");
            } else if (refundReceiver != address(0)) {
                refundReceiver.transfer(payment);
            }
        }

        if (success) emit ExecutionSuccess(txHash, payment);
        else emit ExecutionFailure(txHash);
    }

    function execute(
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation
    ) internal returns (bool success) {
        if (operation == 0) {
            success = executeCall(to, value, data);
        } else if (operation == 1) {
            success = executeDelegateCall(to, data);
        }
    }

    function executeCall(
        address to,
        uint256 value,
        bytes memory data
    ) internal returns (bool success) {
        (success,) = to.call{value: value}(data);
    }

    function executeDelegateCall(
        address to,
        bytes memory data
    ) internal returns (bool success) {
        (success,) = to.delegatecall(data);
    }

    function encodeTransactionData(SafeTx memory safeTx) public view returns (bytes32) {
        bytes32 safeTxHash = keccak256(
            abi.encode(
                SAFE_TX_TYPEHASH,
                safeTx.to,
                safeTx.value,
                keccak256(safeTx.data),
                safeTx.operation,
                safeTx.safeTxGas,
                safeTx.baseGas,
                safeTx.gasPrice,
                safeTx.gasToken,
                safeTx.refundReceiver,
                safeTx.nonce
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, safeTxHash));
    }

    function checkSignatures(
        bytes32 txHash,
        address to,
        uint256 value,
        bytes memory data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) public view returns (bool) {
        bytes32 safeTxHash = encodeTransactionData(
            SafeTx({
                to: to,
                value: value,
                data: data,
                operation: operation,
                safeTxGas: safeTxGas,
                baseGas: baseGas,
                gasPrice: gasPrice,
                gasToken: gasToken,
                refundReceiver: refundReceiver,
                nonce: nonce
            })
        );
        return hasEnoughSignatures(safeTxHash, signatures);
    }

    function hasEnoughSignatures(bytes32 txHash, bytes memory signatures) public view returns (bool) {
        uint256 sigCount = 0;
        mapping(address => bool) seen;
        for (uint256 i = 0; i < signatures.length; i += 65) {
            address signer = recoverSigner(txHash, signatures[i], signatures[i + 1], signatures[i + 2]);
            if (isOwner[signer] && !seen[signer]) {
                seen[signer] = true;
                sigCount++;
            }
            if (sigCount == threshold) return true;
        }
        return false;
    }

    function recoverSigner(bytes32 hash, bytes32 r, bytes32 s, uint8 v) internal pure returns (address) {
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "Invalid signature 's' value");
        require(v == 27 || v == 28, "Invalid signature 'v' value");

        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "Invalid signature");

        return signer;
    }

    fallback() external payable {}
}

interface IToken {
    function transfer(address to, uint256 value) external returns (bool);
}