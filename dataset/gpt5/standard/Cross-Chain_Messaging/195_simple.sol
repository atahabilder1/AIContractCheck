// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICrossChainEndpoint {
    function sendMessage(
        uint256 dstChainId,
        bytes calldata to,
        bytes calldata payload,
        bytes calldata options
    ) external payable returns (bytes32 messageId);
}

contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

contract ReentrancyGuard {
    uint256 private constant _ENTERED = 2;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private _status = _NOT_ENTERED;

    modifier nonReentrant() {
        require(_status == _NOT_ENTERED, "reentrancy");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract CrossChainMessenger is Ownable, ReentrancyGuard {
    ICrossChainEndpoint public endpoint;

    // chainId => trusted remote address (as bytes to remain generic across chains)
    mapping(uint256 => bytes) public trustedRemotes;

    uint64 public sentNonce;
    uint64 public receivedNonce;

    // Optionally store last received payload per source chain for basic introspection
    mapping(uint256 => bytes) public lastReceivedPayload;
    mapping(uint256 => bytes) public lastReceivedFrom;

    event EndpointSet(address indexed endpoint);
    event TrustedRemoteSet(uint256 indexed chainId, bytes remote);
    event MessageSent(
        uint256 indexed dstChainId,
        bytes indexed to,
        bytes payload,
        bytes32 messageId,
        uint64 nonce
    );
    event MessageReceived(
        uint256 indexed srcChainId,
        bytes indexed from,
        bytes payload,
        uint64 nonce
    );

    error NotEndpoint();
    error UntrustedRemote(uint256 chainId, bytes provided, bytes expected);

    constructor(address _endpoint) {
        require(_endpoint != address(0), "endpoint=0");
        endpoint = ICrossChainEndpoint(_endpoint);
        emit EndpointSet(_endpoint);
    }

    receive() external payable {}
    fallback() external payable {}

    // Admin: set the messaging endpoint/gateway
    function setEndpoint(address _endpoint) external onlyOwner {
        require(_endpoint != address(0), "endpoint=0");
        endpoint = ICrossChainEndpoint(_endpoint);
        emit EndpointSet(_endpoint);
    }

    // Admin: set the trusted remote for a given chainId
    function setTrustedRemote(uint256 chainId, bytes calldata remote) external onlyOwner {
        require(remote.length > 0, "remote empty");
        trustedRemotes[chainId] = remote;
        emit TrustedRemoteSet(chainId, remote);
    }

    // Send an arbitrary payload to any destination address (bytes-encoded) on a destination chain.
    // The "options" field is left generic for fee/modality parameters that the endpoint may require.
    function sendMessage(
        uint256 dstChainId,
        bytes calldata to,
        bytes calldata payload,
        bytes calldata options
    ) external payable nonReentrant returns (bytes32 messageId) {
        sentNonce += 1;
        messageId = endpoint.sendMessage{value: msg.value}(dstChainId, to, payload, options);
        emit MessageSent(dstChainId, to, payload, messageId, sentNonce);
    }

    // Convenience: send only to a pre-configured trusted remote for dstChainId.
    function sendMessageToTrusted(
        uint256 dstChainId,
        bytes calldata payload,
        bytes calldata options
    ) external payable nonReentrant returns (bytes32 messageId) {
        bytes memory to = trustedRemotes[dstChainId];
        require(to.length != 0, "no trusted remote");
        sentNonce += 1;
        messageId = endpoint.sendMessage{value: msg.value}(dstChainId, to, payload, options);
        emit MessageSent(dstChainId, to, payload, messageId, sentNonce);
    }

    // Callback entrypoint to receive messages from the endpoint.
    // The messaging endpoint MUST call this function when a message is delivered.
    // Implementations should ensure msg.sender is the trusted endpoint and validate the src.
    function ccReceive(
        uint256 srcChainId,
        bytes calldata srcAddress,
        bytes calldata payload
    ) external nonReentrant {
        if (msg.sender != address(endpoint)) revert NotEndpoint();

        bytes memory expected = trustedRemotes[srcChainId];
        if (expected.length != 0) {
            // If a trusted remote is configured, enforce it
            if (keccak256(srcAddress) != keccak256(expected)) {
                revert UntrustedRemote(srcChainId, srcAddress, expected);
            }
        }

        receivedNonce += 1;

        // Basic handling: store last received data per src chain and emit event
        lastReceivedPayload[srcChainId] = payload;
        lastReceivedFrom[srcChainId] = srcAddress;

        emit MessageReceived(srcChainId, srcAddress, payload, receivedNonce);

        _handleMessage(srcChainId, srcAddress, payload);
    }

    // Internal hook for custom logic on message receipt; override in extensions if needed.
    function _handleMessage(
        uint256 /*srcChainId*/,
        bytes calldata /*srcAddress*/,
        bytes calldata /*payload*/
    ) internal virtual {
        // Intentionally empty: users can extend this contract and override to add custom logic.
    }

    // Admin: sweep native currency
    function sweep(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "to=0");
        if (amount == 0) amount = address(this).balance;
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "sweep failed");
    }
}