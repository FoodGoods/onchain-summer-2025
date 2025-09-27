// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

/**
 * @title AdvancedNFTMarketplace
 * @dev Advanced NFT marketplace with auctions, royalties, and cross-collection trading
 * @notice Implements ERC-721, auction mechanisms, creator royalties, and batch operations
 */
contract AdvancedNFTMarketplace {
    // Events
    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price, uint256 timestamp);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event AuctionCreated(uint256 indexed tokenId, uint256 startPrice, uint256 endTime);
    event BidPlaced(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address indexed winner, uint256 winningBid);
    event RoyaltyPaid(address indexed creator, uint256 indexed tokenId, uint256 amount);
    event CollectionRegistered(address indexed collection, address indexed creator, uint256 royaltyRate);

    // Structs
    struct NFTListing {
        address seller;
        uint256 price;
        bool isActive;
        uint256 timestamp;
        address collection;
    }

    struct Auction {
        address seller;
        uint256 startPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool isActive;
        address collection;
    }

    struct Collection {
        address creator;
        uint256 royaltyRate; // In basis points (e.g., 250 = 2.5%)
        bool isRegistered;
        string name;
        string symbol;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    // State variables
    mapping(uint256 => NFTListing) public listings;
    mapping(uint256 => Auction) public auctions;
    mapping(address => Collection) public collections;
    mapping(uint256 => mapping(address => Bid)) public bids;
    mapping(address => uint256) public pendingWithdrawals;
    
    uint256 public constant AUCTION_DURATION = 7 days;
    uint256 public constant MIN_BID_INCREASE = 5; // 5% minimum bid increase
    uint256 public constant PLATFORM_FEE_RATE = 250; // 2.5% platform fee
    uint256 public constant MAX_ROYALTY_RATE = 1000; // 10% max royalty
    
    address public owner;
    uint256 public totalVolume;
    uint256 public totalFees;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyNFTOwner(uint256 tokenId, address collection) {
        require(_isNFTOwner(tokenId, collection, msg.sender), "Not NFT owner");
        _;
    }

    modifier validCollection(address collection) {
        require(collections[collection].isRegistered, "Collection not registered");
        _;
    }

    modifier auctionActive(uint256 tokenId) {
        require(auctions[tokenId].isActive, "Auction not active");
        require(block.timestamp < auctions[tokenId].endTime, "Auction ended");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Collection Management
    function registerCollection(
        address collection,
        address creator,
        uint256 royaltyRate,
        string memory name,
        string memory symbol
    ) external onlyOwner {
        require(royaltyRate <= MAX_ROYALTY_RATE, "Royalty rate too high");
        require(!collections[collection].isRegistered, "Collection already registered");
        
        collections[collection] = Collection({
            creator: creator,
            royaltyRate: royaltyRate,
            isRegistered: true,
            name: name,
            symbol: symbol
        });

        emit CollectionRegistered(collection, creator, royaltyRate);
    }

    // NFT Listing Functions
    function listNFT(
        uint256 tokenId,
        address collection,
        uint256 price
    ) external validCollection(collection) onlyNFTOwner(tokenId, collection) {
        require(price > 0, "Price must be positive");
        require(!listings[tokenId].isActive, "Already listed");
        require(!auctions[tokenId].isActive, "NFT in auction");

        listings[tokenId] = NFTListing({
            seller: msg.sender,
            price: price,
            isActive: true,
            timestamp: block.timestamp,
            collection: collection
        });

        emit NFTListed(tokenId, msg.sender, price, block.timestamp);
    }

    function buyNFT(uint256 tokenId) external payable {
        NFTListing storage listing = listings[tokenId];
        require(listing.isActive, "NFT not for sale");
        require(msg.value >= listing.price, "Insufficient payment");

        address seller = listing.seller;
        address collection = listing.collection;
        
        // Deactivate listing
        listing.isActive = false;

        // Transfer NFT (simplified - in real implementation, use actual NFT contract)
        _transferNFT(tokenId, collection, seller, msg.sender);

        // Calculate fees and royalties
        uint256 platformFee = (listing.price * PLATFORM_FEE_RATE) / 10000;
        uint256 royaltyAmount = _calculateRoyalty(tokenId, collection, listing.price);
        uint256 sellerAmount = listing.price - platformFee - royaltyAmount;

        // Distribute payments
        pendingWithdrawals[seller] += sellerAmount;
        pendingWithdrawals[owner] += platformFee;
        
        if (royaltyAmount > 0) {
            address creator = collections[collection].creator;
            pendingWithdrawals[creator] += royaltyAmount;
            emit RoyaltyPaid(creator, tokenId, royaltyAmount);
        }

        // Update stats
        totalVolume += listing.price;
        totalFees += platformFee;

        emit NFTSold(tokenId, seller, msg.sender, listing.price);
    }

    function cancelListing(uint256 tokenId) external {
        NFTListing storage listing = listings[tokenId];
        require(listing.isActive, "No active listing");
        require(listing.seller == msg.sender, "Not the seller");

        listing.isActive = false;
    }

    // Auction Functions
    function createAuction(
        uint256 tokenId,
        address collection,
        uint256 startPrice
    ) external validCollection(collection) onlyNFTOwner(tokenId, collection) {
        require(startPrice > 0, "Start price must be positive");
        require(!listings[tokenId].isActive, "NFT currently listed");
        require(!auctions[tokenId].isActive, "Auction already exists");

        auctions[tokenId] = Auction({
            seller: msg.sender,
            startPrice: startPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + AUCTION_DURATION,
            isActive: true,
            collection: collection
        });

        emit AuctionCreated(tokenId, startPrice, block.timestamp + AUCTION_DURATION);
    }

    function placeBid(uint256 tokenId) external payable auctionActive(tokenId) {
        Auction storage auction = auctions[tokenId];
        require(msg.sender != auction.seller, "Seller cannot bid");
        
        uint256 minBid = auction.highestBid == 0 
            ? auction.startPrice 
            : auction.highestBid + (auction.highestBid * MIN_BID_INCREASE / 100);
        
        require(msg.value >= minBid, "Bid too low");

        // Refund previous highest bidder
        if (auction.highestBidder != address(0)) {
            pendingWithdrawals[auction.highestBidder] += auction.highestBid;
        }

        // Update auction
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        // Record bid
        bids[tokenId][msg.sender] = Bid({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        });

        emit BidPlaced(tokenId, msg.sender, msg.value);
    }

    function endAuction(uint256 tokenId) external {
        Auction storage auction = auctions[tokenId];
        require(auction.isActive, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction not ended");
        require(
            msg.sender == auction.seller || 
            msg.sender == auction.highestBidder || 
            msg.sender == owner,
            "Not authorized"
        );

        auction.isActive = false;

        if (auction.highestBidder != address(0)) {
            // Transfer NFT to winner
            _transferNFT(tokenId, auction.collection, auction.seller, auction.highestBidder);

            // Calculate fees and royalties
            uint256 platformFee = (auction.highestBid * PLATFORM_FEE_RATE) / 10000;
            uint256 royaltyAmount = _calculateRoyalty(tokenId, auction.collection, auction.highestBid);
            uint256 sellerAmount = auction.highestBid - platformFee - royaltyAmount;

            // Distribute payments
            pendingWithdrawals[auction.seller] += sellerAmount;
            pendingWithdrawals[owner] += platformFee;
            
            if (royaltyAmount > 0) {
                address creator = collections[auction.collection].creator;
                pendingWithdrawals[creator] += royaltyAmount;
                emit RoyaltyPaid(creator, tokenId, royaltyAmount);
            }

            // Update stats
            totalVolume += auction.highestBid;
            totalFees += platformFee;

            emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid);
        }
    }

    // Batch Operations
    function batchListNFTs(
        uint256[] memory tokenIds,
        address[] memory collectionAddresses,
        uint256[] memory prices
    ) external {
        require(
            tokenIds.length == collectionAddresses.length && 
            collectionAddresses.length == prices.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _listNFT(tokenIds[i], collectionAddresses[i], prices[i]);
        }
    }

    function batchBuyNFTs(uint256[] memory tokenIds) external payable {
        uint256 totalCost = 0;
        
        // Calculate total cost
        for (uint256 i = 0; i < tokenIds.length; i++) {
            NFTListing storage listing = listings[tokenIds[i]];
            require(listing.isActive, "NFT not for sale");
            totalCost += listing.price;
        }

        require(msg.value >= totalCost, "Insufficient payment");

        // Execute purchases
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _executePurchase(tokenIds[i]);
        }
    }

    // Withdrawal Functions
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    // Internal Functions
    function _listNFT(
        uint256 tokenId,
        address collection,
        uint256 price
    ) internal validCollection(collection) onlyNFTOwner(tokenId, collection) {
        require(price > 0, "Price must be positive");
        require(!listings[tokenId].isActive, "Already listed");
        require(!auctions[tokenId].isActive, "NFT in auction");

        listings[tokenId] = NFTListing({
            seller: msg.sender,
            price: price,
            isActive: true,
            timestamp: block.timestamp,
            collection: collection
        });

        emit NFTListed(tokenId, msg.sender, price, block.timestamp);
    }

    function _executePurchase(uint256 tokenId) internal {
        NFTListing storage listing = listings[tokenId];
        require(listing.isActive, "NFT not for sale");

        address seller = listing.seller;
        address collection = listing.collection;
        
        // Deactivate listing
        listing.isActive = false;

        // Transfer NFT (simplified - in real implementation, use actual NFT contract)
        _transferNFT(tokenId, collection, seller, msg.sender);

        // Calculate fees and royalties
        uint256 platformFee = (listing.price * PLATFORM_FEE_RATE) / 10000;
        uint256 royaltyAmount = _calculateRoyalty(tokenId, collection, listing.price);
        uint256 sellerAmount = listing.price - platformFee - royaltyAmount;

        // Distribute payments
        pendingWithdrawals[seller] += sellerAmount;
        pendingWithdrawals[owner] += platformFee;
        
        if (royaltyAmount > 0) {
            address creator = collections[collection].creator;
            pendingWithdrawals[creator] += royaltyAmount;
            emit RoyaltyPaid(creator, tokenId, royaltyAmount);
        }

        // Update stats
        totalVolume += listing.price;
        totalFees += platformFee;

        emit NFTSold(tokenId, seller, msg.sender, listing.price);
    }

    function _isNFTOwner(uint256 tokenId, address collection, address account) internal pure returns (bool) {
        // Simplified - in real implementation, check actual NFT contract
        return true; // Placeholder
    }

    function _transferNFT(uint256 tokenId, address collection, address from, address to) internal {
        // Simplified - in real implementation, call actual NFT transfer function
        console.log("Transferring NFT %s from %s to %s", tokenId, from, to);
    }

    function _calculateRoyalty(uint256 tokenId, address collection, uint256 salePrice) internal view returns (uint256) {
        Collection memory collectionInfo = collections[collection];
        return (salePrice * collectionInfo.royaltyRate) / 10000;
    }

    // View Functions
    function getListing(uint256 tokenId) external view returns (NFTListing memory) {
        return listings[tokenId];
    }

    function getAuction(uint256 tokenId) external view returns (Auction memory) {
        return auctions[tokenId];
    }

    function getCollection(address collection) external view returns (Collection memory) {
        return collections[collection];
    }

    function getBid(uint256 tokenId, address bidder) external view returns (Bid memory) {
        return bids[tokenId][bidder];
    }

    function getPendingWithdrawal(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    function getMarketStats() external view returns (uint256, uint256) {
        return (totalVolume, totalFees);
    }

    // Emergency Functions
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function updatePlatformFee(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee rate too high"); // Max 10%
        // In real implementation, update PLATFORM_FEE_RATE
    }
}
