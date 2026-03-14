// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrossChainBridge is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct BridgeRequest {
        address sender;
        address token;
        uint256 amount;
        uint256 destChainId;
        address destAddress;
        uint256 nonce;
        bool processed;
    }

    mapping(bytes32 => BridgeRequest) public bridgeRequests;
    mapping(bytes32 => bool) public processedIncoming;
    mapping(address => bool) public supportedTokens;
    mapping(address => bool) public relayers;
    mapping(address => uint256) public nonces;

    uint256 public bridgeFee = 0.001 ether;
    uint256 public minSignatures = 1;

    event TokensLocked(
        bytes32 indexed requestId,
        address indexed sender,
        address token,
        uint256 amount,
        uint256 destChainId,
        address destAddress,
        uint256 nonce
    );

    event TokensReleased(
        bytes32 indexed requestId,
        address indexed recipient,
        address token,
        uint256 amount,
        uint256 sourceChainId
    );

    event NativeDeposited(
        bytes32 indexed requestId,
        address indexed sender,
        uint256 amount,
        uint256 destChainId,
        address destAddress
    );

    modifier onlyRelayer() {
        require(relayers[msg.sender], "Not a relayer");
        _;
    }

    constructor() Ownable(msg.sender) {
        relayers[msg.sender] = true;
    }

    function addRelayer(address _relayer) external onlyOwner {
        relayers[_relayer] = true;
    }

    function removeRelayer(address _relayer) external onlyOwner {
        relayers[_relayer] = false;
    }

    function addSupportedToken(address _token) external onlyOwner {
        supportedTokens[_token] = true;
    }

    function removeSupportedToken(address _token) external onlyOwner {
        supportedTokens[_token] = false;
    }

    function setFee(uint256 _fee) external onlyOwner {
        bridgeFee = _fee;
    }

    function bridgeTokens(
        address _token,
        uint256 _amount,
        uint256 _destChainId,
        address _destAddress
    ) external payable nonReentrant {
        require(supportedTokens[_token], "Token not supported");
        require(_amount > 0, "Amount must be > 0");
        require(_destAddress != address(0), "Invalid dest address");
        require(msg.value >= bridgeFee, "Insufficient fee");

        uint256 nonce = nonces[msg.sender]++;
        bytes32 requestId = keccak256(
            abi.encodePacked(msg.sender, _token, _amount, _destChainId, _destAddress, nonce, block.chainid)
        );

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        bridgeRequests[requestId] = BridgeRequest({
            sender: msg.sender,
            token: _token,
            amount: _amount,
            destChainId: _destChainId,
            destAddress: _destAddress,
            nonce: nonce,
            processed: false
        });

        emit TokensLocked(requestId, msg.sender, _token, _amount, _destChainId, _destAddress, nonce);
    }

    function bridgeNative(
        uint256 _destChainId,
        address _destAddress
    ) external payable nonReentrant {
        require(msg.value > bridgeFee, "Amount must cover fee");
        require(_destAddress != address(0), "Invalid dest address");

        uint256 amount = msg.value - bridgeFee;
        uint256 nonce = nonces[msg.sender]++;
        bytes32 requestId = keccak256(
            abi.encodePacked(msg.sender, address(0), amount, _destChainId, _destAddress, nonce, block.chainid)
        );

        bridgeRequests[requestId] = BridgeRequest({
            sender: msg.sender,
            token: address(0),
            amount: amount,
            destChainId: _destChainId,
            destAddress: _destAddress,
            nonce: nonce,
            processed: false
        });

        emit NativeDeposited(requestId, msg.sender, amount, _destChainId, _destAddress);
    }

    function releaseTokens(
        bytes32 _requestId,
        address _recipient,
        address _token,
        uint256 _amount,
        uint256 _sourceChainId
    ) external onlyRelayer nonReentrant {
        require(!processedIncoming[_requestId], "Already processed");
        require(_recipient != address(0), "Invalid recipient");
        require(_amount > 0, "Amount must be > 0");

        processedIncoming[_requestId] = true;

        if (_token == address(0)) {
            (bool success, ) = _recipient.call{value: _amount}("");
            require(success, "Native transfer failed");
        } else {
            IERC20(_token).safeTransfer(_recipient, _amount);
        }

        emit TokensReleased(_requestId, _recipient, _token, _amount, _sourceChainId);
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Transfer failed");
    }

    function emergencyWithdrawToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(owner(), _amount);
    }

    receive() external payable {}
}