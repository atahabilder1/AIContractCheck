// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EmergencyNFT is ERC721Pausable, AccessControl, ReentrancyGuard {
    using Counters for Counters.Counter;

    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");

    Counters.Counter private _tokenIdCounter;

    string private _baseTokenURI;
    uint256 public immutable maxSupply;
    uint256 public mintPrice;

    event BaseURISet(string newBaseURI);
    event MintPriceSet(uint256 newPrice);
    event EmergencyWithdrawal(address indexed to, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 price_,
        uint256 maxSupply_
    ) ERC721(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ADMIN_ROLE, msg.sender);
        _baseTokenURI = baseURI_;
        mintPrice = price_;
        maxSupply = maxSupply_;
    }

    function mint(uint256 quantity) external payable whenNotPaused {
        require(quantity > 0, "Quantity zero");
        uint256 newTotal = _tokenIdCounter.current() + quantity;
        require(newTotal <= maxSupply, "Exceeds max supply");
        require(msg.value == mintPrice * quantity, "Incorrect value");

        for (uint256 i = 0; i < quantity; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current());
        }
    }

    function totalMinted() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function setBaseURI(string calldata newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    function setMintPrice(uint256 newPrice) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintPrice = newPrice;
        emit MintPriceSet(newPrice);
    }

    function pause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(EMERGENCY_ADMIN_ROLE) {
        _unpause();
    }

    function emergencyWithdrawAll(address payable to) external onlyRole(EMERGENCY_ADMIN_ROLE) nonReentrant {
        require(to != address(0), "Zero address");
        uint256 amount = address(this).balance;
        to.transfer(amount);
        emit EmergencyWithdrawal(to, amount);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    receive() external payable {}
    fallback() external payable {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}