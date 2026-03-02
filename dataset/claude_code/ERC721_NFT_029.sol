// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Production-ready ERC721 NFT with comprehensive features
contract ProductionNFT {
    string public name;
    string public symbol;
    address public owner;
    bool public paused;
    string private _baseURI;

    // Token data
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    mapping(uint256 => string) private _tokenURIs;

    // Access control
    mapping(address => bool) public minters;
    mapping(address => bool) public blacklisted;

    // Royalties (EIP-2981)
    address public royaltyReceiver;
    uint96 public royaltyFraction; // basis points (e.g., 250 = 2.5%)

    // Supply management
    uint256 private _tokenIdCounter;
    uint256 public maxSupply;
    uint256 public mintPrice;

    // Whitelist
    mapping(address => bool) public whitelist;
    bool public whitelistOnly;

    // Reveal
    bool public revealed;
    string public unrevealedURI;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event RoyaltyUpdated(address receiver, uint96 fraction);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyMinter() {
        require(minters[msg.sender] || msg.sender == owner, "Not minter");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "Blacklisted");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        address _royaltyReceiver,
        uint96 _royaltyFraction
    ) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        royaltyReceiver = _royaltyReceiver;
        royaltyFraction = _royaltyFraction;
        minters[msg.sender] = true;
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        require(_owner != address(0), "Zero address");
        return _balances[_owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address tokenOwner = _owners[tokenId];
        require(tokenOwner != address(0), "Token doesn't exist");
        return tokenOwner;
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        require(_owners[tokenId] != address(0), "Token doesn't exist");
        if (!revealed) {
            return unrevealedURI;
        }
        string memory _tokenURI = _tokenURIs[tokenId];
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }
        return string(abi.encodePacked(_baseURI, toString(tokenId), ".json"));
    }

    // EIP-2981 Royalty
    function royaltyInfo(uint256, uint256 salePrice) external view returns (address, uint256) {
        uint256 royaltyAmount = (salePrice * royaltyFraction) / 10000;
        return (royaltyReceiver, royaltyAmount);
    }

    function approve(address to, uint256 tokenId) public whenNotPaused notBlacklisted(msg.sender) {
        address tokenOwner = ownerOf(tokenId);
        require(to != tokenOwner, "Approval to owner");
        require(msg.sender == tokenOwner || isApprovedForAll(tokenOwner, msg.sender), "Not authorized");
        _tokenApprovals[tokenId] = to;
        emit Approval(tokenOwner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        require(_owners[tokenId] != address(0), "Token doesn't exist");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) public whenNotPaused notBlacklisted(msg.sender) {
        require(operator != msg.sender, "Approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address _owner, address operator) public view returns (bool) {
        return _operatorApprovals[_owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public whenNotPaused notBlacklisted(from) notBlacklisted(to) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public whenNotPaused notBlacklisted(from) notBlacklisted(to) {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "Non-ERC721 receiver");
    }

    function mint(address to, uint256 quantity) public payable whenNotPaused notBlacklisted(to) {
        if (whitelistOnly) {
            require(whitelist[msg.sender], "Not whitelisted");
        }
        require(_tokenIdCounter + quantity <= maxSupply, "Max supply exceeded");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter++;
            _mint(to, tokenId);
        }
    }

    function adminMint(address to, uint256 quantity) public onlyMinter {
        require(_tokenIdCounter + quantity <= maxSupply, "Max supply exceeded");
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = _tokenIdCounter++;
            _mint(to, tokenId);
        }
    }

    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        address tokenOwner = ownerOf(tokenId);
        delete _tokenApprovals[tokenId];
        _balances[tokenOwner] -= 1;
        delete _owners[tokenId];
        emit Transfer(tokenOwner, address(0), tokenId);
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), "Mint to zero");
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "Not owner");
        require(to != address(0), "Transfer to zero");
        delete _tokenApprovals[tokenId];
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address tokenOwner = ownerOf(tokenId);
        return (spender == tokenOwner || getApproved(tokenId) == spender || isApprovedForAll(tokenOwner, spender));
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch {
                return false;
            }
        }
        return true;
    }

    // Admin functions
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURI = baseURI_;
    }

    function setUnrevealedURI(string memory _unrevealedURI) external onlyOwner {
        unrevealedURI = _unrevealedURI;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setRoyalty(address _receiver, uint96 _fraction) external onlyOwner {
        require(_fraction <= 1000, "Max 10%");
        royaltyReceiver = _receiver;
        royaltyFraction = _fraction;
        emit RoyaltyUpdated(_receiver, _fraction);
    }

    function addToWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = true;
        }
    }

    function removeFromWhitelist(address[] calldata accounts) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            whitelist[accounts[i]] = false;
        }
    }

    function setWhitelistOnly(bool _whitelistOnly) external onlyOwner {
        whitelistOnly = _whitelistOnly;
    }

    function blacklistAddress(address account) external onlyOwner {
        blacklisted[account] = true;
    }

    function unblacklistAddress(address account) external onlyOwner {
        blacklisted[account] = false;
    }

    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
    }

    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }

    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0x80ac58cd || // ERC721
               interfaceId == 0x2a55205a || // ERC2981
               interfaceId == 0x01ffc9a7;   // ERC165
    }
}

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
