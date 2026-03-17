// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ReputationBasedFunctionPermissions {
    // ----------------- Ownership -----------------
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "OwnerOnly");
        _;
    }

    constructor() {
        owner = msg.sender;

        // Default reputation thresholds
        // Level 0 => 0
        // Level 1 => 100
        // Level 2 => 1000
        _setLevelThreshold(0, 0);
        _setLevelThreshold(1, 100);
        _setLevelThreshold(2, 1000);

        // Sample function permissions
        // postContent(string) requires level 1
        _setFunctionPermission(bytes4(keccak256(bytes("postContent(string)"))), 1);
        // deleteContent(uint256) requires level 2
        _setFunctionPermission(bytes4(keccak256(bytes("deleteContent(uint256)"))), 2);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ZeroAddress");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ----------------- Reputation -----------------
    mapping(address => uint256) public reputation;
    mapping(address => bool) public feeder;

    event FeederSet(address indexed feeder, bool allowed);
    event ReputationIncreased(address indexed account, address indexed operator, uint256 amount, uint256 newScore);
    event ReputationDecreased(address indexed account, address indexed operator, uint256 amount, uint256 newScore);
    event ReputationSet(address indexed account, address indexed operator, uint256 newScore);

    modifier onlyFeeder() {
        require(feeder[msg.sender] || msg.sender == owner, "FeederOnly");
        _;
    }

    function setFeeder(address account, bool allowed) external onlyOwner {
        feeder[account] = allowed;
        emit FeederSet(account, allowed);
    }

    function increaseReputation(address account, uint256 amount) external onlyFeeder {
        require(account != address(0), "ZeroAddress");
        uint256 newScore = reputation[account] + amount;
        reputation[account] = newScore;
        emit ReputationIncreased(account, msg.sender, amount, newScore);
    }

    function decreaseReputation(address account, uint256 amount) external onlyFeeder {
        require(account != address(0), "ZeroAddress");
        uint256 current = reputation[account];
        uint256 newScore = amount >= current ? 0 : current - amount;
        reputation[account] = newScore;
        emit ReputationDecreased(account, msg.sender, amount, newScore);
    }

    function setReputation(address account, uint256 newScore) external onlyOwner {
        require(account != address(0), "ZeroAddress");
        reputation[account] = newScore;
        emit ReputationSet(account, msg.sender, newScore);
    }

    // ----------------- Levels & Thresholds -----------------
    // minScoreForLevel[level] => minimum reputation required to achieve 'level'
    mapping(uint8 => uint256) public minScoreForLevel;
    uint8 public maxDefinedLevel;

    event LevelThresholdSet(uint8 indexed level, uint256 minScore);

    function setLevelThreshold(uint8 level, uint256 minScore) external onlyOwner {
        _setLevelThreshold(level, minScore);
    }

    function setLevelThresholds(uint8[] calldata levels, uint256[] calldata minScores) external onlyOwner {
        require(levels.length == minScores.length, "LengthMismatch");
        for (uint256 i = 0; i < levels.length; i++) {
            _setLevelThreshold(levels[i], minScores[i]);
        }
    }

    function _setLevelThreshold(uint8 level, uint256 minScore) internal {
        minScoreForLevel[level] = minScore;
        if (level > maxDefinedLevel) {
            maxDefinedLevel = level;
        }
        emit LevelThresholdSet(level, minScore);
    }

    function permissionLevelOf(address account) public view returns (uint8) {
        uint256 rep = reputation[account];
        uint8 level = 0;
        uint8 maxLevel = maxDefinedLevel;
        for (uint8 i = 0; i <= maxLevel; i++) {
            if (rep >= minScoreForLevel[i]) {
                level = i;
            }
        }
        return level;
    }

    // ----------------- Function Permissions -----------------
    // requiredLevelBySelector[selector] => minimum level needed to call the function
    mapping(bytes4 => uint8) public requiredLevelBySelector;

    event FunctionPermissionSet(bytes4 indexed selector, uint8 level);

    function setFunctionPermission(bytes4 selector, uint8 level) external onlyOwner {
        _setFunctionPermission(selector, level);
    }

    function setFunctionPermissionBySignature(string calldata signature, uint8 level) external onlyOwner {
        bytes4 selector = bytes4(keccak256(bytes(signature)));
        _setFunctionPermission(selector, level);
    }

    function setBatchFunctionPermissions(bytes4[] calldata selectors, uint8 level) external onlyOwner {
        for (uint256 i = 0; i < selectors.length; i++) {
            _setFunctionPermission(selectors[i], level);
        }
    }

    function _setFunctionPermission(bytes4 selector, uint8 level) internal {
        requiredLevelBySelector[selector] = level;
        emit FunctionPermissionSet(selector, level);
    }

    function requiredPermissionFor(bytes4 selector) external view returns (uint8) {
        return requiredLevelBySelector[selector];
    }

    function requiredPermissionForSignature(string calldata signature) external view returns (uint8) {
        return requiredLevelBySelector[bytes4(keccak256(bytes(signature)))];
    }

    // ----------------- Modifier -----------------
    modifier requiresPermission() {
        if (msg.sender != owner) {
            uint8 userLevel = permissionLevelOf(msg.sender);
            uint8 requiredLevel = requiredLevelBySelector[msg.sig];
            require(userLevel >= requiredLevel, "InsufficientPermission");
        }
        _;
    }

    // ----------------- Example Usage -----------------
    event ActionExecuted(address indexed user, string action, uint8 userLevel);

    // Requires level >= 1 (configured in constructor)
    function postContent(string calldata content) external requiresPermission {
        // Example action logic
        emit ActionExecuted(msg.sender, content, permissionLevelOf(msg.sender));
    }

    // Requires level >= 2 (configured in constructor)
    function deleteContent(uint256 contentId) external requiresPermission {
        // Example admin/moderator action logic
        emit ActionExecuted(msg.sender, string(abi.encodePacked("delete:", _toString(contentId))), permissionLevelOf(msg.sender));
    }

    // ----------------- Utilities -----------------
    function computeSelector(string calldata signature) external pure returns (bytes4) {
        return bytes4(keccak256(bytes(signature)));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + uint256(temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }
}