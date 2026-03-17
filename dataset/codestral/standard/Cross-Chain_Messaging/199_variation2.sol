// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TrustedMessenger {
    mapping(address => mapping(uint256[])) public trustedSources;
    event MessageReceived(address indexed sender, string message);

    function setTrustedSource(uint256 _chainId, address _source) public {
        trustedSources[msg.sender][_chainId].push(_source);
    }

    function receiveMessage(string memory _message) public {
        require(trustedSources[msg.sender][_getChainId()][msg.sender], "Unauthorized sender");
        emit MessageReceived(msg.sender, _message);
    }

    function _getChainId() internal view returns (uint256) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}