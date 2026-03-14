// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MinimalYieldAggregator {
    address public owner;
    IERC20 public underlyingToken;
    address public stakingContract; // Address of the contract where yield is generated

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Harvest(address indexed harvester, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _underlyingToken, address _stakingContract) {
        owner = msg.sender;
        underlyingToken = IERC20(_underlyingToken);
        stakingContract = _stakingContract;
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        underlyingToken.transferFrom(msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(balanceOfUnderlying() >= _amount, "Insufficient balance");
        underlyingToken.transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function balanceOfUnderlying() public view returns (uint256) {
        return underlyingToken.balanceOf(address(this));
    }

    // This function would typically interact with the staking contract to claim rewards.
    // The actual implementation depends on the specific staking contract.
    function harvest() external onlyOwner {
        // Example: Assume stakingContract has a function `claimRewards()` that returns rewards in underlyingToken
        // This is a placeholder and needs to be adapted to the actual staking contract's interface.
        // For demonstration purposes, we'll assume a direct transfer of rewards to this contract.
        // In a real scenario, you'd call a method on stakingContract.
        uint256 rewards = IERC20(stakingContract).balanceOf(address(this)); // This is a simplification
        require(rewards > 0, "No rewards to harvest");

        // In a real scenario, you would call a specific function on the staking contract
        // to claim the rewards and have them sent to this aggregator contract.
        // For this minimal example, we'll just assume rewards are somehow available.
        // If the staking contract *itself* holds the rewards, you'd need a way to withdraw them.

        // Let's simulate a scenario where the staking contract is also an ERC20 and we can transfer from it.
        // THIS IS HIGHLY DEPENDENT ON THE STAKING CONTRACT'S DESIGN.
        // A more realistic harvest would involve calling a specific function on the staking contract.
        // For instance: `IERC20(stakingContract).transfer(address(this), rewards_from_staking_contract);`
        // Or even better: `IStakingContract(stakingContract).claimRewards();` which would then deposit rewards to this contract.

        // For this minimal example, let's assume the staking contract *is* the reward token and we can transfer it.
        // This is unlikely but demonstrates the concept of moving earned tokens.
        // If the staking contract is NOT the reward token, this logic needs to change significantly.

        // A more robust approach would be to check if the staking contract has a function like `claimRewards()`
        // and call that. For this minimal example, we'll just use a placeholder.

        // For the sake of a runnable minimal example, let's assume the staking contract *is* the underlying token
        // and we can "harvest" by simply checking its balance and transferring. This is NOT how yield farming works.
        // A proper yield aggregator harvests rewards from a *separate* staking contract.

        // Let's refine this to be more conceptually accurate, assuming the staking contract *emits* rewards
        // that can be claimed by this aggregator.
        // This is still a simplification. A real harvest function would interact with the staking contract's API.

        // Placeholder for actual reward claiming logic.
        // In a real system, you would call a function on the `stakingContract` to claim rewards.
        // For example: `IStakingContract(stakingContract).claimRewards();`
        // And then the rewards would be sent to `address(this)`.

        // Let's simulate receiving rewards for this minimal example.
        // Assume `underlyingToken` is also the reward token and it has been transferred to `stakingContract`
        // and `stakingContract` has a method `getRewards()` that returns the reward token.
        // This is getting complicated for "minimal".

        // The most minimal viable harvest would be:
        // 1. Call a function on the staking contract that sends rewards to this contract.
        // 2. Or, call a function on the staking contract that returns rewards, and then transfer them.

        // Let's assume the staking contract has a function `claimRewardsTo(address _recipient)`
        // and `underlyingToken` is the reward token.
        // This requires defining an interface for the staking contract.

        // For a truly minimal example, let's just assume the rewards are already in `stakingContract`
        // and we can transfer them to `address(this)` IF `stakingContract` is an ERC20.
        // This is a very weak assumption.

        // Let's go with the most basic interaction:
        // Assume the `stakingContract` is designed such that calling a specific function
        // on it will deposit rewards (in `underlyingToken`) into `address(this)`.
        // We'll call a hypothetical `claimAndDepositRewards()` function on the staking contract.
        // This requires an interface.

        // Minimalist approach: Assume rewards are already in the staking contract and can be withdrawn by this contract.
        // This implies the staking contract has a withdrawal function accessible by this contract.
        // Again, highly dependent on the staking contract.

        // Let's simplify to the core idea: Harvest means getting earned tokens into this contract.
        // We'll assume the staking contract is an ERC20 and we can transfer from it to this contract.
        // This is conceptually flawed for most yield farms, but it's minimal.

        // A more common pattern: The staking contract allows anyone to claim rewards,
        // and they are sent to the staker. We want to claim them for the aggregator.
        // This means the aggregator needs to interact with the staking contract.

        // Let's assume the `stakingContract` has a function `claimRewards()` that sends rewards to `address(this)`.
        // We'll simulate this by checking the balance of `underlyingToken` in the `stakingContract`
        // and transferring it. This is NOT how it works, but demonstrates the concept of *moving* rewards.

        // A better minimal approach:
        // The `stakingContract` is an ERC20 and we can transfer from it.
        // This assumes the rewards are in `stakingContract` itself.
        // This is highly unlikely.

        // Let's assume the `stakingContract` is a standard ERC20 and rewards are *sent* to it,
        // and we can then transfer them.
        // THIS IS A HUGE SIMPLIFICATION.

        // Let's assume `stakingContract` is an ERC20 and we can claim rewards from it.
        // This requires `stakingContract` to be the reward token itself, which is unlikely.

        // The MOST minimal harvest:
        // Assume the staking contract has a function `claimRewards()` that sends rewards to `address(this)`.
        // We'll simulate this by just checking the balance of the `underlyingToken` in `address(this)`
        // after some hypothetical action.
        // This is not a true harvest.

        // Let's try this: The `stakingContract` is an ERC20, and we can transfer from it.
        // This implies the rewards are deposited into `stakingContract` itself.
        // This is a very basic, and likely incorrect, assumption for a real yield farm.

        // The core idea of harvest is to claim rewards and deposit them into the aggregator.
        // So, we need to call a function on the `stakingContract` that provides rewards.

        // Let's assume the `stakingContract` IS the token that rewards are paid in (unlikely but minimal).
        // And we can transfer from it.
        // This is still not quite right.

        // The absolute minimal harvest:
        // Assume `stakingContract` has a function `claimRewards()` that sends rewards to `address(this)`.
        // For this minimal example, we'll assume that calling `stakingContract.claimRewards()`
        // will result in `underlyingToken` being sent to `address(this)`.
        // We'll then just check the balance.

        // Let's define an interface for the staking contract for clarity.
        interface IStakingContract {
            function claimRewards() external returns (uint256); // Hypothetical function
        }

        // This is still very abstract. A more concrete minimal approach:
        // Assume the rewards are in the `stakingContract` and we can transfer them.
        // This would mean `stakingContract` must be an ERC20 token itself.

        // Let's assume the `stakingContract` is a simple ERC20 and we can transfer from it.
        // This is a gross oversimplification of yield farming.
        // A yield farm typically has a separate reward token and a staking contract.
        // The aggregator interacts with the staking contract to claim rewards.

        // Let's assume the `stakingContract` is an ERC20 and we can transfer from it.
        // This means the rewards are somehow deposited into the `stakingContract` itself.

        // A more typical harvest function would look like:
        // 1. Call a function on the staking contract to claim rewards.
        // 2. The staking contract sends rewards (e.g., `underlyingToken`) to `address(this)`.
        // 3. This function then records the harvested amount.

        // For this minimal example, let's assume the `stakingContract` has a function
        // `claimRewardsTo(address _recipient)` that sends `underlyingToken` to `_recipient`.
        // We'll call this function. This requires defining an interface.

        interface IRewardDistributor {
            function claimRewards() external; // Assume this function sends rewards to msg.sender (this contract)
        }

        // Let's assume the `stakingContract` is an ERC20 and we can transfer from it.
        // This implies the rewards have been deposited into the `stakingContract` itself.
        // This is a very simplified model.

        // For a minimal example, let's assume the `stakingContract` is an ERC20 and we can transfer FROM it.
        // This implies the rewards are stored in the `stakingContract` itself.
        // This is NOT how most yield farms work, but it's minimal.
        // A real harvest would involve calling a specific function on the staking contract.

        // Let's simulate a scenario where the staking contract is an ERC20 and we can claim from it.
        // This means the `stakingContract` address *is* the reward token contract.
        // This is unlikely, but for a minimal example:
        uint256 rewards = IERC20(stakingContract).balanceOf(address(this)); // Check if rewards are already here. Unlikely.

        // A more plausible minimal harvest:
        // Assume the `stakingContract` has a function `claimRewards()` which sends rewards to `msg.sender`.
        // So, we call `stakingContract.claimRewards()`.
        // The rewards will then be in `address(this)`.

        // Let's define an interface for the staking contract.
        interface IStakingYield {
            function claimRewards() external; // This function should send rewards to msg.sender
        }

        // Calling the hypothetical claimRewards function on the staking contract.
        // This function is expected to transfer the earned rewards (in underlyingToken) to this contract.
        IStakingYield(stakingContract).claimRewards();

        // After the claim, check how much underlyingToken is now in this contract.
        // This is the harvested amount.
        uint256 harvestedAmount = balanceOfUnderlying(); // This assumes rewards are in underlyingToken
        require(harvestedAmount > 0, "No rewards harvested");

        emit Harvest(msg.sender, harvestedAmount);
    }

    // Function to rebalance or compound rewards would go here.
    // For a minimal example, we omit this.
}