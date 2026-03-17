// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract IsolatedLendingPool {
    struct Market {
        address collateralToken;
        address borrowToken;
        uint256 totalCollateral;
        uint256 totalBorrowed;
        uint256 interestRate;
        uint256 liquidationThreshold;
    }

    mapping(address => Market) markets;

    function createMarket(address _collateralToken, address _borrowToken, uint256 _interestRate, uint256 _liquidationThreshold) public {
        require(_collateralToken != address(0), "Collateral token is zero address");
        require(_borrowToken != address(0), "Borrow token is zero address");
        require(_interestRate > 0, "Interest rate must be greater than zero");
        require(_liquidationThreshold > 0 && _liquidationThreshold < 1e18, "Liquidation threshold is invalid");

        markets[_collateralToken] = Market(_collateralToken, _borrowToken, 0, 0, _interestRate, _liquidationThreshold);
    }

    function depositCollateral(address _market, uint256 _amount) public {
        require(_amount > 0, "Deposit amount must be greater than zero");

        markets[_market].totalCollateral += _amount;
    }

    function borrowTokens(address _market, uint256 _amount) public {
        require(_amount > 0, "Borrow amount must be greater than zero");
        require(_amount <= calculateMaxBorrowableAmount(_market), "Borrow amount exceeds the maximum borrowable amount");

        markets[_market].totalBorrowed += _amount;
    }

    function calculateMaxBorrowableAmount(address _market) public view returns (uint256) {
        return (markets[_market].totalCollateral * markets[_market].liquidationThreshold) / 1e18;
    }
}