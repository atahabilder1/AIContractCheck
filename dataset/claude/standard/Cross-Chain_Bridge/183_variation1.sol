// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CrossChainBridge {
    address public owner;
    address public relayer;

    uint256 public ethFeePercent; // basis points (e.g., 30 = 0.3%)
    uint256 public ethFlatFee;
    uint256 public erc20FeePercent;
    uint256 public erc20FlatFee;

    uint256 public constant MAX_FEE_PERCENT = 500; // 5% max
    uint256 public nonce;

    mapping(address => bool) public supportedTokens;
    mapping(bytes32 => bool) public processedTransfers;
    mapping(uint256 => bool) public supportedChains;

    bool public paused;

    event BridgeETH(
        address indexed sender,
        uint256 amount,
        uint256 fee,
        uint256 destinationChainId,
        uint256 indexed nonce
    );

    event BridgeERC20(
        address indexed sender,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 destinationChainId,
        uint256 indexed nonce
    );

    event ReleasedETH(address indexed recipient, uint256 amount, bytes32 indexed transferId);
    event ReleasedERC20(address indexed recipient, address indexed token, uint256 amount, bytes32 indexed transferId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Not relayer");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Bridge paused");
        _;
    }

    constructor(address _relayer, uint256 _ethFeePercent, uint256 _ethFlatFee, uint256 _erc20FeePercent, uint256 _erc20FlatFee) {
        require(_relayer != address(0), "Invalid relayer");
        require(_ethFeePercent <= MAX_FEE_PERCENT, "ETH fee too high");
        require(_erc20FeePercent <= MAX_FEE_PERCENT, "ERC20 fee too high");

        owner = msg.sender;
        relayer = _relayer;
        ethFeePercent = _ethFeePercent;
        ethFlatFee = _ethFlatFee;
        erc20FeePercent = _erc20FeePercent;
        erc20FlatFee = _erc20FlatFee;
    }

    function bridgeETH(uint256 destinationChainId) external payable whenNotPaused {
        require(supportedChains[destinationChainId], "Chain not supported");
        uint256 fee = (msg.value * ethFeePercent) / 10000 + ethFlatFee;
        require(msg.value > fee, "Amount must exceed fee");

        uint256 bridgedAmount = msg.value - fee;
        uint256 currentNonce = nonce++;

        emit BridgeETH(msg.sender, bridgedAmount, fee, destinationChainId, currentNonce);
    }

    function bridgeERC20(address token, uint256 amount, uint256 destinationChainId) external whenNotPaused {
        require(supportedTokens[token], "Token not supported");
        require(supportedChains[destinationChainId], "Chain not supported");
        require(amount > 0, "Zero amount");

        uint256 fee = (amount * erc20FeePercent) / 10000 + erc20FlatFee;
        require(amount > fee, "Amount must exceed fee");

        uint256 bridgedAmount = amount - fee;
        uint256 currentNonce = nonce++;

        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        emit BridgeERC20(msg.sender, token, bridgedAmount, fee, destinationChainId, currentNonce);
    }

    function releaseETH(address payable recipient, uint256 amount, bytes32 sourceTransferId) external onlyRelayer whenNotPaused {
        require(!processedTransfers[sourceTransferId], "Already processed");
        require(address(this).balance >= amount, "Insufficient ETH balance");

        processedTransfers[sourceTransferId] = true;

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ReleasedETH(recipient, amount, sourceTransferId);
    }

    function releaseERC20(address recipient, address token, uint256 amount, bytes32 sourceTransferId) external onlyRelayer whenNotPaused {
        require(!processedTransfers[sourceTransferId], "Already processed");
        require(supportedTokens[token], "Token not supported");

        processedTransfers[sourceTransferId] = true;

        require(IERC20(token).transfer(recipient, amount), "Token transfer failed");

        emit ReleasedERC20(recipient, token, amount, sourceTransferId);
    }

    function setETHFees(uint256 _feePercent, uint256 _flatFee) external onlyOwner {
        require(_feePercent <= MAX_FEE_PERCENT, "Fee too high");
        ethFeePercent = _feePercent;
        ethFlatFee = _flatFee;
    }

    function setERC20Fees(uint256 _feePercent, uint256 _flatFee) external onlyOwner {
        require(_feePercent <= MAX_FEE_PERCENT, "Fee too high");
        erc20FeePercent = _feePercent;
        erc20FlatFee = _flatFee;
    }

    function addSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = true;
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token] = false;
    }

    function addSupportedChain(uint256 chainId) external onlyOwner {
        supportedChains[chainId] = true;
    }

    function removeSupportedChain(uint256 chainId) external onlyOwner {
        supportedChains[chainId] = false;
    }

    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Invalid relayer");
        relayer = _relayer;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function withdrawFees(address payable to) external onlyOwner {
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }

    function withdrawTokenFees(address token, address to) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transfer(to, balance), "Token withdraw failed");
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }

    receive() external payable {}
}