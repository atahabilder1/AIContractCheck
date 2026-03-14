// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BridgeRelayer {
    address public admin;
    bool public paused;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not an admin");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    event AdminChanged(address indexed newAdmin);
    event Paused();
    event Unpaused();
    event FundsWithdrawn(uint256 amount);

    constructor(address _admin) {
        admin = _admin;
        paused = false;
    }

    function changeAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        admin = _newAdmin;
        emit AdminChanged(_newAdmin);
    }

    function pause() external onlyAdmin {
        require(!paused, "Already paused");
        paused = true;
        emit Paused();
    }

    function unpause() external onlyAdmin {
        require(paused, "Not paused");
        paused = false;
        emit Unpaused();
    }

    function withdrawFunds() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(admin).transfer(balance);
        emit FundsWithdrawn(balance);
    }

    function bridgeTransfer(address _recipient, uint256 _amount) external payable whenNotPaused {
        require(_recipient != address(0), "Invalid recipient");
        require(msg.value == _amount, "Incorrect amount");
        // Bridge transfer logic here
    }
}