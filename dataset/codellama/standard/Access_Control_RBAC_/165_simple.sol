pragma solidity ^0.8.0;

contract RoleBasedAccessControl {
    address public admin;
    address public minter;

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only the admin can perform this action");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Only the minter can perform this action");
        _;
    }

    function setMinter(address _newMinter) public onlyAdmin {
        minter = _newMinter;
    }

    function mint(uint _amount) public onlyMinter {
        // Mint the tokens
    }
}