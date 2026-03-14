// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    struct RelayRequest {
        address sender;
        address recipient;
        uint256 amount;
        uint256 sourceChainId;
        uint256 destChainId;
        uint256 nonce;
        uint256 timestamp;
        bool executed;
    }

    address public owner;
    uint256 public relayerFee; // in basis points (e.g., 30 = 0.3%)
    uint256 public minRelayAmount;
    uint256 public requiredConfirmations;
    uint256 public requestNonce;

    mapping(bytes32 => RelayRequest) public relayRequests;
    mapping(bytes32 => mapping(address => bool)) public confirmations;
    mapping(bytes32 => uint256) public confirmationCount;
    mapping(address => bool) public relayers;
    mapping(address => uint256) public nonces;
    uint256 public relayerCount;

    event Deposited(
        bytes32 indexed requestId,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChainId,
        uint256 destChainId,
        uint256 nonce
    );

    event Confirmed(bytes32 indexed requestId, address indexed relayer);
    event Executed(bytes32 indexed requestId, address indexed recipient, uint256 amount);
    event RelayerAdded(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event FeeUpdated(uint256 newFee);
    event FundsWithdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(relayers[msg.sender], "Not relayer");
        _;
    }

    constructor(uint256 _relayerFee, uint256 _minRelayAmount, uint256 _requiredConfirmations) {
        owner = msg.sender;
        relayerFee = _relayerFee;
        minRelayAmount = _minRelayAmount;
        requiredConfirmations = _requiredConfirmations;

        relayers[msg.sender] = true;
        relayerCount = 1;
    }

    function deposit(address _recipient, uint256 _destChainId) external payable {
        require(msg.value >= minRelayAmount, "Below minimum relay amount");
        require(_recipient != address(0), "Invalid recipient");
        require(_destChainId != block.chainid, "Same chain");

        uint256 nonce = nonces[msg.sender]++;
        requestNonce++;

        bytes32 requestId = keccak256(
            abi.encodePacked(msg.sender, _recipient, msg.value, block.chainid, _destChainId, nonce)
        );

        relayRequests[requestId] = RelayRequest({
            sender: msg.sender,
            recipient: _recipient,
            amount: msg.value,
            sourceChainId: block.chainid,
            destChainId: _destChainId,
            nonce: nonce,
            timestamp: block.timestamp,
            executed: false
        });

        emit Deposited(requestId, msg.sender, _recipient, msg.value, block.chainid, _destChainId, nonce);
    }

    function confirmRelay(bytes32 _requestId) external onlyRelayer {
        require(!confirmations[_requestId][msg.sender], "Already confirmed");
        require(!relayRequests[_requestId].executed, "Already executed");

        confirmations[_requestId][msg.sender] = true;
        confirmationCount[_requestId]++;

        emit Confirmed(_requestId, msg.sender);

        if (confirmationCount[_requestId] >= requiredConfirmations) {
            _executeRelay(_requestId);
        }
    }

    function _executeRelay(bytes32 _requestId) internal {
        RelayRequest storage request = relayRequests[_requestId];
        require(!request.executed, "Already executed");
        require(request.recipient != address(0), "Invalid request");

        request.executed = true;

        uint256 fee = (request.amount * relayerFee) / 10000;
        uint256 transferAmount = request.amount - fee;

        (bool success, ) = request.recipient.call{value: transferAmount}("");
        require(success, "Transfer failed");

        emit Executed(_requestId, request.recipient, transferAmount);
    }

    function addRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid address");
        require(!relayers[_relayer], "Already relayer");

        relayers[_relayer] = true;
        relayerCount++;

        emit RelayerAdded(_relayer);
    }

    function removeRelayer(address _relayer) external onlyOwner {
        require(relayers[_relayer], "Not a relayer");
        require(relayerCount > requiredConfirmations, "Would break quorum");

        relayers[_relayer] = false;
        relayerCount--;

        emit RelayerRemoved(_relayer);
    }

    function setFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee too high"); // max 10%
        relayerFee = _newFee;
        emit FeeUpdated(_newFee);
    }

    function setMinRelayAmount(uint256 _minAmount) external onlyOwner {
        minRelayAmount = _minAmount;
    }

    function setRequiredConfirmations(uint256 _required) external onlyOwner {
        require(_required > 0, "Must be at least 1");
        require(_required <= relayerCount, "Exceeds relayer count");
        requiredConfirmations = _required;
    }

    function withdrawFees(address payable _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid address");
        require(_amount <= address(this).balance, "Insufficient balance");

        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Withdrawal failed");

        emit FundsWithdrawn(_to, _amount);
    }

    function getRequestId(
        address _sender,
        address _recipient,
        uint256 _amount,
        uint256 _sourceChainId,
        uint256 _destChainId,
        uint256 _nonce
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_sender, _recipient, _amount, _sourceChainId, _destChainId, _nonce));
    }

    function isConfirmed(bytes32 _requestId) external view returns (bool) {
        return confirmationCount[_requestId] >= requiredConfirmations;
    }

    receive() external payable {}
}