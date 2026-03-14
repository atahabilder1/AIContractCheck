// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultisigWallet {
    address[] public owners;
    uint public required;
    uint public nonce;
    mapping (address => uint) public ownerIndex;

    constructor(address[] memory _owners, uint _required) public {
        owners = _owners;
        required = _required;
        for (uint i = 0; i < _owners.length; i++) {
            ownerIndex[_owners[i]] = i;
        }
    }

    function execute(address to, uint value, bytes memory data) public {
        require(ownerIndex[msg.sender] != 0, "Only owners can execute");
        require(owners.length >= required, "Not enough owners");
        require(nonce < 2**32, "Nonce exceeds 32 bits");

        // Execute the transaction
        (bool success, ) = to.call{value: value}(data);
        require(success, "Transaction execution failed");

        // Increment the nonce
        nonce++;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getRequired() public view returns (uint) {
        return required;
    }

    function getNonce() public view returns (uint) {
        return nonce;
    }
}

contract DelegateCallModule {
    address public multisigWallet;
    address public delegateCallModule;

    constructor(address _multisigWallet, address _delegateCallModule) public {
        multisigWallet = _multisigWallet;
        delegateCallModule = _delegateCallModule;
    }

    function execute(address to, uint value, bytes memory data) public {
        require(msg.sender == multisigWallet, "Only the multisig wallet can execute");
        require(delegateCallModule.call{value: value}(data), "Delegate call execution failed");
    }

    function getMultisigWallet() public view returns (address) {
        return multisigWallet;
    }

    function getDelegateCallModule() public view returns (address) {
        return delegateCallModule;
    }
}

contract SignatureValidationModule {
    address public multisigWallet;
    address public signatureValidationModule;

    constructor(address _multisigWallet, address _signatureValidationModule) public {
        multisigWallet = _multisigWallet;
        signatureValidationModule = _signatureValidationModule;
    }

    function execute(address to, uint value, bytes memory data) public {
        require(msg.sender == multisigWallet, "Only the multisig wallet can execute");
        require(signatureValidationModule.call{value: value}(data), "Signature validation execution failed");
    }

    function getMultisigWallet() public view returns (address) {
        return multisigWallet;
    }

    function getSignatureValidationModule() public view returns (address) {
        return signatureValidationModule;
    }
}

contract GasRefundModule {
    address public multisigWallet;
    address public gasRefundModule;

    constructor(address _multisigWallet, address _gasRefundModule) public {
        multisigWallet = _multisigWallet;
        gasRefundModule = _gasRefundModule;
    }

    function execute(address to, uint value, bytes memory data) public {
        require(msg.sender == multisigWallet, "Only the multisig wallet can execute");
        require(gasRefundModule.call{value: value}(data), "Gas refund execution failed");
    }

    function getMultisigWallet() public view returns (address) {
        return multisigWallet;
    }

    function getGasRefundModule() public view returns (address) {
        return gasRefundModule;
    }
}

contract GnosisSafe {
    address public multisigWallet;
    address public delegateCallModule;
    address public signatureValidationModule;
    address public gasRefundModule;

    constructor(address _multisigWallet, address _delegateCallModule, address _signatureValidationModule, address _gasRefundModule) public {
        multisigWallet = _multisigWallet;
        delegateCallModule = _delegateCallModule;
        signatureValidationModule = _signatureValidationModule;
        gasRefundModule = _gasRefundModule;
    }

    function execute(address to, uint value, bytes memory data) public {
        require(msg.sender == multisigWallet, "Only the multisig wallet can execute");

        // Execute the transaction
        (bool success, ) = to.call{value: value}(data);
        require(success, "Transaction execution failed");

        // Refund gas
        gasRefundModule.call{value: 0}(data);
    }

    function getMultisigWallet() public view returns (address) {
        return multisigWallet;
    }

    function getDelegateCallModule() public view returns (address) {
        return delegateCallModule;
    }

    function getSignatureValidationModule() public view returns (address) {
        return signatureValidationModule;
    }

    function getGasRefundModule() public view returns (address) {
        return gasRefundModule;
    }
}