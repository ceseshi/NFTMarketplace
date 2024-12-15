// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {NFTMarketplace} from "../src/NFTMarketplace.sol";
import {CoolNFT} from "../src/CoolNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTMarketplaceTest is Test {
    NFTMarketplace public nftMarketplace;
    CoolNFT public coolNFT;

    address owner = makeAddr("owner");
    address seller = makeAddr("seller");
    address buyer = makeAddr("buyer");

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the implementation
        address implementation = address(new NFTMarketplace());

        // Deploy the proxy
        bytes memory initializerData = abi.encodeCall(NFTMarketplace.initialize, ("NFTMarketplace"));
        address proxy = address(new ERC1967Proxy(implementation, initializerData));

        nftMarketplace = NFTMarketplace(payable(proxy));
        coolNFT = new CoolNFT("CoolNFT", "CNFT");

        vm.stopPrank();

        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
    }

    function testMintCoolNFT() public {
        address minter = seller;

        vm.startPrank(minter);
        vm.expectEmit(address(coolNFT));
        emit IERC721.Transfer(address(0), minter, 0);
        uint256 tokenId = coolNFT.mint{value: coolNFT.price()}();

        assertEq(coolNFT.ownerOf(tokenId), minter);
        assertEq(coolNFT.balanceOf(minter), 1);
    }

    function mintAndCreateTestSellOffer(address offerer, uint256 price, uint256 deadline) public returns (uint256) {
        price = bound(price, 0.1 ether, 10 ether);

        vm.startPrank(offerer);
        uint256 tokenId = coolNFT.mint{value: coolNFT.price()}();
        coolNFT.approve(address(nftMarketplace), tokenId);

        uint256 offerId = nftMarketplace.createSellOffer(address(coolNFT), tokenId, price, deadline);

        return offerId;
    }

    function createTestBuyOffer(address offerer, uint256 price, uint256 deadline) public returns (uint256) {
        price = bound(price, 0.1 ether, 10 ether);

        // Create a buy offer
        vm.startPrank(seller);
        uint256 tokenId = coolNFT.mint{value: coolNFT.price()}();
        coolNFT.approve(address(nftMarketplace), tokenId);

        vm.startPrank(offerer);
        uint256 offerId = nftMarketplace.createBuyOffer{value: price}(address(coolNFT), tokenId, price, deadline);

        return offerId;
    }

    function testCreateSellOffer() public {
        uint256 expectedOfferId = nftMarketplace.sellOfferIdCounter();
        uint256 expectedTokenId = 0;
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 days;

        //vm.expectEmit(address(nftMarketplace));
        //emit NFTMarketplace.SellOfferCreated(expectedOfferId, address(coolNFT), expectedTokenId, price, deadline);
        uint256 offerId = mintAndCreateTestSellOffer(seller, price, deadline);

        (
            address nftAddress,
            uint256 offerTokenId,
            address offerOfferer,
            uint256 offerPrice,
            uint248 offerDeadline,
            bool offerIsEnded
        ) = nftMarketplace.sellOffers(offerId);

        assertEq(expectedOfferId, offerId);
        assertEq(nftAddress, address(coolNFT));
        assertEq(offerTokenId, expectedTokenId);
        assertEq(offerOfferer, seller);
        assertEq(offerPrice, price);
        assertEq(offerDeadline, deadline);
        assertFalse(offerIsEnded);
    }

    function testAcceptSellOffer() public {
        // Balances that must match at the end
        uint256 balanceSeller = address(seller).balance;
        uint256 balanceBuyer = address(buyer).balance;

        // Create a sell offer
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        balanceSeller -= price;
        uint256 offerId = mintAndCreateTestSellOffer(seller, price, deadline);

        // Get the offer data
        (, uint256 offerTokenId,, uint256 offerPrice,, bool offerIsEnded) = nftMarketplace.sellOffers(offerId);

        // Accept the sell offer
        vm.startPrank(buyer);
        nftMarketplace.acceptSellOffer{value: offerPrice}(offerId);
        balanceSeller += price;
        balanceBuyer -= price;

        (,,,,, offerIsEnded) = nftMarketplace.sellOffers(offerId);

        // Verify that the sell offer was accepted correctly
        assertTrue(offerIsEnded, "!offerIsEnded");
        assertEq(coolNFT.ownerOf(offerTokenId), buyer, "Incorrect owner");
        assertEq(address(seller).balance, balanceSeller, "Incorrect seller balance");
        assertEq(address(buyer).balance, balanceBuyer, "Incorrect buyer balance");
    }

    function testCreateBuyOffer() public {
        uint256 expectedOfferId = nftMarketplace.buyOfferIdCounter();
        uint256 expectedTokenId = 0;
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 days;

        //vm.expectEmit(address(nftMarketplace));
        //emit NFTMarketplace.BuyOfferCreated(expectedOfferId, address(coolNFT), expectedTokenId, price, deadline);
        uint256 offerId = createTestBuyOffer(buyer, price, deadline);

        (
            address nftAddress,
            uint256 offerTokenId,
            address offerOfferer,
            uint256 offerPrice,
            uint248 offerDeadline,
            bool offerIsEnded
        ) = nftMarketplace.buyOffers(offerId);

        assertEq(expectedOfferId, offerId);
        assertEq(nftAddress, address(coolNFT));
        assertEq(offerTokenId, expectedTokenId);
        assertEq(offerOfferer, buyer);
        assertEq(offerPrice, price);
        assertEq(offerDeadline, deadline);
        assertFalse(offerIsEnded);
    }

    function testAcceptBuyOffer() public {
        // Balances that must match at the end
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256 balanceBuyer = address(buyer).balance;
        uint256 balanceSeller = address(seller).balance;

        // Create a buy offer
        balanceSeller -= price;
        uint256 offerId = createTestBuyOffer(buyer, price, deadline);
        balanceBuyer -= price;

        // Get the offer data
        (, uint256 offerTokenId,,,, bool offerIsEnded) = nftMarketplace.buyOffers(offerId);

        // Accept the buy offer
        vm.startPrank(seller);
        coolNFT.approve(address(nftMarketplace), offerTokenId);
        nftMarketplace.acceptBuyOffer(offerId);
        balanceSeller += price;

        (,,,,, offerIsEnded) = nftMarketplace.buyOffers(offerId);

        // Verify that the buy offer was accepted correctly
        assertTrue(offerIsEnded, "!offerIsEnded");
        assertEq(coolNFT.ownerOf(offerTokenId), buyer, "Incorrect owner");
        assertEq(address(seller).balance, balanceSeller, "Incorrect seller balance");
        assertEq(address(buyer).balance, balanceBuyer, "Incorrect buyer balance");
    }

    function testRecoverNFT() public {
        // Mint an NFT and send it directly to the marketplace
        vm.startPrank(seller);
        uint256 tokenId = coolNFT.mint{value: coolNFT.price()}();
        coolNFT.approve(address(nftMarketplace), tokenId);

        coolNFT.transferFrom(seller, address(nftMarketplace), tokenId);

        // Verify NFT is in marketplace
        assertEq(coolNFT.ownerOf(tokenId), address(nftMarketplace));

        // Recover the NFT
        vm.startPrank(owner);
        nftMarketplace.recoverNFT(address(coolNFT), tokenId, seller);

        // Verify NFT was recovered
        assertEq(coolNFT.ownerOf(tokenId), seller);
    }

    function testCannotRecoverNFTInactiveOffer() public {
        uint256 price = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256 expectedTokenId = 0;
        mintAndCreateTestSellOffer(seller, price, deadline);

        // Try to recover the NFT (should fail)
        vm.startPrank(owner);
        vm.expectRevert(NFTMarketplace.OfferNotEnded.selector);
        nftMarketplace.recoverNFT(address(coolNFT), expectedTokenId, seller);
    }

    function testOnlyOwnerCanRecover() public {
        vm.startPrank(seller);
        uint256 tokenId = coolNFT.mint{value: coolNFT.price()}();
        coolNFT.approve(address(nftMarketplace), tokenId);

        coolNFT.transferFrom(seller, address(nftMarketplace), tokenId);

        // Try to recover as non-owner
        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", buyer));
        nftMarketplace.recoverNFT(address(coolNFT), tokenId, buyer);
    }
}
