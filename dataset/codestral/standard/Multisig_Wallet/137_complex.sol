// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@gnosis.pm/safe-contracts/contracts/handlers/CompatibilityFallbackHandler.sol";
import "@gnosis.pm/safe-contracts/contracts/libraries/Modules.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "eip1271/EIP1271.sol";

contract MultiSigWallet is Ownable {
    using SafeMath for uint256;
    using Modules for GnosisSafe;
    using Address for address;

    EIP1271 eip1271;
    CompatibilityFallbackHandler fallbackHandler;
    bytes32 DOMAIN_SEPARATOR;
    uint256 constant MAX_OWNERS = 10;
    uint256 threshold;
    address[] owners;
    GnosisSafeProxy safeProxy;
    IGnosisSafe safe;

    constructor(address[] memory _owners, uint256 _threshold) {
        require(_owners.length <= MAX_OWNERS && _threshold > 0 && _threshold <= _owners.length);
        owners = _owners;
        threshold = _threshold;
        eip1271 = new EIP1271();
        fallbackHandler = new CompatibilityFallbackHandler();
        DOMAIN_SEPARATOR = keccak256(abi.encodePacked("\x19\x01", address(this), _getChainId(), "GnosisSafe"));
        safeProxy = new GnosisSafeProxy(fallbackHandler);
        safe = GnosisSafe(safeProxy.address).setup(owners, threshold, address(0), "", fallbackHandler, 0, address(0));
    }

    function execTransaction(address to, uint256 value, bytes memory data, Enum.Operation operation) external {
        require(_isValidSignature(), "Invalid signature");
        safe.execTransaction(to, value, data, operation);
    }

    function isValidSignature(bytes32 hash, bytes memory sig) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (eip1271.isValidSignature(owners[i], _hashTypedDataV4(DOMAIN_SEPARATOR, hash), sig)) {
                return true;
            }
        }
        return false;
    }

    function _isValidSignature() private view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(_msgSender(), _msgData()));
        return isValidSignature(hash, _signature());
    }

    // Helper functions to retrieve message sender, data and signature
    function _msgSender() private view returns (address) { ... }
    function _msgData() private view returns (bytes memory) { ... }
    function _signature() private view returns (bytes memory) { ... }
    function _hashTypedDataV4(bytes32 domainSeparator, bytes32 hashStruct) private pure returns (bytes32) { ... }
    function _getChainId() internal view returns (uint256) { ... }
}