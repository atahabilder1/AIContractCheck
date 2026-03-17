// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TestnetEscrow {
    struct EscrowDeal {
        address depositor;
        address beneficiary;
        address arbiter;
        uint256 amount;
        bool released;
        bool refunded;
    }

    uint256 private _nextId = 1;
    mapping(uint256 => EscrowDeal) private _escrows;

    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "Reentrancy");
        _locked = true;
        _;
        _locked = false;
    }

    event EscrowCreated(
        uint256 indexed id,
        address indexed depositor,
        address indexed beneficiary,
        address arbiter,
        uint256 amount
    );

    event Deposited(
        uint256 indexed id,
        address indexed depositor,
        uint256 amount
    );

    event Released(
        uint256 indexed id,
        address indexed beneficiary,
        uint256 amount,
        address indexed caller
    );

    event Refunded(
        uint256 indexed id,
        address indexed depositor,
        uint256 amount,
        address indexed caller
    );

    modifier exists(uint256 id) {
        require(_escrows[id].depositor != address(0), "Escrow: not found");
        _;
    }

    modifier notCompleted(uint256 id) {
        EscrowDeal storage e = _escrows[id];
        require(!e.released && !e.refunded, "Escrow: completed");
        _;
    }

    modifier onlyArbiter(uint256 id) {
        require(msg.sender == _escrows[id].arbiter, "Escrow: not arbiter");
        _;
    }

    modifier onlyDepositor(uint256 id) {
        require(msg.sender == _escrows[id].depositor, "Escrow: not depositor");
        _;
    }

    function createEscrow(address beneficiary, address arbiter) external payable returns (uint256 id) {
        require(beneficiary != address(0), "Escrow: beneficiary zero");
        require(arbiter != address(0), "Escrow: arbiter zero");
        require(msg.value > 0, "Escrow: zero value");

        id = _nextId++;
        _escrows[id] = EscrowDeal({
            depositor: msg.sender,
            beneficiary: beneficiary,
            arbiter: arbiter,
            amount: msg.value,
            released: false,
            refunded: false
        });

        emit EscrowCreated(id, msg.sender, beneficiary, arbiter, msg.value);
    }

    function deposit(uint256 id) external payable exists(id) notCompleted(id) onlyDepositor(id) {
        require(msg.value > 0, "Escrow: zero value");
        _escrows[id].amount += msg.value;
        emit Deposited(id, msg.sender, msg.value);
    }

    function release(uint256 id) external exists(id) notCompleted(id) onlyArbiter(id) nonReentrant {
        EscrowDeal storage e = _escrows[id];
        uint256 amount = e.amount;
        require(amount > 0, "Escrow: empty");

        e.released = true;
        e.amount = 0;

        (bool ok, ) = payable(e.beneficiary).call{value: amount}("");
        require(ok, "Escrow: transfer failed");

        emit Released(id, e.beneficiary, amount, msg.sender);
    }

    function refund(uint256 id) external exists(id) notCompleted(id) onlyArbiter(id) nonReentrant {
        EscrowDeal storage e = _escrows[id];
        uint256 amount = e.amount;
        require(amount > 0, "Escrow: empty");

        e.refunded = true;
        e.amount = 0;

        (bool ok, ) = payable(e.depositor).call{value: amount}("");
        require(ok, "Escrow: transfer failed");

        emit Refunded(id, e.depositor, amount, msg.sender);
    }

    function getEscrow(uint256 id)
        external
        view
        exists(id)
        returns (
            address depositor,
            address beneficiary,
            address arbiter,
            uint256 amount,
            bool released,
            bool refunded
        )
    {
        EscrowDeal storage e = _escrows[id];
        return (e.depositor, e.beneficiary, e.arbiter, e.amount, e.released, e.refunded);
    }

    function totalEscrows() external view returns (uint256) {
        return _nextId - 1;
    }

    receive() external payable {
        revert("Escrow: use createEscrow/deposit");
    }

    fallback() external payable {
        revert("Escrow: invalid call");
    }
}