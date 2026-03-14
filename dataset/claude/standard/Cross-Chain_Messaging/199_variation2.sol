// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossChainMessaging {
    struct Message {
        uint256 sourceChainId;
        address sourceContract;
        address sender;
        bytes payload;
        uint256 timestamp;
        bool delivered;
    }

    mapping(address => mapping(uint256 => mapping(address => bool))) private trustedSources;
    mapping(address => uint256[]) private trustedChains;
    mapping(address => mapping(uint256 => address[])) private trustedContractsPerChain;
    mapping(bytes32 => Message) public messages;
    mapping(address => bytes32[]) public inbox;

    uint256 public messageNonce;

    event TrustedSourceAdded(address indexed receiver, uint256 indexed chainId, address indexed sourceContract);
    event TrustedSourceRemoved(address indexed receiver, uint256 indexed chainId, address indexed sourceContract);
    event MessageSent(bytes32 indexed messageId, uint256 indexed destChainId, address indexed receiver);
    event MessageDelivered(bytes32 indexed messageId, address indexed receiver);
    event MessageRejected(bytes32 indexed messageId, address indexed receiver, string reason);

    modifier onlyValidAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    function addTrustedSource(uint256 chainId, address sourceContract) external onlyValidAddress(sourceContract) {
        require(!trustedSources[msg.sender][chainId][sourceContract], "Already trusted");

        trustedSources[msg.sender][chainId][sourceContract] = true;
        trustedContractsPerChain[msg.sender][chainId].push(sourceContract);

        bool chainExists = false;
        uint256[] storage chains = trustedChains[msg.sender];
        for (uint256 i = 0; i < chains.length; i++) {
            if (chains[i] == chainId) {
                chainExists = true;
                break;
            }
        }
        if (!chainExists) {
            chains.push(chainId);
        }

        emit TrustedSourceAdded(msg.sender, chainId, sourceContract);
    }

    function addTrustedSourcesBatch(uint256[] calldata chainIds, address[] calldata sourceContracts) external {
        require(chainIds.length == sourceContracts.length, "Length mismatch");

        for (uint256 i = 0; i < chainIds.length; i++) {
            require(sourceContracts[i] != address(0), "Invalid address");
            if (!trustedSources[msg.sender][chainIds[i]][sourceContracts[i]]) {
                trustedSources[msg.sender][chainIds[i]][sourceContracts[i]] = true;
                trustedContractsPerChain[msg.sender][chainIds[i]].push(sourceContracts[i]);

                bool chainExists = false;
                uint256[] storage chains = trustedChains[msg.sender];
                for (uint256 j = 0; j < chains.length; j++) {
                    if (chains[j] == chainIds[i]) {
                        chainExists = true;
                        break;
                    }
                }
                if (!chainExists) {
                    chains.push(chainIds[i]);
                }

                emit TrustedSourceAdded(msg.sender, chainIds[i], sourceContracts[i]);
            }
        }
    }

    function removeTrustedSource(uint256 chainId, address sourceContract) external {
        require(trustedSources[msg.sender][chainId][sourceContract], "Not trusted");

        trustedSources[msg.sender][chainId][sourceContract] = false;

        address[] storage contracts = trustedContractsPerChain[msg.sender][chainId];
        for (uint256 i = 0; i < contracts.length; i++) {
            if (contracts[i] == sourceContract) {
                contracts[i] = contracts[contracts.length - 1];
                contracts.pop();
                break;
            }
        }

        if (contracts.length == 0) {
            uint256[] storage chains = trustedChains[msg.sender];
            for (uint256 i = 0; i < chains.length; i++) {
                if (chains[i] == chainId) {
                    chains[i] = chains[chains.length - 1];
                    chains.pop();
                    break;
                }
            }
        }

        emit TrustedSourceRemoved(msg.sender, chainId, sourceContract);
    }

    function sendMessage(
        uint256 destChainId,
        address receiver,
        bytes calldata payload
    ) external onlyValidAddress(receiver) returns (bytes32 messageId) {
        require(payload.length > 0, "Empty payload");

        messageNonce++;
        messageId = keccak256(
            abi.encodePacked(block.chainid, destChainId, msg.sender, receiver, messageNonce, block.timestamp)
        );

        messages[messageId] = Message({
            sourceChainId: block.chainid,
            sourceContract: msg.sender,
            sender: tx.origin,
            payload: payload,
            timestamp: block.timestamp,
            delivered: false
        });

        emit MessageSent(messageId, destChainId, receiver);
    }

    function deliverMessage(
        bytes32 messageId,
        uint256 sourceChainId,
        address sourceContract,
        address receiver,
        bytes calldata payload
    ) external {
        require(!messages[messageId].delivered, "Already delivered");

        if (!trustedSources[receiver][sourceChainId][sourceContract]) {
            emit MessageRejected(messageId, receiver, "Untrusted source");
            revert("Source not trusted by receiver");
        }

        messages[messageId] = Message({
            sourceChainId: sourceChainId,
            sourceContract: sourceContract,
            sender: msg.sender,
            payload: payload,
            timestamp: block.timestamp,
            delivered: true
        });

        inbox[receiver].push(messageId);

        emit MessageDelivered(messageId, receiver);
    }

    function isTrustedSource(address receiver, uint256 chainId, address sourceContract) external view returns (bool) {
        return trustedSources[receiver][chainId][sourceContract];
    }

    function getTrustedChains(address receiver) external view returns (uint256[] memory) {
        return trustedChains[receiver];
    }

    function getTrustedContracts(address receiver, uint256 chainId) external view returns (address[] memory) {
        return trustedContractsPerChain[receiver][chainId];
    }

    function getInboxLength(address receiver) external view returns (uint256) {
        return inbox[receiver].length;
    }

    function getInboxMessages(address receiver, uint256 offset, uint256 limit) external view returns (bytes32[] memory) {
        uint256 total = inbox[receiver].length;
        if (offset >= total) {
            return new bytes32[](0);
        }

        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }

        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = inbox[receiver][i];
        }
        return result;
    }

    function getMessage(bytes32 messageId) external view returns (Message memory) {
        return messages[messageId];
    }
}