// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MessagingProtocol {
    struct TrustedSource {
        uint256 chainId;
        address contractAddress;
    }

    mapping(address => TrustedSource[]) public trustedSources;

    event TrustedSourceAdded(address indexed receiver, uint256 chainId, address contractAddress);
    event TrustedSourceRemoved(address indexed receiver, uint256 chainId, address contractAddress);
    event MessageReceived(address indexed receiver, uint256 fromChainId, address fromContract, string message);

    modifier onlyTrustedSource(uint256 _chainId, address _fromContract) {
        require(isTrustedSource(msg.sender, _chainId, _fromContract), "Sender is not a trusted source");
        _;
    }

    function addTrustedSource(uint256 _chainId, address _contractAddress) external {
        require(!isTrustedSource(msg.sender, _chainId, _contractAddress), "Already a trusted source");
        trustedSources[msg.sender].push(TrustedSource(_chainId, _contractAddress));
        emit TrustedSourceAdded(msg.sender, _chainId, _contractAddress);
    }

    function removeTrustedSource(uint256 _chainId, address _contractAddress) external {
        uint256 index = findTrustedSourceIndex(msg.sender, _chainId, _contractAddress);
        require(index != type(uint256).max, "Not a trusted source");
        trustedSources[msg.sender][index] = trustedSources[msg.sender][trustedSources[msg.sender].length - 1];
        trustedSources[msg.sender].pop();
        emit TrustedSourceRemoved(msg.sender, _chainId, _contractAddress);
    }

    function receiveMessage(uint256 _fromChainId, address _fromContract, string calldata _message) external onlyTrustedSource(_fromChainId, _fromContract) {
        emit MessageReceived(msg.sender, _fromChainId, _fromContract, _message);
    }

    function isTrustedSource(address _receiver, uint256 _chainId, address _contractAddress) public view returns (bool) {
        return findTrustedSourceIndex(_receiver, _chainId, _contractAddress) != type(uint256).max;
    }

    function findTrustedSourceIndex(address _receiver, uint256 _chainId, address _contractAddress) internal view returns (uint256) {
        for (uint256 i = 0; i < trustedSources[_receiver].length; i++) {
            if (trustedSources[_receiver][i].chainId == _chainId && trustedSources[_receiver][i].contractAddress == _contractAddress) {
                return i;
            }
        }
        return type(uint256).max;
    }
}