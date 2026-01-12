# AUDB Stablecoin (Avalanche Fuji)

AUDB is a stablecoin pegged to 1 AUD, designed for the Avalanche network. It utilizes a hybrid algorithmic model with protocol-owned liquidity (POL) and partial over-collateralization.

## Architecture

- **AUDB.sol**: The core ERC20 token. Mint/Burn is restricted to the Owner (Rebalancer).
- **Rebalancer.sol**: Manages the peg. Uses **Pyth Network** oracles to check AUD/USD price.
  - If Price > 1.01 AUD: Mints AUDB to expand supply.
  - If Price < 0.99 AUD: Burns AUDB (from reserves) to contract supply.
- **LiquidityManager.sol**: Handles Protocol Owned Liquidity on **Trader Joe**.
- **Paymaster.sol**: ERC-4337 compliant paymaster allowing users to pay gas in AUDB.
- **Governance.sol**: Timelock controller for secure upgrades.

## Deployment Info (Fuji Testnet)

- **Network**: Avalanche Fuji
- **Pyth Oracle**: `0x23f0e8FAeE7bbb405E7A7C3d60138FCfd43d7509`
- **Trader Joe Router**: `0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901`

## Setup

1. Install dependencies:
   ```bash
   npm install
   ```
2. Compile contracts:
   ```bash
   npx hardhat compile
   ```
3. Test:
   ```bash
   npx hardhat test
   ```
4. Deploy:
   ```bash
   npx hardhat run scripts/deploy.js --network fuji
   ```

## Development

- Built with Hardhat & OpenZeppelin.
- Targeted Solidity Version: `0.8.20`.
