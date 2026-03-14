// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProxy {
    function implementation() external view returns (address);
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

interface IProxyWithAdmin {
    function admin() external view returns (address);
}

contract UUPSProxy is IProxy, IProxyWithAdmin {
    address private immutable implementation_;
    address private immutable admin_;

    constructor(address initialImplementation, address initialAdmin) {
        implementation_ = initialImplementation;
        admin_ = initialAdmin;
    }

    function implementation() external override view returns (address) {
        return implementation_;
    }

    function admin() external override view returns (address) {
        return admin_;
    }

    function upgradeTo(address newImplementation) external override {
        require(msg.sender == admin_, "UUPSProxy: Only admin can upgrade");
        implementation_ = newImplementation;
    }

    function upgradeToAndCall(address newImplementation, bytes memory data) external payable override {
        require(msg.sender == admin_, "UUPSProxy: Only admin can upgrade and call");
        implementation_ = newImplementation;
        (bool success, ) = newImplementation.delegatecall(data);
        require(success, "UUPSProxy: Upgrade failed");
    }

    fallback() external payable {
        address impl = implementation();
        require(impl != address(0), "UUPSProxy: Implementation not set");
        (bool success, bytes memory ret) = impl.delegatecall(msg.data);
        require(success, "UUPSProxy: Delegate call failed");
        assembly {
            return(add(ret, 0x20), mload(ret))
        }
    }
}