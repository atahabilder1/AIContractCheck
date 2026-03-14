// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/ProxyAdmin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// This is a placeholder for your actual upgradeable logic contract.
// It should inherit from the logic contract you want to upgrade.
contract MyLogicContract is Ownable {
    string public version;

    function initialize(string memory _version) public initializer {
        version = _version;
    }

    function updateVersion(string memory _version) public {
        version = _version;
    }

    // Example function
    function getVersion() public view returns (string memory) {
        return version;
    }
}

// This contract acts as the entry point and manages the proxy and admin.
contract ProxyManager is Ownable {
    TransparentUpgradeableProxy public proxy;
    ProxyAdmin public admin;
    address public logicContractAddress;

    event ProxyCreated(address proxyAddress, address adminAddress, address logicContractAddress);
    event LogicContractUpgraded(address newLogicContractAddress);

    constructor(address _initialLogicContract) Ownable(msg.sender) {
        // Deploy the ProxyAdmin contract
        admin = new ProxyAdmin();

        // Deploy the initial logic contract implementation
        // In a real-world scenario, you would deploy this separately and pass its address.
        // For simplicity here, we'll assume it's already deployed or managed externally.
        // If you are deploying it here, you'd typically use a factory or a separate deployment script.
        // For this example, we'll assume _initialLogicContract is the address of an already deployed logic contract.
        logicContractAddress = _initialLogicContract;

        // Deploy the TransparentUpgradeableProxy
        proxy = new TransparentUpgradeableProxy(
            logicContractAddress,
            address(admin),
            "" // No initial data for initialization in this constructor
        );

        emit ProxyCreated(address(proxy), address(admin), logicContractAddress);
    }

    /**
     * @notice Initializes the proxy with the logic contract's initialization function.
     * @param _version The initial version string to set in the logic contract.
     */
    function initializeProxy(string memory _version) public onlyOwner {
        // The ABI encoding for the initialize function of MyLogicContract
        bytes memory data = abi.encodeWithSelector(
            MyLogicContract.initialize.selector,
            _version
        );
        // Call the initialize function on the proxy
        // The proxy will delegate this call to the logic contract
        // Note: This should only be called once.
        // If the logic contract has an `initialize` function, it must be protected
        // to only be called once (e.g., using `initializer` modifier from OpenZeppelin).
        (bool success, ) = address(proxy).call(data);
        require(success, "Proxy initialization failed");
    }

    /**
     * @notice Upgrades the logic contract implementation for the proxy.
     * @param _newLogicContractAddress The address of the new logic contract implementation.
     */
    function upgradeLogicContract(address _newLogicContractAddress) public onlyOwner {
        // The ProxyAdmin contract is used to manage upgrades.
        // The owner of the ProxyManager contract is also the owner of the ProxyAdmin contract.
        admin.upgrade(proxy, _newLogicContractAddress);
        logicContractAddress = _newLogicContractAddress;
        emit LogicContractUpgraded(_newLogicContractAddress);
    }

    /**
     * @notice Transfers ownership of the ProxyAdmin contract.
     * @param _newOwner The address of the new owner.
     */
    function transferAdminOwnership(address _newOwner) public onlyOwner {
        admin.transferOwnership(_newOwner);
    }

    /**
     * @notice Transfers ownership of the ProxyManager contract.
     * @param _newOwner The address of the new owner.
     */
    function transferProxyManagerOwnership(address _newOwner) public onlyOwner {
        transferOwnership(_newOwner);
    }

    // You can add functions here to delegate calls to the proxy if needed,
    // or directly interact with the proxy address.
    // For example:
    function getVersionFromProxy() public view returns (string memory) {
        // Ensure the proxy has been initialized and has a logic contract set.
        require(address(proxy) != address(0), "Proxy not deployed");
        // Delegate call to the logic contract via the proxy
        return MyLogicContract(address(proxy)).getVersion();
    }

    function updateVersionViaProxy(string memory _version) public {
        // Ensure the proxy has been initialized and has a logic contract set.
        require(address(proxy) != address(0), "Proxy not deployed");
        // Delegate call to the logic contract via the proxy
        MyLogicContract(address(proxy)).updateVersion(_version);
    }
}