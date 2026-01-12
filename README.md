# AUDB Stablecoin (Australian Dollar Backed)

**AUDB** is a production-grade algorithmic stablecoin pegged to **1 AUD**, deployed on **Avalanche Fuji Testnet**. The protocol combines algorithmic supply management with over-collateralized fallback mechanisms, providing stability and scalability through a sophisticated hybrid stability model.

**🔒 Security Status:** Comprehensive internal audit completed. See [SECURITY_AUDIT.md](./SECURITY_AUDIT.md) for full details.

---

## 🚀 Live Deployment (Avalanche Fuji Testnet)

### Contract Addresses

| Contract | Address | Explorer |
|----------|---------|----------|
| **AUDB Token** | `0x2892e8B664F39aF3BaaFECECB2C7Eb6aa38e9d4D` | [View on Snowtrace](https://testnet.snowtrace.io/address/0x2892e8B664F39aF3BaaFECECB2C7Eb6aa38e9d4D) |
| **Rebalancer** | `0xA96f7F8D9037e3Dd90970De9b403d337fC43f913` | [View on Snowtrace](https://testnet.snowtrace.io/address/0xA96f7F8D9037e3Dd90970De9b403d337fC43f913) |
| **LiquidityManager** | `0x0ccDE3e90008479975B94CAE89927C80CA3BcA7f` | [View on Snowtrace](https://testnet.snowtrace.io/address/0x0ccDE3e90008479975B94CAE89927C80CA3BcA7f) |
| **Vault** | `0xfeDFe6528DD88B5f1D58C5B1f6dFa1A45851969a` | [View on Snowtrace](https://testnet.snowtrace.io/address/0xfeDFe6528DD88B5f1D58C5B1f6dFa1A45851969a) |
| **Paymaster** | `0xA39177d9d8245D916042526E1e336D50428fe3b2` | [View on Snowtrace](https://testnet.snowtrace.io/address/0xA39177d9d8245D916042526E1e336D50428fe3b2) |

**Network:** Avalanche Fuji Testnet  
**Chain ID:** 43113  
**RPC:** `https://api.avax-test.network/ext/bc/C/rpc`

**Deployment Date:** January 12, 2026  
**Version:** 2.0 (Security Hardened)

---

## 🏗️ Architecture

### Core Components

#### 1. **AUDB Token (ERC20 + Permit + AccessControl)**
   - Standard ERC20 with gasless approval support (ERC-2612)
   - Role-based access control (MINTER_ROLE, BURNER_ROLE, PAUSER_ROLE)
   - Pausable in case of emergency
   - Maximum supply cap: 1 billion AUDB
   - Maximum mint per transaction: 10 million AUDB

#### 2. **Rebalancer (Algorithmic Stability Engine)**
   - Monitors AUD/USD price feed via **Pyth Network Oracle**
   - Secure oracle integration with:
     - 60-second staleness checks
     - Confidence interval validation (max 1% deviation)
     - Circuit breakers for extreme price movements (>10x deviation)
   - Expands supply when price > peg + threshold (max 10% per hour)
   - Contracts supply when price < peg - threshold (max 10% per hour)
   - Rate limiting: minimum 1 hour between rebalances
   - Integrated with LiquidityManager for DEX operations

#### 3. **LiquidityManager (Protocol-Owned Liquidity)**
   - Manages POL on Trader Joe DEX
   - **Slippage protection:** 1% maximum slippage on all swaps
   - **Deadline protection:** 5-minute deadline on all DEX operations
   - Adds liquidity during expansion (sell pressure)
   - Removes liquidity during contraction (buy pressure)
   - Emergency withdrawal functionality
   - Deepens market liquidity automatically

#### 4. **Vault (Over-Collateralized Fallback)**
   - Users deposit USDC to mint AUDB
   - **Enforces 150% collateralization ratio** (FIXED)
   - Liquidation threshold: 140% CR
   - Liquidation bonus: 5% for liquidators
   - Provides price floor during algorithmic instability
   - Pausable for emergency situations

#### 5. **Paymaster (ERC-4337 Gas Abstraction)**
   - Allows users to pay gas fees in AUDB
   - Simulates exchange rate conversion to AVAX
   - Supports sponsored transactions
   - Simplifies user onboarding

---

## 🔐 Security Features (v2.0)

### ✅ Critical Fixes Implemented

1. **Oracle Security**
   - ✅ Secure price fetching with `getPriceNoOlderThan` (60s max age)
   - ✅ Confidence interval validation (max 1% deviation)
   - ✅ Circuit breaker for extreme price movements (>10x)
   
2. **Slippage Protection**
   - ✅ 1% maximum slippage on all DEX swaps
   - ✅ 5-minute deadline on all DEX operations
   - ✅ Pre-calculated minimum output amounts

3. **Collateral Ratio**
   - ✅ Fixed vault to enforce actual 150% CR (previously 100%)
   - ✅ Liquidation mechanism for underwater positions (<140% CR)
   - ✅ Safe decimal handling (USDC 6 decimals → AUDB 18 decimals)

4. **Access Control**
   - ✅ Role-based permissions (not single owner)
   - ✅ Separate MINTER_ROLE and BURNER_ROLE
   - ✅ Multi-contract authorization without single point of failure

5. **Supply Management**
   - ✅ Maximum total supply: 1 billion AUDB
   - ✅ Maximum mint per transaction: 10 million AUDB
   - ✅ Maximum supply change per rebalance: 10%
   - ✅ Rate limiting: 1-hour minimum between rebalances

6. **Input Validation**
   - ✅ Zero-address checks on all constructors
   - ✅ Non-zero amount validation
   - ✅ Proper parameter validation

7. **Emergency Controls**
   - ✅ Pausable contracts
   - ✅ Emergency liquidity withdrawal
   - ✅ Circuit breakers

### 📋 Audit Results

- **Critical Issues:** 4 found → 4 fixed ✅
- **High Severity:** 7 found → 7 fixed ✅
- **Medium Severity:** 8 found → 8 fixed ✅
- **Low Severity:** 5 found → 5 fixed ✅

**Full audit report:** [SECURITY_AUDIT.md](./SECURITY_AUDIT.md)

---

## 🔗 Key Integrations

- **Oracle:** [Pyth Network](https://pyth.network/) (Live AUD/USD feed)
- **DEX:** [Trader Joe](https://traderjoexyz.com/) (Liquidity Management)
- **Collateral:** USDC on Fuji (`0x5425890298aed601595a70ab815c96711a31bc65`)

---

## 📊 Features

### Core Features
- ✅ **ERC20 Compatibility** - Works with all standard wallets and DEXs
- ✅ **ERC-2612 Permit** - Gasless approvals using signed messages
- ✅ **Hybrid Stability** - Algorithmic + collateral-backed design
- ✅ **Protocol-Owned Liquidity** - Automated market-making
- ✅ **Gas Abstraction** - Pay fees in AUDB (ERC-4337 compatible)

### Security Features (v2.0)
- ✅ **Role-Based Access Control** - Multi-contract permissions
- ✅ **Oracle Security** - Staleness checks + confidence validation
- ✅ **Slippage Protection** - MEV resistance on all swaps
- ✅ **Circuit Breakers** - Automatic pause on extreme volatility
- ✅ **Rate Limiting** - Prevents rapid-fire manipulation
- ✅ **Liquidation System** - Maintains vault solvency
- ✅ **Emergency Pause** - Admin can halt operations if needed
- ✅ **Supply Caps** - Maximum 1B total, 10M per mint

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

### Deployment to Fuji
```bash
npx hardhat run scripts/deploy.js --network fuji
```

---

## 📖 Documentation

- **Whitepaper:** [WHITEPAPER.md](./WHITEPAPER.md) - Comprehensive technical documentation
- **Security Audit:** [SECURITY_AUDIT.md](./SECURITY_AUDIT.md) - Full audit report with findings

---

## 🎯 Roadmap

### ✅ Phase 1: Foundation (Completed)
- [x] Protocol design & architecture
- [x] Smart contract development
- [x] Unit testing
- [x] Fuji testnet deployment
- [x] Internal security audit
- [x] Critical vulnerability fixes

### 🔄 Phase 2: Security & Optimization (In Progress)
- [x] Internal security audit
- [x] Critical fixes implementation
- [ ] External security audit (CertiK, Trail of Bits, or Quantstamp)
- [ ] Bug bounty program launch ($500k pool on Immunefi)
- [ ] Formal verification of critical functions
- [ ] Community bug testing

### Phase 3: Mainnet Launch (Q2 2026)
- [ ] Avalanche C-Chain mainnet deployment
- [ ] Seed liquidity ($500k USDC/AUDB)
- [ ] Aggregator listings (CoinGecko, CoinMarketCap)
- [ ] Official website & documentation portal

### Phase 4: Ecosystem Growth (Q2-Q3 2026)
- [ ] Aave lending market integration
- [ ] Curve stable pool deployment
- [ ] Australian fintech partnerships
- [ ] Regional exchange listings

---

## 📜 License

MIT

---

## 🔐 Security Considerations

### Current Status (v2.0)
This is a **testnet deployment** with significant security improvements:
- ✅ All critical vulnerabilities fixed
- ✅ Role-based access control implemented
- ✅ Oracle manipulation resistant
- ✅ Slippage protection on all swaps
- ✅ Proper collateralization enforcement
- ✅ Circuit breakers and rate limiting

### Before Mainnet Deployment
- [ ] External security audit by reputable firm
- [ ] Bug bounty program ($500k+ pool)
- [ ] Multi-sig governance implementation
- [ ] Emergency response procedures
- [ ] Insurance protocol integration (Nexus Mutual)
- [ ] Formal verification of critical functions

---

## ⚠️ Risk Disclosure

**IMPORTANT:** This protocol is experimental software. Cryptocurrency investments involve significant risk. Do not invest more than you can afford to lose.

**Risks include:**
- Smart contract vulnerabilities
- Oracle manipulation
- Market volatility
- Regulatory uncertainty
- Liquidity crises

**This is a testnet deployment for testing purposes only. Use at your own risk.**

---

## 📞 Support

For questions, issues, or security disclosures:
- **GitHub Issues:** [Open an issue](https://github.com/yourusername/audb/issues)
- **Security:** security@audb.finance (for responsible disclosure)

---

## 🙏 Acknowledgments

Built with:
- [OpenZeppelin](https://openzeppelin.com/) - Security-hardened smart contracts
- [Pyth Network](https://pyth.network/) - High-fidelity oracle data
- [Trader Joe](https://traderjoexyz.com/) - DEX infrastructure
- [Hardhat](https://hardhat.org/) - Development environment

---

**Last Updated:** January 12, 2026  
**Version:** 2.0 (Security Hardened)  
**Status:** ✅ Internal Audit Complete | 🔄 External Audit Pending
