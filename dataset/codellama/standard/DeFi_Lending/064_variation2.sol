// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LendingPool {
    struct Collateral {
        address collateral;
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 liquidationPenalty;
        uint256 liquidationThreshold;
        uint256 liquidationPriority;
    }

    struct Market {
        address[] collaterals;
        address[] borrowers;
        mapping(address => uint256) collateralIndex;
        mapping(address => uint256) borrowerIndex;
        mapping(address => Collateral) collateralsMap;
        mapping(address => Collateral) borrowersMap;
    }

    mapping(address => Market) markets;
    mapping(address => mapping(address => uint256)) marketCollateralIndex;
    mapping(address => mapping(address => uint256)) marketBorrowerIndex;

    function addMarket(address _collateral, address _borrower, uint256 _amount, uint256 _interestRate, uint256 _liquidationPenalty, uint256 _liquidationThreshold, uint256 _liquidationPriority) public {
        Market storage market = markets[_collateral];
        Collateral storage collateral = market.collateralsMap[_collateral];
        Collateral storage borrower = market.borrowersMap[_borrower];

        market.collateralIndex[_collateral] = market.collaterals.length;
        market.borrowerIndex[_borrower] = market.borrowers.length;

        market.collaterals.push(collateral);
        market.borrowers.push(borrower);

        collateral.amount = _amount;
        collateral.interestRate = _interestRate;
        collateral.liquidationPenalty = _liquidationPenalty;
        collateral.liquidationThreshold = _liquidationThreshold;
        collateral.liquidationPriority = _liquidationPriority;

        borrower.amount = _amount;
        borrower.interestRate = _interestRate;
        borrower.liquidationPenalty = _liquidationPenalty;
        borrower.liquidationThreshold = _liquidationThreshold;
        borrower.liquidationPriority = _liquidationPriority;
    }

    function removeMarket(address _collateral, address _borrower) public {
        Market storage market = markets[_collateral];
        Collateral storage collateral = market.collateralsMap[_collateral];
        Collateral storage borrower = market.borrowersMap[_borrower];

        market.collaterals.length--;
        market.borrowers.length--;

        delete market.collateralsMap[_collateral];
        delete market.borrowersMap[_borrower];

        delete market.collateralIndex[_collateral];
        delete market.borrowerIndex[_borrower];
    }

    function getCollateral(address _collateral) public view returns (Collateral storage) {
        Market storage market = markets[_collateral];
        return market.collateralsMap[_collateral];
    }

    function getBorrower(address _borrower) public view returns (Collateral storage) {
        Market storage market = markets[_borrower];
        return market.borrowersMap[_borrower];
    }

    function getCollateralIndex(address _collateral) public view returns (uint256) {
        Market storage market = markets[_collateral];
        return market.collateralIndex[_collateral];
    }

    function getBorrowerIndex(address _borrower) public view returns (uint256) {
        Market storage market = markets[_borrower];
        return market.borrowerIndex[_borrower];
    }
}