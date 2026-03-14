// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LazyMintNFT is ERC721, ERC721Enumerable, IERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    struct RoyaltyRecipient {
        address payable wallet;
        uint256 share;
    }

    struct TokenMetadata {
        string name;
        string description;
        string image;
        string animationUrl;
        string[] traitTypes;
        string[] traitValues;
    }

    struct LazyMintVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        bytes signature;
    }

    uint256 private _nextTokenId;
    uint256 public maxSupply;
    uint256 public mintPrice;
    uint256 public maxPerWallet;
    uint256 public maxBatchSize;

    bytes32 public merkleRoot;
    bool public allowlistActive;
    bool public publicSaleActive;

    mapping(uint256 => TokenMetadata) private _tokenMetadata;
    mapping(address => uint256) public mintedPerWallet;
    mapping(uint256 => bool) private _lazyMintClaimed;

    RoyaltyRecipient[] public royaltyRecipients;
    uint256 public totalRoyaltyBps;

    address public voucherSigner;

    event LazyMintRedeemed(address indexed minter, uint256 indexed tokenId, uint256 price);
    event BatchMinted(address indexed minter, uint256 startTokenId, uint256 quantity);
    event MetadataUpdated(uint256 indexed tokenId);
    event RoyaltyRecipientsUpdated(uint256 totalBps);

    error ExceedsMaxSupply();
    error ExceedsMaxPerWallet();
    error ExceedsBatchSize();
    error InsufficientPayment();
    error SaleNotActive();
    error InvalidMerkleProof();
    error InvalidVoucherSignature();
    error VoucherAlreadyClaimed();
    error InvalidRoyaltyConfig();
    error WithdrawFailed();
    error InvalidMetadata();
    error ZeroAddress();

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        uint256 maxPerWallet_,
        uint256 maxBatchSize_,
        address voucherSigner_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
        maxPerWallet = maxPerWallet_;
        maxBatchSize = maxBatchSize_;
        voucherSigner = voucherSigner_;
    }

    // ========================
    // Allowlist Mint (Merkle)
    // ========================

    function allowlistMint(uint256 quantity, bytes32[] calldata proof) external payable nonReentrant {
        if (!allowlistActive) revert SaleNotActive();
        if (msg.value < mintPrice * quantity) revert InsufficientPayment();
        if (mintedPerWallet[msg.sender] + quantity > maxPerWallet) revert ExceedsMaxPerWallet();

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidMerkleProof();

        _mintBatch(msg.sender, quantity);
    }

    // ========================
    // Public Mint
    // ========================

    function publicMint(uint256 quantity) external payable nonReentrant {
        if (!publicSaleActive) revert SaleNotActive();
        if (msg.value < mintPrice * quantity) revert InsufficientPayment();
        if (mintedPerWallet[msg.sender] + quantity > maxPerWallet) revert ExceedsMaxPerWallet();

        _mintBatch(msg.sender, quantity);
    }

    // ========================
    // Batch Minting
    // ========================

    function _mintBatch(address to, uint256 quantity) internal {
        if (quantity > maxBatchSize) revert ExceedsBatchSize();
        if (_nextTokenId + quantity > maxSupply) revert ExceedsMaxSupply();

        uint256 startId = _nextTokenId;
        mintedPerWallet[to] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, _nextTokenId);
            _nextTokenId++;
        }

        emit BatchMinted(to, startId, quantity);
    }

    function ownerMintBatch(address to, uint256 quantity) external onlyOwner {
        if (_nextTokenId + quantity > maxSupply) revert ExceedsMaxSupply();
        if (quantity > maxBatchSize) revert ExceedsBatchSize();

        uint256 startId = _nextTokenId;
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(to, _nextTokenId);
            _nextTokenId++;
        }

        emit BatchMinted(to, startId, quantity);
    }

    // ========================
    // Lazy Minting
    // ========================

    function redeemLazyMint(LazyMintVoucher calldata voucher) external payable nonReentrant {
        if (voucher.price > 0 && msg.value < voucher.price) revert InsufficientPayment();
        if (_lazyMintClaimed[voucher.tokenId]) revert VoucherAlreadyClaimed();

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(voucher.tokenId, voucher.price, voucher.uri))
            )
        );

        address signer = _recoverSigner(digest, voucher.signature);
        if (signer != voucherSigner) revert InvalidVoucherSignature();

        _lazyMintClaimed[voucher.tokenId] = true;
        _safeMint(msg.sender, voucher.tokenId);

        emit LazyMintRedeemed(msg.sender, voucher.tokenId, voucher.price);
    }

    function _recoverSigner(bytes32 digest, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        if (v < 27) v += 27;

        return ecrecover(digest, v, r, s);
    }

    // ========================
    // On-Chain Metadata
    // ========================

    function setTokenMetadata(
        uint256 tokenId,
        string calldata name_,
        string calldata description_,
        string calldata image_,
        string calldata animationUrl_,
        string[] calldata traitTypes_,
        string[] calldata traitValues_
    ) external onlyOwner {
        if (traitTypes_.length != traitValues_.length) revert InvalidMetadata();

        _tokenMetadata[tokenId] = TokenMetadata({
            name: name_,
            description: description_,
            image: image_,
            animationUrl: animationUrl_,
            traitTypes: traitTypes_,
            traitValues: traitValues_
        });

        emit MetadataUpdated(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        TokenMetadata storage meta = _tokenMetadata[tokenId];

        if (bytes(meta.name).length == 0) {
            string memory defaultName = string.concat(name(), " #", tokenId.toString());
            return _buildTokenURI(defaultName, "An NFT from this collection.", "", "", new string[](0), new string[](0));
        }

        return _buildTokenURI(
            meta.name,
            meta.description,
            meta.image,
            meta.animationUrl,
            meta.traitTypes,
            meta.traitValues
        );
    }

    function _buildTokenURI(
        string memory name_,
        string memory description_,
        string memory image_,
        string memory animationUrl_,
        string[] memory traitTypes_,
        string[] memory traitValues_
    ) internal pure returns (string memory) {
        string memory attributes = "[";
        for (uint256 i = 0; i < traitTypes_.length; i++) {
            if (i > 0) attributes = string.concat(attributes, ",");
            attributes = string.concat(
                attributes,
                '{"trait_type":"', traitTypes_[i], '","value":"', traitValues_[i], '"}'
            );
        }
        attributes = string.concat(attributes, "]");

        string memory json = string.concat(
            '{"name":"', name_, '","description":"', description_, '"'
        );

        if (bytes(image_).length > 0) {
            json = string.concat(json, ',"image":"', image_, '"');
        }

        if (bytes(animationUrl_).length > 0) {
            json = string.concat(json, ',"animation_url":"', animationUrl_, '"');
        }

        json = string.concat(json, ',"attributes":', attributes, "}");

        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    // ========================
    // Royalty Distribution (ERC-2981)
    // ========================

    function setRoyaltyRecipients(
        address payable[] calldata wallets,
        uint256[] calldata shares
    ) external onlyOwner {
        if (wallets.length != shares.length) revert InvalidRoyaltyConfig();

        delete royaltyRecipients;
        uint256 total = 0;

        for (uint256 i = 0; i < wallets.length; i++) {
            if (wallets[i] == address(0)) revert ZeroAddress();
            if (shares[i] == 0) revert InvalidRoyaltyConfig();
            total += shares[i];
            royaltyRecipients.push(RoyaltyRecipient({wallet: wallets[i], share: shares[i]}));
        }

        if (total > 10000) revert InvalidRoyaltyConfig();
        totalRoyaltyBps = total;

        emit RoyaltyRecipientsUpdated(total);
    }

    function royaltyInfo(uint256, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        if (royaltyRecipients.length == 0) {
            return (address(0), 0);
        }
        royaltyAmount = (salePrice * totalRoyaltyBps) / 10000;
        receiver = address(this);
    }

    function distributeRoyalties() external nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) return;

        for (uint256 i = 0; i < royaltyRecipients.length; i++) {
            uint256 payment = (balance * royaltyRecipients[i].share) / totalRoyaltyBps;
            (bool success, ) = royaltyRecipients[i].wallet.call{value: payment}("");
            if (!success) revert WithdrawFailed();
        }
    }

    // ========================
    // Admin Functions
    // ========================

    function setMerkleRoot(bytes32 root) external onlyOwner {
        merkleRoot = root;
    }

    function setAllowlistActive(bool active) external onlyOwner {
        allowlistActive = active;
    }

    function setPublicSaleActive(bool active) external onlyOwner {
        publicSaleActive = active;
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
    }

    function setMaxPerWallet(uint256 max) external onlyOwner {
        maxPerWallet = max;
    }

    function setVoucherSigner(address signer) external onlyOwner {
        if (signer == address(0)) revert ZeroAddress();
        voucherSigner = signer;
    }

    function withdraw() external onlyOwner nonReentrant {
        (bool success, ) = owner().call{value: address(this).balance}("");
        if (!success) revert WithdrawFailed();
    }

    // ========================
    // Overrides
    // ========================

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    receive() external payable {}
}