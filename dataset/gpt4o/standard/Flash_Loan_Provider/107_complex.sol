// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IFlashLoanReceiver {
    function executeOperation(address[] calldata assets, uint256[] calldata amounts, uint256[] calldata premiums, address initiator, bytes calldata params) external returns (bool);
}

contract FlashLoanProvider {
    struct Pool {
        uint256 totalLiquidity;
        uint256 totalDeposits;
    }

    mapping(address => Pool) public pools;
    mapping(address => uint256) public depositors;

    uint256 public constant FLASH_LOAN_FEE = 9; // 0.09% fee
    uint256 public constant FEE_DIVISOR = 10000;

    function deposit(address asset, uint256 amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        pools[asset].totalLiquidity += amount;
        pools[asset].totalDeposits += amount;
        depositors[msg.sender] += amount;
    }

    function withdraw(address asset, uint256 amount) external {
        require(depositors[msg.sender] >= amount, "Insufficient deposit");
        require(pools[asset].totalLiquidity >= amount, "Insufficient liquidity");

        depositors[msg.sender] -= amount;
        pools[asset].totalLiquidity -= amount;
        IERC20(asset).transfer(msg.sender, amount);
    }

    function executeFlashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        bytes calldata params
    ) external {
        require(assets.length == amounts.length, "Assets and amounts length mismatch");

        uint256[] memory premiums = new uint256[](assets.length);
        uint256[] memory initialBalances = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            initialBalances[i] = IERC20(assets[i]).balanceOf(address(this));
            require(pools[assets[i]].totalLiquidity >= amounts[i], "Insufficient liquidity for asset");
            premiums[i] = (amounts[i] * FLASH_LOAN_FEE) / FEE_DIVISOR;
            pools[assets[i]].totalLiquidity -= amounts[i];
            IERC20(assets[i]).transfer(receiverAddress, amounts[i]);
        }

        require(
            IFlashLoanReceiver(receiverAddress).executeOperation(assets, amounts, premiums, msg.sender, params),
            "Flash loan execution failed"
        );

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 totalRepayment = amounts[i] + premiums[i];
            require(IERC20(assets[i]).balanceOf(address(this)) >= initialBalances[i] + premiums[i], "Insufficient repayment");
            pools[assets[i]].totalLiquidity += totalRepayment;
        }
    }
}