// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {
    constructor() ERC20("Staking Reward Token", "SRT") Ownable(msg.sender) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

contract StakableNFT is ERC721Enumerable, Ownable {
    uint256 private _nextTokenId;
    uint256 public mintPrice = 0.01 ether;
    uint256 public maxSupply = 10000;

    RewardToken public rewardToken;
    uint256 public rewardRatePerSecond = 1e16; // 0.01 tokens per second per staked NFT

    struct StakeInfo {
        address owner;
        uint256 stakedAt;
        uint256 accumulatedRewards;
    }

    mapping(uint256 => StakeInfo) public stakes;
    mapping(address => uint256[]) private _stakedTokensByOwner;

    event Staked(address indexed owner, uint256 indexed tokenId);
    event Unstaked(address indexed owner, uint256 indexed tokenId, uint256 rewards);
    event RewardsClaimed(address indexed owner, uint256 rewards);

    constructor() ERC721("Stakable NFT", "SNFT") Ownable(msg.sender) {
        rewardToken = new RewardToken();
    }

    function mint(uint256 quantity) external payable {
        require(quantity > 0 && quantity <= 20, "Invalid quantity");
        require(_nextTokenId + quantity <= maxSupply, "Exceeds max supply");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, _nextTokenId);
            _nextTokenId++;
        }
    }

    function stake(uint256[] calldata tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(ownerOf(tokenId) == msg.sender, "Not token owner");
            require(stakes[tokenId].owner == address(0), "Already staked");

            _transfer(msg.sender, address(this), tokenId);

            stakes[tokenId] = StakeInfo({
                owner: msg.sender,
                stakedAt: block.timestamp,
                accumulatedRewards: 0
            });
            _stakedTokensByOwner[msg.sender].push(tokenId);

            emit Staked(msg.sender, tokenId);
        }
    }

    function unstake(uint256[] calldata tokenIds) external {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            StakeInfo storage info = stakes[tokenId];
            require(info.owner == msg.sender, "Not stake owner");

            uint256 reward = _calculateReward(tokenId);
            totalRewards += reward;

            _transfer(address(this), msg.sender, tokenId);
            _removeStakedToken(msg.sender, tokenId);
            delete stakes[tokenId];

            emit Unstaked(msg.sender, tokenId, reward);
        }

        if (totalRewards > 0) {
            rewardToken.mint(msg.sender, totalRewards);
        }
    }

    function claimRewards(uint256[] calldata tokenIds) external {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            StakeInfo storage info = stakes[tokenId];
            require(info.owner == msg.sender, "Not stake owner");

            totalRewards += _calculateReward(tokenId);
            info.stakedAt = block.timestamp;
            info.accumulatedRewards = 0;
        }

        require(totalRewards > 0, "No rewards to claim");
        rewardToken.mint(msg.sender, totalRewards);

        emit RewardsClaimed(msg.sender, totalRewards);
    }

    function _calculateReward(uint256 tokenId) internal view returns (uint256) {
        StakeInfo storage info = stakes[tokenId];
        uint256 stakingDuration = block.timestamp - info.stakedAt;
        return (stakingDuration * rewardRatePerSecond) + info.accumulatedRewards;
    }

    function _removeStakedToken(address owner, uint256 tokenId) internal {
        uint256[] storage tokens = _stakedTokensByOwner[owner];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    function pendingRewards(uint256 tokenId) external view returns (uint256) {
        require(stakes[tokenId].owner != address(0), "Not staked");
        return _calculateReward(tokenId);
    }

    function stakedTokensOf(address owner) external view returns (uint256[] memory) {
        return _stakedTokensByOwner[owner];
    }

    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRatePerSecond = newRate;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}