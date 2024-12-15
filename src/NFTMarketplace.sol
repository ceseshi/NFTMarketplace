// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NFTMarketplace is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    struct Offer {
        address nftAddress;
        uint256 tokenId;
        address offerer;
        uint256 price;
        uint248 deadline;
        bool isEnded;
    }

    uint256 public sellOfferIdCounter;
    uint256 public buyOfferIdCounter;
    mapping(uint256 => Offer) public sellOffers;
    mapping(uint256 => Offer) public buyOffers;
    string public marketplaceName;

    /**
     * Events
     */
    event SellOfferCreated(uint256 indexed offerId, address indexed nftAddress, uint256 indexed tokenId, uint256 price, uint256 deadline);
    event SellOfferAccepted(uint256 indexed offerId, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event SellOfferCancelled(uint256 indexed offerId, address indexed nftAddress, uint256 indexed tokenId);
    event BuyOfferCreated(uint256 indexed offerId, address indexed nftAddress, uint256 indexed tokenId, uint256 price, uint256 deadline);
    event BuyOfferAccepted(uint256 indexed offerId, address indexed nftAddress, uint256 indexed tokenId);
    event BuyOfferCancelled(uint256 indexed offerId, address indexed nftAddress, uint256 indexed tokenId);

    /**
     * Errors
     */
    error InvalidSeller();
    error InvalidBuyer();
    error InvalidAmount();
    error InvalidDeadline();
    error InvalidOffer();
    error InvalidPrice();
    error ContractNotApproved();
    error EtherTransferFailed();
    error OfferIsEnded();
    error OfferNotEnded();
    error OfferExpired();
    error NotEnoughEther();

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), "New implementation is the zero address");
    }

    /**
     * Proxy Initialization
     */
    function initialize(string memory _marketplaceName) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        marketplaceName = _marketplaceName;
    }

    /**
     * Creates a sell offer
     * @param nftAddress The address of the NFT contract
     * @param tokenId The ID of the NFT to sell
     * @param price The price of the NFT
     * @param deadline The timestamp of the deadline of the offer
     * @return The ID of the created offer
     */
    function createSellOffer(address nftAddress, uint256 tokenId, uint256 price, uint256 deadline) external returns (uint256) {
        require(deadline > block.timestamp, InvalidDeadline());
        if (price == 0) revert InvalidPrice();

        IERC721 nft = IERC721(nftAddress);

        // Checks
        if (nft.ownerOf(tokenId) != msg.sender) revert InvalidSeller();
        if (nft.getApproved(tokenId) != address(this)) revert ContractNotApproved();

        // Create the offer
        uint256 offerId = sellOfferIdCounter++;
        sellOffers[offerId] = Offer(nftAddress, tokenId, msg.sender, price, uint248(deadline), false);

        // Transfer the NFT to the marketplace
        nft.transferFrom(msg.sender, address(this), tokenId);

        // Events
        emit SellOfferCreated(offerId, nftAddress, tokenId, price, deadline);

        return offerId;
    }

    /**
     * Accepts a sell offer
     * @param offerId The ID of the offer to accept
     */
    function acceptSellOffer(uint256 offerId) external payable {
        Offer storage offer = sellOffers[offerId];

        if (offer.nftAddress == address(0)) revert InvalidOffer();
        if (offer.isEnded) revert OfferIsEnded();
        if (offer.deadline < block.timestamp) revert OfferExpired();
        if (msg.sender == offer.offerer) revert InvalidBuyer();
        if (msg.value != offer.price) revert InvalidAmount();

        offer.isEnded = true;

        IERC721(offer.nftAddress).transferFrom(address(this), msg.sender, offer.tokenId);

        (bool success,) = offer.offerer.call{value: offer.price}("");
        if (!success) revert EtherTransferFailed();

        emit SellOfferAccepted(offerId, offer.nftAddress, offer.tokenId, offer.price);
    }

    /**
     * Cancels a sell offer
     * @param offerId The ID of the offer to cancel
     */
    function cancelSellOffer(uint256 offerId) external {
        Offer storage offer = sellOffers[offerId];

        if (offer.nftAddress == address(0)) revert InvalidOffer();
        if (offer.isEnded) revert OfferIsEnded();
        if (offer.deadline > block.timestamp) revert OfferNotEnded();
        if (offer.offerer != msg.sender) revert InvalidSeller();

        offer.isEnded = true;

        emit SellOfferCancelled(offerId, offer.nftAddress, offer.tokenId);
    }

    /**
     * Creates a buy offer
     * @param nftAddress The address of the NFT contract
     * @param tokenId The ID of the NFT to buy
     * @param price The price of the NFT
     * @param deadline The timestamp of the deadline of the offer
     * @return The ID of the created offer
     */
    function createBuyOffer(address nftAddress, uint256 tokenId, uint256 price, uint256 deadline)
        external
        payable
        returns (uint256)
    {
        if (deadline <= block.timestamp) revert InvalidDeadline();
        if (price != msg.value || price == 0) revert InvalidPrice();

        IERC721 nft = IERC721(nftAddress);
        if (nft.ownerOf(tokenId) == msg.sender) revert InvalidBuyer();

        uint256 offerId = buyOfferIdCounter++;
        buyOffers[offerId] = Offer(nftAddress, tokenId, msg.sender, uint256(msg.value), uint248(deadline), false);

        emit BuyOfferCreated(offerId, nftAddress, tokenId, price, deadline);

        return offerId;
    }

    /**
     * Accepts a buy offer
     * @param offerId The ID of the offer to accept
     */
    function acceptBuyOffer(uint256 offerId) external {
        Offer storage offer = buyOffers[offerId];

        if (offer.nftAddress == address(0)) revert InvalidOffer();
        if (offer.isEnded) revert OfferIsEnded();
        if (offer.deadline < block.timestamp) revert OfferExpired();
        if (msg.sender == offer.offerer) revert InvalidSeller();

        offer.isEnded = true;

        emit BuyOfferAccepted(offerId, offer.nftAddress, offer.tokenId);

        IERC721(offer.nftAddress).transferFrom(msg.sender, offer.offerer, offer.tokenId);
        (bool success,) = msg.sender.call{value: offer.price}("");
        if (!success) revert EtherTransferFailed();
    }

    /**
     * Cancels a buy offer
     * @param offerId The ID of the offer to cancel
     */
    function cancelBuyOffer(uint256 offerId) external {
        Offer storage offer = buyOffers[offerId];

        if (offer.nftAddress == address(0)) revert InvalidOffer();
        if (offer.isEnded) revert OfferIsEnded();
        if (offer.deadline > block.timestamp) revert OfferNotEnded();
        if (offer.offerer != msg.sender) revert InvalidBuyer();

        offer.isEnded = true;

        emit BuyOfferCancelled(offerId, offer.nftAddress, offer.tokenId);

        (bool success,) = offer.offerer.call{value: offer.price}("");
        if (!success) revert EtherTransferFailed();
    }

    /**
     * Recovers a stuck NFT from the contract
     * @param nftAddress The address of the NFT contract
     * @param tokenId The ID of the NFT to recover
     * @param to The address to send the NFT to
     */
    function recoverNFT(address nftAddress, uint256 tokenId, address to) external onlyOwner {
        // Verify the NFT is not part of an active offer
        for (uint256 i = 0; i < sellOfferIdCounter; i++) {
            Offer storage offer = sellOffers[i];

            if (offer.nftAddress == nftAddress && offer.tokenId == tokenId && !offer.isEnded && offer.deadline > block.timestamp) {
                revert OfferNotEnded();
            }
        }

        // Return the NFT
        IERC721(nftAddress).transferFrom(address(this), to, tokenId);
    }

    /**
     * Recovers funds from the contract
     */
    function recoverFunds() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * Handles ETH received
     */
    receive() external payable {}
}
