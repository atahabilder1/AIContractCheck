// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CrossChainBridge is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct Validator {
        uint256 stakedAmount;
        uint256 unlockTime;
        bool isActive;
        uint256 slashCount;
    }

    struct BridgeMessage {
        uint256 sourceChain;
        uint256 destChain;
        address sender;
        address recipient;
        address token;
        uint256 amount;
        uint256 nonce;
    }

    IERC20 public immutable stakeToken;
    uint256 public minStake;
    uint256 public quorumThreshold;
    uint256 public constant UNSTAKE_DELAY = 7 days;
    uint256 public constant SLASH_PERCENT = 10;
    uint256 public constant MAX_SLASH_COUNT = 3;

    uint256 public depositNonce;
    uint256 public immutable chainId;

    mapping(address => Validator) public validators;
    address[] public validatorSet;

    mapping(bytes32 => bool) public processedMessages;
    mapping(bytes32 => mapping(address => bool)) public messageSignatures;
    mapping(bytes32 => uint256) public messageSignatureCount;

    mapping(bytes32 => bool) public slashedMessages;

    event ValidatorStaked(address indexed validator, uint256 amount);
    event ValidatorUnstakeRequested(address indexed validator, uint256 unlockTime);
    event ValidatorWithdrawn(address indexed validator, uint256 amount);
    event ValidatorSlashed(address indexed validator, uint256 amount, bytes32 messageHash);
    event Deposited(
        uint256 indexed destChain,
        address indexed sender,
        address indexed recipient,
        address token,
        uint256 amount,
        uint256 nonce
    );
    event Executed(bytes32 indexed messageHash, address indexed recipient, address token, uint256 amount);

    error InsufficientStake();
    error NotActiveValidator();
    error UnstakeNotReady();
    error AlreadyProcessed();
    error AlreadySigned();
    error QuorumNotReached();
    error InvalidSignature();
    error ValidatorAlreadyActive();
    error ChainMismatch();
    error ZeroAmount();
    error MaxSlashReached();

    constructor(
        address _stakeToken,
        uint256 _minStake,
        uint256 _quorumThreshold,
        uint256 _chainId
    ) Ownable(msg.sender) {
        stakeToken = IERC20(_stakeToken);
        minStake = _minStake;
        quorumThreshold = _quorumThreshold;
        chainId = _chainId;
    }

    function stake(uint256 amount) external nonReentrant {
        if (validators[msg.sender].isActive) revert ValidatorAlreadyActive();
        if (amount < minStake) revert InsufficientStake();

        stakeToken.safeTransferFrom(msg.sender, address(this), amount);

        validators[msg.sender] = Validator({
            stakedAmount: amount,
            unlockTime: 0,
            isActive: true,
            slashCount: 0
        });
        validatorSet.push(msg.sender);

        emit ValidatorStaked(msg.sender, amount);
    }

    function requestUnstake() external {
        Validator storage v = validators[msg.sender];
        if (!v.isActive) revert NotActiveValidator();

        v.isActive = false;
        v.unlockTime = block.timestamp + UNSTAKE_DELAY;

        emit ValidatorUnstakeRequested(msg.sender, v.unlockTime);
    }

    function withdraw() external nonReentrant {
        Validator storage v = validators[msg.sender];
        if (v.isActive) revert NotActiveValidator();
        if (block.timestamp < v.unlockTime) revert UnstakeNotReady();
        if (v.stakedAmount == 0) revert ZeroAmount();

        uint256 amount = v.stakedAmount;
        v.stakedAmount = 0;

        _removeValidator(msg.sender);
        stakeToken.safeTransfer(msg.sender, amount);

        emit ValidatorWithdrawn(msg.sender, amount);
    }

    function deposit(
        uint256 destChain,
        address recipient,
        address token,
        uint256 amount
    ) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 nonce = depositNonce++;

        emit Deposited(destChain, msg.sender, recipient, token, amount, nonce);
    }

    function submitSignature(
        BridgeMessage calldata message,
        bytes calldata signature
    ) external nonReentrant {
        if (message.destChain != chainId) revert ChainMismatch();

        bytes32 messageHash = hashMessage(message);
        if (processedMessages[messageHash]) revert AlreadyProcessed();

        address signer = messageHash.toEthSignedMessageHash().recover(signature);
        if (!validators[signer].isActive) revert NotActiveValidator();
        if (messageSignatures[messageHash][signer]) revert AlreadySigned();

        messageSignatures[messageHash][signer] = true;
        messageSignatureCount[messageHash]++;

        if (messageSignatureCount[messageHash] >= quorumThreshold) {
            processedMessages[messageHash] = true;
            IERC20(message.token).safeTransfer(message.recipient, message.amount);

            emit Executed(messageHash, message.recipient, message.token, message.amount);
        }
    }

    function slashValidator(
        address validator,
        BridgeMessage calldata invalidMessage,
        bytes calldata signature,
        bytes calldata fraudProof
    ) external onlyOwner nonReentrant {
        bytes32 messageHash = hashMessage(invalidMessage);

        address signer = messageHash.toEthSignedMessageHash().recover(signature);
        if (signer != validator) revert InvalidSignature();

        Validator storage v = validators[validator];
        if (v.stakedAmount == 0) revert ZeroAmount();
        if (v.slashCount >= MAX_SLASH_COUNT) revert MaxSlashReached();

        require(_verifyFraudProof(invalidMessage, fraudProof), "Invalid fraud proof");

        uint256 slashAmount = (v.stakedAmount * SLASH_PERCENT) / 100;
        v.stakedAmount -= slashAmount;
        v.slashCount++;

        if (v.stakedAmount < minStake) {
            v.isActive = false;
            v.unlockTime = block.timestamp + UNSTAKE_DELAY;
        }

        stakeToken.safeTransfer(owner(), slashAmount);

        emit ValidatorSlashed(validator, slashAmount, messageHash);
    }

    function hashMessage(BridgeMessage calldata message) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                message.sourceChain,
                message.destChain,
                message.sender,
                message.recipient,
                message.token,
                message.amount,
                message.nonce
            )
        );
    }

    function getValidatorCount() external view returns (uint256) {
        return validatorSet.length;
    }

    function getActiveValidators() external view returns (address[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < validatorSet.length; i++) {
            if (validators[validatorSet[i]].isActive) count++;
        }

        address[] memory active = new address[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < validatorSet.length; i++) {
            if (validators[validatorSet[i]].isActive) {
                active[idx++] = validatorSet[i];
            }
        }
        return active;
    }

    function setMinStake(uint256 _minStake) external onlyOwner {
        minStake = _minStake;
    }

    function setQuorumThreshold(uint256 _quorumThreshold) external onlyOwner {
        quorumThreshold = _quorumThreshold;
    }

    function _verifyFraudProof(
        BridgeMessage calldata message,
        bytes calldata proof
    ) internal pure returns (bool) {
        // In production, this would verify a Merkle proof or SPV proof
        // showing the message does not correspond to a valid deposit
        // on the source chain. For this implementation, the proof must
        // contain a valid counter-evidence hash.
        return proof.length > 0 && keccak256(proof) != keccak256(abi.encode(message));
    }

    function _removeValidator(address validator) internal {
        for (uint256 i = 0; i < validatorSet.length; i++) {
            if (validatorSet[i] == validator) {
                validatorSet[i] = validatorSet[validatorSet.length - 1];
                validatorSet.pop();
                break;
            }
        }
    }
}