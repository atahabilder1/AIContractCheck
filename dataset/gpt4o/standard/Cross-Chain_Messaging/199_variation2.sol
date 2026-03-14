// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MessagingProtocol {
    
    struct TrustedSource {
        bool isTrusted;
        string sourceChain;
    }

    mapping(address => mapping(address => TrustedSource)) public trustedSources;

    event MessageSent(address indexed from, address indexed to, string sourceChain, string message);
    event TrustedSourceUpdated(address indexed receiver, address indexed sourceContract, string sourceChain, bool isTrusted);

    modifier onlyTrustedSource(address _receiver, string memory _sourceChain) {
        require(trustedSources[_receiver][msg.sender].isTrusted, "Source not trusted");
        require(keccak256(bytes(trustedSources[_receiver][msg.sender].sourceChain)) == keccak256(bytes(_sourceChain)), "Source chain mismatch");
        _;
    }

    function updateTrustedSource(address _sourceContract, string calldata _sourceChain, bool _isTrusted) external {
        trustedSources[msg.sender][_sourceContract] = TrustedSource(_isTrusted, _sourceChain);
        emit TrustedSourceUpdated(msg.sender, _sourceContract, _sourceChain, _isTrusted);
    }

    function sendMessage(address _to, string calldata _sourceChain, string calldata _message) external onlyTrustedSource(_to, _sourceChain) {
        emit MessageSent(msg.sender, _to, _sourceChain, _message);
    }
}