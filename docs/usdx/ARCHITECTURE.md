# USDX System Architecture

## 1. Executive Summary & Purpose

USDX is a proposed fiat-backed stablecoin designed to operate on the TRON blockchain (TRC-20 standard). The primary financial objective of USDX is to maintain a 1:1 backing by eligible fiat reserves held in segregated, audited custodian bank accounts.

**Phase 0 Status Notice:** This document defines the baseline architecture, financial invariants, trust boundaries, and component lifecycles for USDX. This phase is strictly an architecture and technical validation phase. No production smart contracts, backend services, or infrastructure are implemented in Phase 0.

---

## 2. Core Financial Invariants

The protocol architecture mandates strict compliance with core financial invariants. System state transitions must enforce or preserve these invariants at all times:

1. **Solvency Invariant:** `totalSupply <= eligibleReserves`
   - The total circulating supply of USDX tokens on-chain must never exceed the total verified, eligible fiat reserves held by authorized custodians.
2. **Controlled Minting Invariant:**
   - Minting must not occur without satisfying the active reserve attestation policy, explicit operational authorization, and strict rate/allowance limits.
3. **Redemption Parity Invariant:**
   - Redemption must irrevocably burn the corresponding USDX token amount on-chain prior to or atomically upon fiat disbursement from reserve custody.
4. **Backend Non-Authority Invariant:**
   - A compromise of off-chain backend infrastructure or API servers must not grant unrestricted token creation authority. Minting requires multi-party authorization and on-chain verification constraints.
5. **Fail-Closed Reserve Invariant:**
   - Invalid, stale, unavailable, zero, or contradictory reserve attestation data must force the minting mechanism into a fail-closed state (pausing new token creation).
6. **Authority Separation Invariant:**
   - Administrative and governance authority (contract upgrades, role assignment, pause overrides) must be strictly isolated from operational minting/burning issuance roles.

---

## 3. On-Chain vs. Off-Chain Architecture

```
+-----------------------------------------------------------------------------------+
|                               OFF-CHAIN DOMAIN                                     |
+-----------------------------------------------------------------------------------+
|  +------------------+     +--------------------+     +------------------------+   |
|  | Bank / Custodian | <-> | Compliance System  | <-> | USDX Core Backend Service|   |
|  | (Fiat Reserves)  |     | (KYC / AML / Sanct)|     | (Order Orchestration)  |   |
|  +------------------+     +--------------------+     +------------------------+   |
|           ^                                                       |               |
|           | Attestation Feed                                      | Signed Intent |
|           v                                                       v               |
|  +----------------------------------------------------------------------------+   |
|  |                       Reserve Attestation / Oracle                         |   |
|  +----------------------------------------------------------------------------+   |
+-----------------------------------------------------------------------------------+
                                        |
                            Push / Attest On-Chain Data
                                        v
+-----------------------------------------------------------------------------------+
|                                ON-CHAIN DOMAIN                                    |
+-----------------------------------------------------------------------------------+
|  +----------------------------------------------------------------------------+   |
|  |                      Reserve Data Contract / Oracle Engine                 |   |
|  +----------------------------------------------------------------------------+   |
|                                       | Solvency Check                            |
|                                       v                                           |
|  +----------------------------------------------------------------------------+   |
|  |                           USDX Core TRC-20 Contract                        |   |
|  |  - 6 Decimals                                                              |   |
|  |  - Mint / Burn Access Control                                            |   |
|  |  - Emergency Pause Circuit Breaker                                         |   |
|  |  - Sanctions / Blacklist Enforcement                                       |   |
|  +----------------------------------------------------------------------------+   |
|             ^                                                     ^               |
|             | Mint / Burn Requests                                | Liquidity     |
|             v                                                     v               |
|  +--------------------+                             +-------------------------+   |
|  | Authorized Minter/ |                             |   Secondary Market /    |   |
|  | Redeemer Operations|                             |   SunSwap Liquidity     |   |
|  +--------------------+                             +-------------------------+   |
+-----------------------------------------------------------------------------------+
```

---

## 4. System Components & Responsibilities

### 4.1 On-Chain Components (Smart Contracts)
- **USDX TRC-20 Token Contract:** Implements core TRC-20 token interface (transfer, approve, transferFrom, totalSupply, balanceOf) with 6 decimal places. Incorporates permissioned `mint` and `burn` functions, `pause` controls, and compliance features (e.g., blacklisting/sanction freezing).
- **Reserve Oracle / Attestation Verifier:** Stores verified off-chain reserve balances on-chain. Validates signature attestations from qualified independent auditors or oracle networks (e.g., Chainlink Proof of Reserve). Enforces maximum age / heartbeat timeouts.
- **Access Control & Timelock Governance:** Multi-signature governance module linked to a mandatory execution timelock for administrative role assignment, parameter adjustments, or contract upgrades.

### 4.2 Off-Chain Components
- **USDX Core Backend / Orchestrator:** Handles user onboarding, wire transfer matching, order state machines, and cryptographic signing of mint/burn payloads.
- **Reserve Attestation Feed Service:** Collects bank balance data via API or audited reports, signs attestation payloads, and relays them to the on-chain Reserve Data Contract.
- **Compliance & AML Engine:** Performs real-time wallet screening (OFAC/sanctions lists), transaction monitoring, and KYC validation prior to approving mint/redemption requests.
- **Banking & Custodian Infrastructure:** Regulated financial institutions holding cash, cash equivalents (e.g., short-term US Treasury bills), and overnight deposits securing the USDX circulating supply.

---

## 5. Trust Boundaries

```
[ Bank / Custodian ] <--- Custodial Trust ---> [ Fiat Reserve Operations ]
         |                                                 |
  API / Statement                                   Compliance Screening
         v                                                 v
[ Attester / Oracle ] <--- Cryptographic Sign ---> [ Backend Operations ]
         |                                                 |
   On-Chain Push                                     Signed Transaction
         v                                                 v
======================= HARD ON-CHAIN TRUST BOUNDARY =======================
         |                                                 |
         +------------------------> [ USDX Token Contract ] <-------+
```

1. **Off-Chain to On-Chain Boundary:** On-chain contracts do not trust off-chain backend services to dictate arbitrary minting. All mint requests must pass on-chain parameter validation, solvency checks (`totalSupply + amount <= eligibleReserves`), and role-based checks.
2. **Operational vs. Administrative Boundary:** Operational minters operate under daily mint caps and explicit reserve limits. Administrative entities (governance multisig) cannot directly mint tokens without adhering to role restrictions and timelocks.
3. **User / Secondary Market Boundary:** Secondary market users interact via standard TRC-20 methods (`transfer`, `approve`). Standard transfers do not require backend intervention, but are subject to global contract pause state and address sanctions checks.

---

## 6. System Lifecycles

### 6.1 Mint Lifecycle
1. **Fiat Deposit:** Verified user wires USD fiat to designated custodian reserve bank account.
2. **Off-Chain Reconciliation:** Bank notifies USDX backend; backend matches deposit to user KYC record.
3. **Compliance Check:** Compliance engine verifies sender identity and target TRON wallet against sanction lists.
4. **Reserve Attestation Verification:** Oracle/attestation service updates on-chain `eligibleReserves` balance.
5. **Mint Request:** Authorized minter role calls on-chain `mint(recipient, amount)`.
6. **On-Chain Solvency Validation:** Contract asserts `totalSupply + amount <= eligibleReserves` and check contract is `notPaused`.
7. **Token Issuance:** `totalSupply` increases, tokens minted to `recipient` wallet, `Mint` event emitted.

### 6.2 Redemption Lifecycle
1. **Redemption Request:** Verified user submits redemption order off-chain and approves token transfer or deposits USDX to protocol redemption bridge contract.
2. **On-Chain Burning:** Authorized redeemer role invokes `burn(account, amount)` or user invokes `burn(amount)`.
3. **Token Destruction:** `totalSupply` decreases, tokens burned from balance, `Burn` event emitted.
4. **Fiat Disbursement:** Backend verifies on-chain burn transaction confirmation, then instructs custodian bank to execute fiat wire transfer to user's registered bank account.

### 6.3 Reserve Attestation Lifecycle
1. **Data Ingestion:** Independent attester or oracle node queries custodian bank balances.
2. **Payload Cryptographic Signing:** Attester signs payload containing `(eligibleReserves, timestamp, nonce)`.
3. **On-Chain Relay:** Payload submitted to Reserve Verifier Contract.
4. **Validation:** Verifier checks signature against authorized attester key, verifies `timestamp` is fresh, and updates `eligibleReserves`.
5. **Stale Data Handling:** If current time exceeds `lastAttestationTimestamp + HEARTBEAT_PERIOD`, the reserve status is marked `STALE`, disabling new mint operations.

### 6.4 Emergency & Fail-Closed Behavior
- **Stale/Invalid Reserves:** If reserve attestation is stale, missing, or contradictory (`eligibleReserves < totalSupply`), minting fails closed automatically.
- **Pause Circuit Breaker:** An `EmergencyController` role can instantly pause token transfers, minting, and burning in case of detected exploits, regulatory freeze mandates, or key compromises.
- **Unpause Requirement:** Unpausing requires Governance Multisig approval after a mandatory delay/review period.

---

## 7. Governance and Authority Separation

To prevent single points of failure and administrative abuse, protocol roles are strictly separated:

| Role Name | Authority Scope | Key Requirement |
| :--- | :--- | :--- |
| **Governance Multisig** | Upgrades, role administration, timelock changes | 3-of-5 Hardware Multisig + 48h Timelock |
| **Emergency Controller** | Trigger pause, freeze specific sanctioned accounts | 2-of-3 Fast-Response Multisig |
| **Operational Minter** | Call `mint()` within reserve and daily cap limits | Automated KMS / HSM Key with daily velocity limits |
| **Operational Redeemer** | Call `burn()` to process confirmed redemptions | Automated KMS / HSM Key |
| **Reserve Attester** | Submit `updateReserves()` attestation data | Independent Oracle / Auditor Threshold Key |

---

## 8. External Dependencies & Integration Boundaries

1. **TRON Virtual Machine (TVM):** Requires target compatibility with Solidity versions and EVM bytecode standards supported by TRON (e.g., max EVM version `london` to avoid `PUSH0`).
2. **Oracle Infrastructure:** Chainlink Proof of Reserve (PoR) or multi-attester cryptographic signature verifier.
3. **Custodian Banks:** APIs and statement feeds providing balance visibility for reserve verification.
4. **Compliance Screening Providers:** API integration for automated OFAC/sanctions screening (e.g., Chainalysis, Elliptic, TRM Labs).
5. **DEX Liquidity Pools (SunSwap):** Future secondary market trading integration. Secondary pools operate strictly external to core token logic.

---

## 9. Future Deployment Environments

- **Local / Sandbox Development:** Anvil / Local TRON Node (TronBox / Docker) for unit and integration testing.
- **Testnet:** TRON Nile Testnet or Shasta Testnet for staging contract deployment and oracle integration tests.
- **Mainnet:** TRON Mainnet deployment using hardware multisig governance deployment scripts.
