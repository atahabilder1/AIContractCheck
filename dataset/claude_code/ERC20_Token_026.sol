// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Token that trusts source chain data
contract TrustingBridgeToken {
    string public name = "TrustToken";
    string public symbol = "TRST";
    uint256 public totalSupply;
    address public trustedSource;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event CrossChainMint(uint256 sourceChainId, address to, uint256 amount);

    constructor(address _trustedSource) {
        trustedSource = _trustedSource;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // Trusts source chain - no additional validation
    function mintFromSource(uint256 sourceChainId, address to, uint256 amount) external {
        require(msg.sender == trustedSource, "Not trusted");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
        emit CrossChainMint(sourceChainId, to, amount);
    }

    function burnToSource(uint256 amount) external {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
