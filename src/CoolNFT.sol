// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoolNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    uint256 public price = 1 ether;

    error InvalidEther();

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    function mint() public payable returns (uint256) {
        if (msg.value != price) {
            revert InvalidEther();
        }

        _safeMint(msg.sender, _tokenIdCounter);

        return _tokenIdCounter++;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.example.com/nft/";
    }

    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
