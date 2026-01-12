# Whitepaper: AUDB (Australian Dollar Backed Protocol)

**Version 1.0**  
**Date:** January 2026  
**Status:** Live on Avalanche Fuji Testnet

---

## Abstract

The **AUDB (Australian Dollar Backed)** protocol introduces a next-generation decentralized stablecoin pegged to the Australian Dollar (AUD). Built on the high-performance **Avalanche** network, AUDB employs a novel **Hybrid Stability Mechanism** that combines algorithmic supply adjustments with a partial over-collateralized fallback system. This approaches solves the "Stablecoin Trilemma" by balancing **scalability** (via algorithmic expansion), **stability** (via collateral vaults), and **capital efficiency**. Furthermore, AUDB pioneers the adoption of **ERC-4337 Account Abstraction**, enabling users to transact without native gas tokens, radically simplifying the user experience for mass adoption.

---

## 1. Introduction

### 1.1 The Market Gap
While the US Dollar dominates the stablecoin market (USDT, USDC, DAI), the Australian Dollar—the 5th most traded currency globally—lacks a robust, decentralized, and scalable on-chain representation. Current options are either centralized (custodial risk) or fragmented.

### 1.2 The AUDB Vision
AUDB aims to become the premier DeFi-native representative of the Australian Dollar. It is designed not just as a store of value, but as a transaction layer for the future digital economy, enabling seamless payments, remittances, and robust DeFi yields for AUD holders.

---

## 2. Core Architecture

AUDB distinguishes itself through a modular architecture composed of four sovereign but interconnected systems.

### 2.1 HybridPeg™ Stability Mechanism
Unlike purely algorithmic coins (prone to "death spirals") or purely over-collateralized coins (capital inefficient), AUDB uses a dynamic hybrid model:

1.  **Algorithmic Rebalancer (The Growth Engine):**
    *   Utilizes the **Pyth Network Oracle** for real-time, high-fidelity AUD/USD price feeds.
    *   **Expansion:** When `Price > $1.01 AUD`, the protocol mints new AUDB. This supply is sold into the market to lower the price to peg, while simultaneously deepening protocol-owned liquidity (POL).
    *   **Contraction:** When `Price < $0.99 AUD`, the protocol buys back AUDB using its reserves and burns it, reducing supply to restore the peg.

2.  **The Vault (The Safety Net):**
    *   A decentralized "Central Bank" fallback.
    *   Users can mint AUDB by depositing **USDC** collateral at a strictly enforced **150% Collateralization Ratio**.
    *   This ensures that even in extreme volatility, there is always a hard price floor backed by real decentralized assets.

### 2.2 Protocol Owned Liquidity (POL)
The **Liquidity Manager** contract acts as an automated market maker. Instead of renting liquidity via incentives, the protocol owns its liquidity on **Trader Joe**.
*   **Revenue Generation:** Trading fees from the liquidity pool accrue to the protocol, not external LPs.
*   **Deep Depth:** As the protocol expands, it automatically adds to the LP side, creating an ever-deepening moat of liquidity that makes it harder to de-peg.

---

## 3. User Experience & Innovation

### 3.1 Gas Abstraction (ERC-4337)
One of the biggest friction points in crypto is the need to hold a native chain token (AVAX) to send a stablecoin. AUDB eliminates this via its custom **Paymaster** contract.
*   **Pay in AUDB:** Users can pay for transaction network fees using AUDB itself.
*   **Seamless Onboarding:** A user with 0 AVAX but 100 AUDB can still transact freely.

### 3.2 Gasless Approvals (ERC-2612)
AUDB implements the **Permit** standard, allowing users to approve spending via off-chain signatures. This removes the annoying "Approve" transaction step, saving time and gas.

---

## 4. Technical Specifications

| Component | Specification |
|:---|:---|
| **Network** | Avalanche C-Chain (Fuji Testnet / Mainnet Ready) |
| **Token Standard** | ERC-20 + ERC-2612 (Permit) + ERC-4337 Support |
| **Oracle Provider** | Pyth Network (Low latency, confidence intervals) |
| **DEX Integration** | Trader Joe (JoeRouter02) |
| **Contract Security** | OpenZeppelin Hardened (Ownable, Pausable, ReentrancyGuard) |

---

## 5. Tokenomics

*   **Ticker:** AUDB
*   **Decimals:** 18
*   **Initial Supply:** Elastic (Minted against demand)
*   **Hard Cap:** None (Algorithmic)
*   **Fees:**
    *   Vault Minting Fee: 0% (Incentivized)
    *   Redemption Fee: 0.5% (Prevents spam arbitrage)

---

## 6. Roadmap

### Phase 1: Inception (Completed)
- [x] Smart Contract Development (Solidity 0.8.20)
- [x] Unit Testing & Integration Testing
- [x] Deployment to Avalanche Fuji Testnet
- [x] Oracle Integration (Pyth)

### Phase 2: Security & Optimization (Q1 2026)
- [ ] External Security Audit
- [ ] Integration with Fireblocks/OpenBlocks for Institutional Access
- [ ] Bug Bounty Program

### Phase 3: Mainnet Launch (Q2 2026)
- [ ] Launch on Avalanche Mainnet
- [ ] Seed Liquidity on Trader Joe
- [ ] Partnership with Australian Fintechs

---

## 7. Conclusion

AUDB represents a mature evolution in stablecoin design. By learning from the failures of predecessors and leveraging the speed of Avalanche, it offers a robust, user-friendly, and capital-efficient currency for the Australian market. It is not just a token; it is a monetary network designed for the next billion users.

---

*Disclaimer: This whitepaper is for informational purposes only. AUDB is currently in a testnet environment. Cryptocurrency investments rely on emerging technologies and involve risk.*
