// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(address[] calldata assets, uint256[] calldata amounts, uint256[] calldata premiums, address initiator, bytes calldata params) external returns (bool);
}

contract FlashLoanProvider {
    mapping(address => uint256) public deposits;
    uint256 public totalDeposits;
    uint256 public fee = 1; // 1% fee

    function deposit(address asset, uint256 amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        deposits[asset] += amount;
        totalDeposits += amount;
    }

    function withdraw(address asset, uint256 amount) external {
        require(deposits[asset] >= amount, "Insufficient balance");
        deposits[asset] -= amount;
        totalDeposits -= amount;
        IERC20(asset).transfer(msg.sender, amount);
    }

    function flashLoan(address[] calldata assets, uint256[] calldata amounts, bytes calldata params) external {
        require(assets.length == amounts.length, "Mismatched arrays");

        for (uint256 i = 0; i < assets.length; i++) {
            require(deposits[assets[i]] >= amounts[i], "Insufficient liquidity");

            deposits[assets[i]] -= amounts[i];
            IERC20(assets[i]).transfer(msg.sender, amounts[i]);
        }

        bool success = IFlashLoanReceiver(msg.sender).executeOperation(assets, amounts, calculatePremiums(amounts), msg.sender, params);

        require(success, "Flash loan execution failed");

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i] + calculatePremiums(amounts)[i];
            require(IERC20(assets[i]).transferFrom(msg.sender, address(this), amountOwing), "Failed to return tokens");
            deposits[assets[i]] += amounts[i];
        }
    }

    function calculatePremiums(uint256[] calldata amounts) internal view returns (uint256[] memory) {
        uint256[] memory premiums = new uint256[](amounts.length);
        for (uint256 i = 0; i < amounts.length; i++) {
            premiums[i] = (amounts[i] * fee) / 100;
        }
        return premiums;
    }
}