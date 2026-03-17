// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TrustedWrappedToken {
    // ERC20 storage
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Ownership
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Trusted bridge
    address public bridge;
    event BridgeUpdated(address indexed previousBridge, address indexed newBridge);

    // Replay protection
    mapping(bytes32 => bool) public processedMessage;
    uint256 public burnNonce;

    // ERC20 events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Bridging events
    event MintedFromSource(
        uint256 indexed sourceChainId,
        address indexed sourceToken,
        address indexed to,
        address from,
        uint256 amount,
        bytes32 sourceTxHash,
        uint256 sourceEventIndex,
        bytes32 messageId,
        bytes metadata
    );

    event BurnedForSource(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed targetChainId,
        address indexed targetToken,
        uint256 burnNonce,
        bytes32 burnId,
        bytes metadata
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge, "Not bridge");
        _;
    }

    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _bridge) {
        require(_bridge != address(0), "Bridge is zero");
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
        bridge = _bridge;
        emit BridgeUpdated(address(0), _bridge);
    }

    // ERC20 view functions
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address _owner, address spender) external view returns (uint256) {
        return _allowances[_owner][spender];
    }

    // ERC20 core
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= value, "Insufficient allowance");
        unchecked {
            _approve(from, msg.sender, currentAllowance - value);
        }
        _transfer(from, to, value);
        return true;
    }

    // Bridge admin
    function setBridge(address newBridge) external onlyOwner {
        require(newBridge != address(0), "Bridge is zero");
        emit BridgeUpdated(bridge, newBridge);
        bridge = newBridge;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Owner is zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Mint on destination chain by trusted bridge
    function mintFromSource(
        uint256 sourceChainId,
        address sourceToken,
        address from,
        address to,
        uint256 amount,
        bytes32 sourceTxHash,
        uint256 sourceEventIndex,
        bytes calldata metadata
    ) external onlyBridge returns (bytes32 messageId) {
        // Construct a unique messageId from source data
        messageId = keccak256(
            abi.encodePacked(
                sourceChainId,
                sourceToken,
                from,
                to,
                amount,
                sourceTxHash,
                sourceEventIndex
            )
        );
        require(!processedMessage[messageId], "Already processed");
        processedMessage[messageId] = true;

        _mint(to, amount);

        emit MintedFromSource(
            sourceChainId,
            sourceToken,
            to,
            from,
            amount,
            sourceTxHash,
            sourceEventIndex,
            messageId,
            metadata
        );
    }

    // Burn on destination to unlock/release on source
    function burnForSource(
        uint256 targetChainId,
        address targetToken,
        address to,
        uint256 amount,
        bytes calldata metadata
    ) external returns (bytes32 burnId) {
        _burn(msg.sender, amount);
        unchecked {
            burnNonce += 1;
        }
        burnId = keccak256(
            abi.encodePacked(
                block.chainid,
                address(this),
                msg.sender,
                to,
                amount,
                targetChainId,
                targetToken,
                burnNonce
            )
        );

        emit BurnedForSource(
            msg.sender,
            to,
            amount,
            targetChainId,
            targetToken,
            burnNonce,
            burnId,
            metadata
        );
    }

    // Rescue tokens accidentally sent to this contract
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "To is zero");
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Rescue failed");
    }

    // Internal ERC20 logic
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "From is zero");
        require(to != address(0), "To is zero");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "Insufficient balance");
        unchecked {
            _balances[from] = fromBalance - value;
        }
        _balances[to] += value;

        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        require(to != address(0), "To is zero");
        totalSupply += value;
        _balances[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        require(from != address(0), "From is zero");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "Insufficient balance");
        unchecked {
            _balances[from] = fromBalance - value;
            totalSupply -= value;
        }
        emit Transfer(from, address(0), value);
    }

    function _approve(address _owner, address spender, uint256 value) internal {
        require(_owner != address(0), "Owner is zero");
        require(spender != address(0), "Spender is zero");
        _allowances[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }
}