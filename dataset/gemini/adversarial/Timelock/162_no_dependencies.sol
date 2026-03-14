// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Timelock {
    address public owner;
    mapping(uint256 => mapping(address => bool)) public executed;
    mapping(uint256 => mapping(address => uint256)) public queue;

    event Log(address indexed _target, bytes _data, uint256 _value, uint256 _eta, address indexed _executor);

    modifier onlyOwner() {
        require(msg.sender == owner, "Timelock: unauthorized");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function delay() public pure returns (uint256) {
        return 2 days;
    }

    function queueTransaction(address _target, uint256 _value, bytes memory _data, uint256 _eta) public onlyOwner {
        require(_target != address(0), "Timelock: target is zero");
        require(_eta >= block.timestamp + delay(), "Timelock: eta too early");

        uint256 id = uint256(keccak256(abi.encodePacked(_target, _value, _data, _eta)));
        queue[id][msg.sender] = _eta;

        emit Log(_target, _data, _value, _eta, msg.sender);
    }

    function executeTransaction(address _target, uint256 _value, bytes memory _data, uint256 _eta) public payable onlyOwner {
        require(_target != address(0), "Timelock: target is zero");
        require(_eta <= block.timestamp, "Timelock: eta too late");

        uint256 id = uint256(keccak256(abi.encodePacked(_target, _value, _data, _eta)));
        require(queue[id][msg.sender] == _eta, "Timelock: transaction not queued");
        require(!executed[id][msg.sender], "Timelock: transaction already executed");

        executed[id][msg.sender] = true;

        (bool success, ) = _target.call{value: _value}(_data);
        require(success, "Timelock: call failed");
    }

    function cancelTransaction(address _target, uint256 _value, bytes memory _data, uint256 _eta) public onlyOwner {
        require(_target != address(0), "Timelock: target is zero");

        uint256 id = uint256(keccak256(abi.encodePacked(_target, _value, _data, _eta)));
        require(queue[id][msg.sender] == _eta, "Timelock: transaction not queued");
        require(!executed[id][msg.sender], "Timelock: transaction already executed");

        delete queue[id][msg.sender];
    }

    receive() external payable {}
}