// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Proxy is UUPSUpgradeable {
    address private _owner;
    address private _securityCouncil;
    bool private _approvedBySecurityCouncil = false;

    constructor(address initialImplementation, address owner, address securityCouncil) {
        _owner = owner;
        _securityCouncil = securityCouncil;
        _upgradeToAndCall(initialImplementation, abi.encodeWithSignature("initialize()"));
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) public onlyOwner {
        if (_approvedBySecurityCouncil) {
            _upgradeToAndCall(newImplementation, data);
            _approvedBySecurityCouncil = false;
        } else {
            revert("Upgrade not approved by the security council");
        }
    }

    function approveUpgrade() public onlySecurityCouncil {
        _approvedBySecurityCouncil = true;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    modifier onlySecurityCouncil() {
        require(msg.sender == _securityCouncil, "Unauthorized: caller is not the security council");
        _;
    }
}