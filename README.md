# AUDB Stablecoin (Australian Dollar Backed)

**AUDB** is a production-grade algorithmic stablecoin pegged to **1 AUD**, deployed on **Avalanche Fuji Testnet**. The protocol combines algorithmic supply management with over-collateralized fallback mechanisms, providing stability and scalability.

---

## 🚀 Live Deployment (Avalanche Fuji Testnet)

### Contract Addresses

| Contract | Address | Explorer |
|----------|---------|----------|
| **AUDB Token** | `0xce1D594f19C31130F09746419131dFECbb3d47bE` | [View on Snowtrace](https://testnet.snowtrace.io/address/0xce1D594f19C31130F09746419131dFECbb3d47bE) |
| **Rebalancer** | `0x68eF016300ae5d7eFa0c42A37FB35d3b0C5C7c97` | [View on Snowtrace](https://testnet.snowtrace.io/address/0x68eF016300ae5d7eFa0c42A37FB35d3b0C5C7c97) |
| **LiquidityManager** | `0xC22577C4630A7169A26413D16d98e2464e71D0AB` | [View on Snowtrace](https://testnet.snowtrace.io/address/0xC22577C4630A7169A26413D16d98e2464e71D0AB) |
| **Vault** | `0xa7BdC6021883CD0Eb265b299A6210c2D4846dd1B` | [View on Snowtrace](https://testnet.snowtrace.io/address/0xa7BdC6021883CD0Eb265b299A6210c2D4846dd1B) |
| **Paymaster** | `0x018876c9d215Fe23161B98BE85dbe3488c9f705B` | [View on Snowtrace](https://testnet.snowtrace.io/address/0x018876c9d215Fe23161B98BE85dbe3488c9f705B) |

**Network:** Avalanche Fuji Testnet  
**Chain ID:** 43113  
**RPC:** `https://api.avax-test.network/ext/bc/C/rpc`

---

## 🏗️ Architecture

### Core Components

1. **AUDB Token (ERC20 + Permit)**
   - Standard ERC20 token with gasless approval support
   - Pausable in case of emergency
   - Ownership controlled by Rebalancer for algorithmic minting/burning

2. **Rebalancer (Algorithmic Stability)**
   - Monitors AUD/USD price feed via **Pyth Network Oracle**
   - Expands supply when price > peg + threshold
   - Contracts supply when price < peg - threshold
   - Integrated with LiquidityManager for DEX operations

3. **LiquidityManager (Protocol-Owned Liquidity)**
   - Manages POL on Trader Joe DEX
   - Adds liquidity during expansion (sell pressure)
   - Removes liquidity during contraction (buy pressure)
   - Deepens market liquidity automatically

4. **Vault (Over-Collateralized Fallback)**
   - Users deposit USDC to mint AUDB
   - Enforces 150% collateralization ratio
   - Provides price floor during algorithmic instability

5. **Paymaster (ERC-4337 Gas Abstraction)**
   - Allows users to pay gas fees in AUDB
   - Simulates exchange rate conversion to AVAX
   - Supports sponsored transactions

---

## 🔗 Key Integrations

- **Oracle:** [Pyth Network](https://pyth.network/) (Live AUD/USD feed)
- **DEX:** [Trader Joe](https://traderjoexyz.com/) (Liquidity Management)
- **Collateral:** USDC on Fuji (`0x5425890298aed601595a70ab815c96711a31bc65`)

---

## 📊 Features

- ✅ **ERC20 Compatibility** - Works with all standard wallets and DEXs
- ✅ **ERC-2612 Permit** - Gasless approvals using signed messages
- ✅ **Hybrid Stability** - Algorithmic + collateral-backed design
- ✅ **Protocol-Owned Liquidity** - Automated market-making
- ✅ **Gas Abstraction** - Pay fees in AUDB (ERC-4337 compatible)
- ✅ **Emergency Pause** - Owner can halt operations if needed

---

## 🛠️ Development

### Prerequisites
```bash
node >= 18.x
npm >= 9.x
```

### Installation
```bash
npm install
```

### Testing
```bash
npx hardhat test
```

### Compilation
```bash
npx hardhat compile
```

---

## 📜 License

MIT

---

## 🔐 Security Considerations

This is a **testnet deployment** for demonstration purposes. Before mainnet deployment:
- Conduct full security audit
- Implement AccessControl for multi-role minting
- Add circuit breakers and rate limits
- Test oracle manipulation scenarios
- Verify all DEX integrations against real liquidity

---

## 📞 Support

For questions or issues, please open a GitHub issue.
