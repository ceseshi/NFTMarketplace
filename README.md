# NFT Marketplace

A decentralized NFT marketplace smart contract that enables users to create and accept buy/sell offers for NFTs. Built with Solidity and using the UUPS proxy pattern for upgradeability.

A final project for the BlockCoders Solidity course.

## Features

- Create and accept sell offers for NFTs
- Create and accept buy offers for NFTs
- Time-limited offers with deadlines
- Secure ETH and NFT transfers
- Upgradeable contract using UUPS proxy pattern
- NFT recovery mechanism for stuck tokens
- Comprehensive test coverage

## Smart Contracts

- `NFTMarketplace.sol`: The main marketplace contract
- `CoolNFT.sol`: A sample NFT contract for testing purposes

## Technical Details

### Dependencies

- OpenZeppelin Contracts
- OpenZeppelin Contracts Upgradeable
- Foundry for development and testing

### Key Features

#### Sell Offers
- Users can create sell offers by specifying NFT details, price, and deadline
- NFTs are held in escrow by the marketplace until the offer is accepted or cancelled
- Buyers can accept sell offers by sending the required ETH

#### Buy Offers
- Users can create buy offers by sending ETH and specifying NFT details and deadline
- ETH is held in escrow until the offer is accepted or cancelled
- NFT owners can accept buy offers by approving and transferring their NFT

#### Safety Features
- Deadline-based offer expiration
- Owner-only NFT recovery function
- Secure ETH transfers with failure handling
- Access control for critical functions

## Development

### Prerequisites

- [Foundry](https://github.com/foundry-rs/foundry)
- Solidity ^0.8.28

### Installation

1. Clone the repository:

```bash
git clone https://github.com/ceseshi/NFTMarketplace.git
cd NFTMarketplace
```

2. Install dependencies:

```bash
forge install
```

3. Run tests:

```bash
forge test
```

4. Deploy the contract:

```bash
forge script script/NFTMarketplace.s.sol --rpc-url <RPC_URL> --account <KEYSTORE_ACCOUNT> --broadcast
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.