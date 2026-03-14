// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrossChainBridge {

    address public owner;
    mapping(uint256 => bool) public lockedAssets;
    mapping(uint256 => address) public assetDestinations;
    mapping(uint256 => uint256) public assetAmounts;
    uint256 public nextAssetId;

    event AssetLocked(uint256 indexed assetId, address indexed destination, uint256 amount);
    event AssetUnlocked(uint256 indexed assetId, address destination, uint256 amount);

    constructor() {
        owner = msg.sender;
        nextAssetId = 1;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    /**
     * @notice Locks an asset on the current chain and records its destination and amount.
     * This function should be called by a relayer or an external system that
     * initiates the cross-chain transfer. The actual asset transfer (e.g., burning
     * on one chain, minting on another) would be handled by external logic.
     * @param destination The address on the destination chain where the asset should be unlocked.
     * @param amount The amount of the asset to be locked.
     */
    function lockAsset(address destination, uint256 amount) public payable {
        require(amount > 0, "Amount must be greater than zero.");
        require(msg.value == amount, "Sent amount must match the specified amount."); // Assuming native ether for simplicity

        uint256 currentAssetId = nextAssetId;
        lockedAssets[currentAssetId] = true;
        assetDestinations[currentAssetId] = destination;
        assetAmounts[currentAssetId] = amount;
        nextAssetId++;

        emit AssetLocked(currentAssetId, destination, amount);
    }

    /**
     * @notice Unlocks an asset on the current chain, effectively completing the cross-chain transfer.
     * This function should be called by a relayer or an external system that
     * verifies the asset has been locked on the source chain and initiates the release.
     * The actual asset release (e.g., minting on the destination chain) would be handled by external logic.
     * @param assetId The unique identifier of the asset that was locked.
     * @param destination The original destination address provided when locking the asset.
     * @param amount The amount of the asset to be unlocked.
     */
    function unlockAsset(uint256 assetId, address destination, uint256 amount) public onlyOwner {
        require(lockedAssets[assetId], "Asset has not been locked or is already unlocked.");
        require(assetDestinations[assetId] == destination, "Destination mismatch.");
        require(assetAmounts[assetId] == amount, "Amount mismatch.");

        lockedAssets[assetId] = false; // Mark as unlocked
        delete assetDestinations[assetId];
        delete assetAmounts[assetId];

        // In a real bridge, this would involve sending the asset back to the owner
        // or to a designated pool. For this standalone example, we'll just emit an event.
        // If this contract were to hold tokens, you would add logic here to transfer them.
        // For native ether, you could send it back to the caller of this function:
        // payable(msg.sender).transfer(amount);

        emit AssetUnlocked(assetId, destination, amount);
    }

    /**
     * @notice Allows the owner to withdraw any native ether accidentally sent to the contract.
     * This is a safety measure and should be used with caution.
     * @param amount The amount of ether to withdraw.
     */
    function withdrawEther(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "Insufficient contract balance.");
        payable(msg.sender).transfer(amount);
    }

    // Fallback function to receive native ether
    receive() external payable {}
}