// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ERC20 Token with Snapshot Capability
contract SnapshotToken {
    string public name = "Snapshot Token";
    string public symbol = "SNAP";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public owner;
    uint256 public currentSnapshotId;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    struct Snapshot {
        uint256 id;
        uint256 value;
    }

    mapping(address => Snapshot[]) private _accountBalanceSnapshots;
    Snapshot[] private _totalSupplySnapshots;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event SnapshotCreated(uint256 id);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        totalSupply = initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function snapshot() external onlyOwner returns (uint256) {
        currentSnapshotId++;
        emit SnapshotCreated(currentSnapshotId);
        return currentSnapshotId;
    }

    function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256) {
        Snapshot[] storage snapshots = _accountBalanceSnapshots[account];

        if (snapshots.length == 0) {
            return balanceOf[account];
        }

        for (uint256 i = snapshots.length; i > 0; i--) {
            if (snapshots[i - 1].id <= snapshotId) {
                return snapshots[i - 1].value;
            }
        }

        return balanceOf[account];
    }

    function totalSupplyAt(uint256 snapshotId) public view returns (uint256) {
        if (_totalSupplySnapshots.length == 0) {
            return totalSupply;
        }

        for (uint256 i = _totalSupplySnapshots.length; i > 0; i--) {
            if (_totalSupplySnapshots[i - 1].id <= snapshotId) {
                return _totalSupplySnapshots[i - 1].value;
            }
        }

        return totalSupply;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from zero");
        require(to != address(0), "Transfer to zero");
        require(balanceOf[from] >= amount, "Insufficient balance");

        _updateAccountSnapshot(from);
        _updateAccountSnapshot(to);

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }

    function _updateAccountSnapshot(address account) private {
        if (currentSnapshotId > 0) {
            Snapshot[] storage snapshots = _accountBalanceSnapshots[account];
            if (snapshots.length == 0 || snapshots[snapshots.length - 1].id < currentSnapshotId) {
                snapshots.push(Snapshot({id: currentSnapshotId, value: balanceOf[account]}));
            }
        }
    }
}
