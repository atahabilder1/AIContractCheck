// Source: Etherscan Verified (forge-flattened)
// Address: 0x0000000000e655fae4d56241588680f86e3b2377
// Name: LooksRareProtocol
// Compiler: v0.8.17+commit.8df45f5f

// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

// contracts/enums/CollectionType.sol

/**
 * @notice CollectionType is used in OrderStructs.Maker's collectionType to determine the collection type being traded.
 */
enum CollectionType {
    ERC721,
    ERC1155
}

// contracts/enums/QuoteType.sol

/**
 * @notice QuoteType is used in OrderStructs.Maker's quoteType to determine whether the maker order is a bid or an ask.
 */
enum QuoteType {
    Bid,
    Ask
}

// contracts/libraries/OrderStructs.sol

// Enums

/**
 * @title OrderStructs
 * @notice This library contains all order struct types for the LooksRare protocol (v2).
 * @author LooksRare protocol team (👀,💎)
 */
library OrderStructs {
    /**
     * 1. Maker struct
     */

    /**
     * @notice Maker is the struct for a maker order.
     * @param quoteType Quote type (i.e. 0 = BID, 1 = ASK)
     * @param globalNonce Global user order nonce for maker orders
     * @param subsetNonce Subset nonce (shared across bid/ask maker orders)
     * @param orderNonce Order nonce (it can be shared across bid/ask maker orders)
     * @param strategyId Strategy id
     * @param collectionType Collection type (i.e. 0 = ERC721, 1 = ERC1155)
     * @param collection Collection address
     * @param currency Currency address (@dev address(0) = ETH)
     * @param signer Signer address
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @param price Minimum price for maker ask, maximum price for maker bid
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order
     */
    struct Maker {
        QuoteType quoteType;
        uint256 globalNonce;
        uint256 subsetNonce;
        uint256 orderNonce;
        uint256 strategyId;
        CollectionType collectionType;
        address collection;
        address currency;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * 2. Taker struct
     */

    /**
     * @notice Taker is the struct for a taker ask/bid order. It contains the parameters required for a direct purchase.
     * @dev Taker struct is matched against MakerAsk/MakerBid structs at the protocol level.
     * @param recipient Recipient address (to receive NFTs or non-fungible tokens)
     * @param additionalParameters Extra data specific for the order
     */
    struct Taker {
        address recipient;
        bytes additionalParameters;
    }

    /**
     * 3. Merkle tree struct
     */

    enum MerkleTreeNodePosition { Left, Right }

    /**
     * @notice MerkleTreeNode is a MerkleTree's node.
     * @param value It can be an order hash or a proof
     * @param position The node's position in its branch.
     *                 It can be left or right or none
     *                 (before the tree is sorted).
     */
    struct MerkleTreeNode {
        bytes32 value;
        MerkleTreeNodePosition position;
    }

    /**
     * @notice MerkleTree is the struct for a merkle tree of order hashes.
     * @dev A Merkle tree can be computed with order hashes.
     *      It can contain order hashes from both maker bid and maker ask structs.
     * @param root Merkle root
     * @param proof Array containing the merkle proof
     */
    struct MerkleTree {
        bytes32 root;
        MerkleTreeNode[] proof;
    }

    /**
     * 4. Constants
     */

    /**
     * @notice This is the type hash constant used to compute the maker order hash.
     */
    bytes32 internal constant _MAKER_TYPEHASH =
        keccak256(
            "Maker("
                "uint8 quoteType,"
                "uint256 globalNonce,"
                "uint256 subsetNonce,"
                "uint256 orderNonce,"
                "uint256 strategyId,"
                "uint8 collectionType,"
                "address collection,"
                "address currency,"
                "address signer,"
                "uint256 startTime,"
                "uint256 endTime,"
                "uint256 price,"
                "uint256[] itemIds,"
                "uint256[] amounts,"
                "bytes additionalParameters"
            ")"
        );

    /**
     * 5. Hash functions
     */

    /**
     * @notice This function is used to compute the order hash for a maker struct.
     * @param maker Maker order struct
     * @return makerHash Hash of the maker struct
     */
    function hash(Maker memory maker) internal pure returns (bytes32) {
        // Encoding is done into two parts to avoid stack too deep issues
        return
            keccak256(
                bytes.concat(
                    abi.encode(
                        _MAKER_TYPEHASH,
                        maker.quoteType,
                        maker.globalNonce,
                        maker.subsetNonce,
                        maker.orderNonce,
                        maker.strategyId,
                        maker.collectionType,
                        maker.collection,
                        maker.currency
                    ),
                    abi.encode(
                        maker.signer,
                        maker.startTime,
                        maker.endTime,
                        maker.price,
                        keccak256(abi.encodePacked(maker.itemIds)),
                        keccak256(abi.encodePacked(maker.amounts)),
                        keccak256(maker.additionalParameters)
                    )
                )
            );
    }
}

// contracts/interfaces/ILooksRareProtocol.sol

// Libraries

/**
 * @title ILooksRareProtocol
 * @author LooksRare protocol team (👀,💎)
 */
interface ILooksRareProtocol {
    /**
     * @notice This struct contains an order nonce's invalidation status
     *         and the order hash that triggered the status change.
     * @param orderHash Maker order hash
     * @param orderNonce Order nonce
     * @param isNonceInvalidated Whether this transaction invalidated the maker user's order nonce at the protocol level
     */
    struct NonceInvalidationParameters {
        bytes32 orderHash;
        uint256 orderNonce;
        bool isNonceInvalidated;
    }

    /**
     * @notice It is emitted when there is an affiliate fee paid.
     * @param affiliate Affiliate address
     * @param currency Address of the currency
     * @param affiliateFee Affiliate fee (in the currency)
     */
    event AffiliatePayment(address affiliate, address currency, uint256 affiliateFee);

    /**
     * @notice It is emitted if there is a change in the domain separator.
     */
    event NewDomainSeparator();

    /**
     * @notice It is emitted when there is a new gas limit for a ETH transfer (before it is wrapped to WETH).
     * @param gasLimitETHTransfer Gas limit for an ETH transfer
     */
    event NewGasLimitETHTransfer(uint256 gasLimitETHTransfer);

    /**
     * @notice It is emitted when a taker ask transaction is completed.
     * @param nonceInvalidationParameters Struct about nonce invalidation parameters
     * @param askUser Address of the ask user
     * @param bidUser Address of the bid user
     * @param strategyId Id of the strategy
     * @param currency Address of the currency
     * @param collection Address of the collection
     * @param itemIds Array of item ids
     * @param amounts Array of amounts (for item ids)
     * @param feeRecipients Array of fee recipients
     *        feeRecipients[0] User who receives the proceeds of the sale (it can be the taker ask user or different)
     *        feeRecipients[1] Creator fee recipient (if none, address(0))
     * @param feeAmounts Array of fee amounts
     *        feeAmounts[0] Fee amount for the user receiving sale proceeds
     *        feeAmounts[1] Creator fee amount
     *        feeAmounts[2] Protocol fee amount prior to adjustment for a potential affiliate payment
     */
    event TakerAsk(
        NonceInvalidationParameters nonceInvalidationParameters,
        address askUser, // taker (initiates the transaction)
        address bidUser, // maker (receives the NFT)
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[2] feeRecipients,
        uint256[3] feeAmounts
    );

    /**
     * @notice It is emitted when a taker bid transaction is completed.
     * @param nonceInvalidationParameters Struct about nonce invalidation parameters
     * @param bidUser Address of the bid user
     * @param bidRecipient Address of the recipient of the bid
     * @param strategyId Id of the strategy
     * @param currency Address of the currency
     * @param collection Address of the collection
     * @param itemIds Array of item ids
     * @param amounts Array of amounts (for item ids)
     * @param feeRecipients Array of fee recipients
     *        feeRecipients[0] User who receives the proceeds of the sale (it is the maker ask user)
     *        feeRecipients[1] Creator fee recipient (if none, address(0))
     * @param feeAmounts Array of fee amounts
     *        feeAmounts[0] Fee amount for the user receiving sale proceeds
     *        feeAmounts[1] Creator fee amount
     *        feeAmounts[2] Protocol fee amount prior to adjustment for a potential affiliate payment
     */
    event TakerBid(
        NonceInvalidationParameters nonceInvalidationParameters,
        address bidUser, // taker (initiates the transaction)
        address bidRecipient, // taker (receives the NFT)
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[2] feeRecipients,
        uint256[3] feeAmounts
    );

    /**
     * @notice It is returned if the gas limit for a standard ETH transfer is too low.
     */
    error NewGasLimitETHTransferTooLow();

    /**
     * @notice It is returned if the domain separator cannot be updated (i.e. the chainId is the same).
     */
    error SameDomainSeparator();

    /**
     * @notice It is returned if the domain separator should change.
     */
    error ChainIdInvalid();

    /**
     * @notice It is returned if the nonces are invalid.
     */
    error NoncesInvalid();

    /**
     * @notice This function allows a user to execute a taker ask (against a maker bid).
     * @param takerAsk Taker ask struct
     * @param makerBid Maker bid struct
     * @param makerSignature Maker signature
     * @param merkleTree Merkle tree struct (if the signature contains multiple maker orders)
     * @param affiliate Affiliate address
     */
    function executeTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.Maker calldata makerBid,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external;

    /**
     * @notice This function allows a user to execute a taker bid (against a maker ask).
     * @param takerBid Taker bid struct
     * @param makerAsk Maker ask struct
     * @param makerSignature Maker signature
     * @param merkleTree Merkle tree struct (if the signature contains multiple maker orders)
     * @param affiliate Affiliate address
     */
    function executeTakerBid(
        OrderStructs.Taker calldata takerBid,
        OrderStructs.Maker calldata makerAsk,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external payable;

    /**
     * @notice This function allows a user to batch buy with an array of taker bids (against an array of maker asks).
     * @param takerBids Array of taker bid structs
     * @param makerAsks Array of maker ask structs
     * @param makerSignatures Array of maker signatures
     * @param merkleTrees Array of merkle tree structs if the signature contains multiple maker orders
     * @param affiliate Affiliate address
     * @param isAtomic Whether the execution should be atomic
     *        i.e. whether it should revert if 1 or more transactions fail
     */
    function executeMultipleTakerBids(
        OrderStructs.Taker[] calldata takerBids,
        OrderStructs.Maker[] calldata makerAsks,
        bytes[] calldata makerSignatures,
        OrderStructs.MerkleTree[] calldata merkleTrees,
        address affiliate,
        bool isAtomic
    ) external payable;
}