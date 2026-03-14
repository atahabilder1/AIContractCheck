// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IModule {
    function execute(address to, uint256 value, bytes calldata data) external returns (bool);
}

interface IERC1271 {
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4);
}

contract MultisigWallet is IERC1271 {
    bytes4 constant EIP1271_MAGIC = 0x1626ba7e;

    event ExecutionSuccess(bytes32 indexed txHash);
    event ExecutionFailure(bytes32 indexed txHash);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdChanged(uint256 threshold);
    event ModuleEnabled(address indexed module);
    event ModuleDisabled(address indexed module);

    address internal constant SENTINEL = address(0x1);

    mapping(address => address) public owners;
    uint256 public ownerCount;
    uint256 public threshold;
    uint256 public nonce;

    mapping(address => address) public modules;

    mapping(bytes32 => uint256) public approvedHashes;

    enum Operation { Call, DelegateCall }

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length >= _threshold && _threshold > 0, "Invalid threshold");

        address current = SENTINEL;
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0) && owner != SENTINEL && owners[owner] == address(0), "Invalid owner");
            owners[current] = owner;
            current = owner;
        }
        owners[current] = SENTINEL;
        ownerCount = _owners.length;
        threshold = _threshold;
        modules[SENTINEL] = SENTINEL;
    }

    receive() external payable {}

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external returns (bool success) {
        uint256 startGas = gasleft();

        bytes32 txHash = getTransactionHash(
            to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce
        );
        nonce++;

        _checkSignatures(txHash, signatures);

        if (safeTxGas > 0) {
            require(gasleft() >= safeTxGas * 64 / 63 + 2500, "Not enough gas");
        }

        success = _execute(to, value, data, operation, safeTxGas == 0 ? gasleft() : safeTxGas);

        if (success) {
            emit ExecutionSuccess(txHash);
        } else {
            emit ExecutionFailure(txHash);
        }

        if (gasPrice > 0) {
            uint256 gasUsed = startGas - gasleft() + baseGas;
            uint256 payment = gasUsed * gasPrice;
            address receiver = refundReceiver == address(0) ? payable(msg.sender) : refundReceiver;

            if (gasToken == address(0)) {
                (bool refundSuccess,) = receiver.call{value: payment}("");
                require(refundSuccess, "Gas refund failed");
            } else {
                (bool refundSuccess, bytes memory ret) = gasToken.call(
                    abi.encodeWithSignature("transfer(address,uint256)", receiver, payment)
                );
                require(refundSuccess && (ret.length == 0 || abi.decode(ret, (bool))), "Token refund failed");
            }
        }
    }

    function _execute(
        address to,
        uint256 value,
        bytes memory data,
        Operation operation,
        uint256 txGas
    ) internal returns (bool success) {
        if (operation == Operation.DelegateCall) {
            assembly {
                success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
            }
        } else {
            assembly {
                success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
            }
        }
    }

    function _checkSignatures(bytes32 txHash, bytes memory signatures) internal view {
        require(signatures.length >= threshold * 65, "Not enough signatures");

        address lastOwner = address(0);
        for (uint256 i = 0; i < threshold; i++) {
            (uint8 v, bytes32 r, bytes32 s) = _splitSignature(signatures, i);
            address signer;

            if (v == 0) {
                // Contract signature (EIP-1271)
                signer = address(uint160(uint256(r)));
                require(uint256(s) + 32 <= signatures.length, "Invalid contract sig offset");

                uint256 contractSigLen;
                uint256 sigOffset = uint256(s);
                assembly {
                    contractSigLen := mload(add(add(signatures, 0x20), sigOffset))
                }
                require(sigOffset + 32 + contractSigLen <= signatures.length, "Invalid contract sig length");

                bytes memory contractSig = new bytes(contractSigLen);
                assembly {
                    let src := add(add(add(signatures, 0x20), sigOffset), 32)
                    let dest := add(contractSig, 0x20)
                    for { let j := 0 } lt(j, contractSigLen) { j := add(j, 32) } {
                        mstore(add(dest, j), mload(add(src, j)))
                    }
                }

                require(
                    IERC1271(signer).isValidSignature(txHash, contractSig) == EIP1271_MAGIC,
                    "EIP1271 validation failed"
                );
            } else if (v == 1) {
                // Pre-approved hash
                signer = address(uint160(uint256(r)));
                require(approvedHashes[txHash] > 0 || msg.sender == signer, "Hash not approved");
            } else {
                // ECDSA signature
                signer = ecrecover(
                    keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", txHash)),
                    v - 4 > 30 ? v : v,
                    r,
                    s
                );
                if (signer == address(0)) {
                    signer = ecrecover(txHash, v, r, s);
                }
            }

            require(signer > lastOwner && isOwner(signer), "Invalid signer or order");
            lastOwner = signer;
        }
    }

    function _splitSignature(bytes memory signatures, uint256 index)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        uint256 offset = index * 65;
        assembly {
            let base := add(add(signatures, 0x20), offset)
            r := mload(base)
            s := mload(add(base, 0x20))
            v := byte(0, mload(add(base, 0x40)))
        }
    }

    function approveHash(bytes32 hash) external {
        require(isOwner(msg.sender), "Not owner");
        approvedHashes[hash] = 1;
    }

    // --- Owner management (only via self-call) ---

    function addOwnerWithThreshold(address owner, uint256 _threshold) external authorized {
        require(owner != address(0) && owner != SENTINEL && owners[owner] == address(0), "Invalid owner");
        owners[owner] = owners[SENTINEL];
        owners[SENTINEL] = owner;
        ownerCount++;
        emit OwnerAdded(owner);
        if (threshold != _threshold) _changeThreshold(_threshold);
    }

    function removeOwner(address prevOwner, address owner, uint256 _threshold) external authorized {
        require(ownerCount - 1 >= _threshold, "Threshold too high");
        require(owners[prevOwner] == owner, "Invalid prev owner");
        owners[prevOwner] = owners[owner];
        owners[owner] = address(0);
        ownerCount--;
        emit OwnerRemoved(owner);
        if (threshold != _threshold) _changeThreshold(_threshold);
    }

    function swapOwner(address prevOwner, address oldOwner, address newOwner) external authorized {
        require(
            newOwner != address(0) && newOwner != SENTINEL && owners[newOwner] == address(0),
            "Invalid new owner"
        );
        require(owners[prevOwner] == oldOwner, "Invalid prev owner");
        owners[newOwner] = owners[oldOwner];
        owners[prevOwner] = newOwner;
        owners[oldOwner] = address(0);
        emit OwnerRemoved(oldOwner);
        emit OwnerAdded(newOwner);
    }

    function changeThreshold(uint256 _threshold) external authorized {
        _changeThreshold(_threshold);
    }

    function _changeThreshold(uint256 _threshold) internal {
        require(_threshold > 0 && _threshold <= ownerCount, "Invalid threshold");
        threshold = _threshold;
        emit ThresholdChanged(_threshold);
    }

    // --- Module system ---

    function enableModule(address module) external authorized {
        require(module != address(0) && module != SENTINEL && modules[module] == address(0), "Invalid module");
        modules[module] = modules[SENTINEL];
        modules[SENTINEL] = module;
        emit ModuleEnabled(module);
    }

    function disableModule(address prevModule, address module) external authorized {
        require(modules[prevModule] == module, "Invalid prev module");
        modules[prevModule] = modules[module];
        modules[module] = address(0);
        emit ModuleDisabled(module);
    }

    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation
    ) external returns (bool success) {
        require(modules[msg.sender] != address(0) && msg.sender != SENTINEL, "Not a module");
        success = _execute(to, value, data, operation, gasleft());
    }

    function isModuleEnabled(address module) public view returns (bool) {
        return module != SENTINEL && modules[module] != address(0);
    }

    // --- View functions ---

    function isOwner(address account) public view returns (bool) {
        return account != SENTINEL && owners[account] != address(0);
    }

    function getOwners() external view returns (address[] memory) {
        address[] memory result = new address[](ownerCount);
        address current = owners[SENTINEL];
        for (uint256 i = 0; i < ownerCount; i++) {
            result[i] = current;
            current = owners[current];
        }
        return result;
    }

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
                ),
                to,
                value,
                keccak256(data),
                uint8(operation),
                safeTxGas,
                baseGas,
                gasPrice,
                gasToken,
                refundReceiver,
                _nonce,
                block.chainid,
                address(this)
            )
        );
    }

    function isValidSignature(bytes32 hash, bytes memory signature) external view override returns (bytes4) {
        if (signature.length == 0) {
            require(approvedHashes[hash] > 0, "Hash not approved");
        } else {
            _checkSignatures(hash, signature);
        }
        return EIP1271_MAGIC;
    }

    modifier authorized() {
        require(msg.sender == address(this), "Only self");
        _;
    }
}