// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Most gas efficient ERC20 implementation
contract UltraEfficientERC20 {
    mapping(address => uint256) private _b;
    mapping(address => mapping(address => uint256)) private _a;
    uint256 private _t;

    event Transfer(address indexed, address indexed, uint256);
    event Approval(address indexed, address indexed, uint256);

    constructor(uint256 supply) { _t = supply; _b[msg.sender] = supply; }

    function name() external pure returns (string memory) { return "Efficient"; }
    function symbol() external pure returns (string memory) { return "EFF"; }
    function decimals() external pure returns (uint8) { return 18; }
    function totalSupply() external view returns (uint256) { return _t; }
    function balanceOf(address a) external view returns (uint256) { return _b[a]; }
    function allowance(address o, address s) external view returns (uint256) { return _a[o][s]; }

    function transfer(address to, uint256 val) external returns (bool) {
        _b[msg.sender] -= val;
        unchecked { _b[to] += val; }
        emit Transfer(msg.sender, to, val);
        return true;
    }

    function approve(address spender, uint256 val) external returns (bool) {
        _a[msg.sender][spender] = val;
        emit Approval(msg.sender, spender, val);
        return true;
    }

    function transferFrom(address from, address to, uint256 val) external returns (bool) {
        _a[from][msg.sender] -= val;
        _b[from] -= val;
        unchecked { _b[to] += val; }
        emit Transfer(from, to, val);
        return true;
    }
}
