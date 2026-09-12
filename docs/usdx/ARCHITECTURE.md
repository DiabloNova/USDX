# USDX System Architecture

## 1. Executive Summary & Purpose

USDX is a fiat-backed stablecoin designed to operate on the TRON blockchain adhering to the TRC-20 token standard. The primary financial objective of USDX is to maintain a 1:1 backing by eligible USD fiat reserves held in segregated custodian bank accounts.

**Phase 0 Architecture Notice:** This document defines the baseline architecture, financial invariants, trust boundaries, system lifecycles, and governance model for USDX. This phase is strictly an architecture and technical validation phase. No production smart contracts, backend services, or infrastructure are implemented in Phase 0.

---

## 2. Core Financial Invariants & Trust Model

The protocol architecture enforces strict financial invariants to maintain solvency and operational integrity:

1. **Attested Solvency Invariant:** `totalSupply <= eligibleReserves`
   - **Precision & Security Model:** The total circulating supply of USDX tokens on-chain must never exceed the total verified, eligible fiat reserves as recorded on-chain by the reserve attestation module.
   - **Trust Model Explicit Distinction:** The blockchain cannot directly observe off-chain bank balances or legal ownership of fiat funds. The on-chain invariant strictly protects token supply against the *accepted attested reserve value*. It does not independently prove or verify that the underlying custodian bank balances are truthful. Absolute solvency relies on the integrity of the off-chain custody and attestation layer combined with on-chain cryptographic quorum verification.
2. **Quorum-Controlled Minting Invariant:**
   - Token minting is strictly bound by the active attested reserve ceiling. Minting cannot occur without a valid, fresh attestation quorum, explicit operational minter authorization, and active rate/velocity limiters.
3. **Redemption Non-Atomic Parity Invariant:**
   - Tokens presented for redemption must be irrevocably burned on-chain before or as part of the cross-system redemption state machine before off-chain fiat wire disbursement occurs.
4. **Backend Non-Authority Invariant:**
   - A compromise of off-chain backend infrastructure or API servers must not grant unrestricted token creation authority. Minting requires multi-party authorization and is bounded on-chain by the attested reserve limit.
5. **Fail-Closed Reserve Invariant:**
   - Stale, invalid, zero, or conflicting reserve attestation data forces the minting mechanism into a fail-closed state, automatically halting all new token creation.
6. **Authority Separation Invariant:**
   - Administrative and governance authority (contract upgrades, role assignment, timelock parameters) is strictly isolated from operational roles (minters, redeemers, emergency controllers, attesters).

---

## 3. On-Chain vs. Off-Chain Trust Boundaries

```
+-----------------------------------------------------------------------------------+
|                               OFF-CHAIN DOMAIN                                     |
+-----------------------------------------------------------------------------------+
|  +------------------+     +--------------------+     +------------------------+   |
|  | Bank / Custodian | <-> | Compliance System  | <-> | USDX Core Backend      |   |
|  | (Fiat Reserves)  |     | (KYC / AML / Sanct)|     | (Order Orchestrator)   |   |
|  +------------------+     +--------------------+     +------------------------+   |
|           ^                                                       |               |
|           | Attestation Feed                                      | Signed Intent |
|           v                                                       v               |
|  +----------------------------------------------------------------------------+   |
|  |                    Multi-Attestor Quorum Engine                            |   |
|  +----------------------------------------------------------------------------+   |
+-----------------------------------------------------------------------------------+
                                        |
                    Push Threshold Signed Reserve Data
                                        v
+-----------------------------------------------------------------------------------+
|                                ON-CHAIN DOMAIN                                    |
+-----------------------------------------------------------------------------------+
|  +----------------------------------------------------------------------------+   |
|  |                     Reserve Verifier Contract (Quorum)                     |   |
|  +----------------------------------------------------------------------------+   |
|                                       | Enforce Solvency Ceiling                  |
|                                       v                                           |
|  +----------------------------------------------------------------------------+   |
|  |                     USDX Core Token Contract (UUPS Proxy)                  |   |
|  |  - TRC-20 Interface (6 Decimals)                                           |   |
|  |  - Mint / Burn Access Control                                            |   |
|  |  - Emergency Pause Circuit Breaker                                         |   |
|  |  - Protocol Blacklist / Freeze Enforcement                                 |   |
|  +----------------------------------------------------------------------------+   |
|             ^                                                     ^               |
|             | Mint / Burn Calls                                   | Liquidity     |
|             v                                                     v               |
|  +--------------------+                             +-------------------------+   |
|  | Operational Minter |                             | Post-Launch Secondary   |   |
|  | / Redeemer Keys    |                             | Markets (SunSwap DEX)   |   |
|  +--------------------+                             +-------------------------+   |
+-----------------------------------------------------------------------------------+
```

### Trust Boundary Principles
1. **Off-Chain to On-Chain Boundary:** On-chain contracts do not trust off-chain backend services. All mint operations are constrained on-chain by the `eligibleReserves` balance set by the attestation quorum.
2. **Attestation Boundary:** The protocol trusts a multi-attestor threshold quorum (e.g., 2-of-3 independent attestation nodes/auditors). No single off-chain attestor can unilaterally increase `eligibleReserves`.
3. **Operational vs. Governance Boundary:** Operational keys operate under strict velocity caps and cannot alter protocol roles, upgrade logic, or bypass timelocks.
4. **Secondary Market Boundary:** DEX liquidity (e.g., SunSwap) is strictly external to protocol solvency. AMM pool balances or LP tokens are **never** treated as eligible reserves.

---

## 4. System Components & Responsibilities

### 4.1 On-Chain Smart Contracts
- **USDX Core Token Contract (UUPS Proxy):** Implements TRC-20 standard functions (`transfer`, `approve`, `transferFrom`, `totalSupply`, `balanceOf`) with 6 decimal places. Features permissioned `mint` and `burn`, `pause` circuit breakers, and mandatory compliance `blacklist` / `freeze` controls. Built using the Universal Upgradeable Proxy Standard (UUPS).
- **Reserve Verifier Contract:** Receives and validates cryptographic threshold signatures from authorized attesters. Computes the current `eligibleReserves` ceiling and enforces freshness heartbeats.
- **Timelock Controller:** Enforces a mandatory execution delay (e.g., 48 hours) for all administrative actions, contract upgrades, and parameter modifications proposed by Governance.

### 4.2 Off-Chain Infrastructure
- **USDX Backend Orchestrator:** Manages customer KYC/AML checks, wire deposit matching, redemption workflow state machines, and cryptographic payload generation.
- **Multi-Attestor Quorum Nodes:** Independent services operated by authorized auditors/attesters that query custodian bank balances, verify reserve eligibility, sign attestation payloads, and push updates on-chain.
- **Banking & Custodian Infrastructure:** Regulated banking institutions holding segregated USD fiat deposits securing the stablecoin.

---

## 5. System Lifecycles

### 5.1 Mint Lifecycle
1. **Fiat Wire Deposit:** Customer sends USD fiat wire to designated custodian reserve bank account.
2. **Off-Chain Reconciliation:** Custodian bank notifies USDX orchestrator; system matches wire to customer account.
3. **Compliance Screening:** Automated engine verifies customer KYC status and screens destination TRON wallet against sanctions lists.
4. **Reserve Attestation Update:** Multi-attestor quorum signs and submits updated `eligibleReserves` to Reserve Verifier contract.
5. **Mint Request Execution:** Authorized `Minter` role calls `mint(recipient, amount)` on USDX contract.
6. **On-Chain Solvency & Compliance Validation:** Contract asserts `totalSupply + amount <= eligibleReserves`, recipient is not blacklisted, and contract is `notPaused`.
7. **Issuance:** Token supply increases and tokens are transferred to `recipient` TRON wallet.

### 5.2 Redemption Lifecycle (Cross-System State Machine)
Redemption is an asynchronous, non-atomic workflow bridging on-chain token burning with off-chain fiat banking transfers. It is modeled as a state machine:

```
[Requested] -> [Approved] -> [Burned] -> [Payout Pending] -> [Paid]
     |              |            |              |
     v              v            v              v
 [Rejected]    [Cancelled] [Burn Failed] [Payout Failed] -> [Reconciled / Retried]
```

1. **Requested:** User initiates redemption request off-chain and approves USDX token transfer to protocol redemption module.
2. **Approved:** Compliance engine validates user sanctions status and wire payout details.
3. **Burned:** Operational `Redeemer` role invokes `burn(account, amount)` on-chain. Tokens are permanently destroyed (`totalSupply` decreases).
4. **Payout Pending:** Burn confirmation is received on-chain; backend issues fiat wire transfer instruction to custodian bank.
5. **Paid:** Custodian bank confirms wire execution; redemption order transitions to terminal `Paid` state.
6. **Failure & Reconciliation Handling:**
   - **Payout Failure:** If fiat wire fails (e.g., incorrect wire routing info), order transitions to `Payout Failed`.
   - **Reconciliation / Retry:** Customer service corrects wire details and triggers wire retry (`Payout Pending -> Paid`), or operational admins issue a compensating re-mint credit to user's wallet (`Reconciled`), maintaining exact accounting parity.
   - **Duplicate Payout Prevention:** On-chain burn transaction hash and unique redemption request ID are immutably linked off-chain; backend idempotency locks prevent duplicate bank wires.

### 5.3 Reserve Attestation Lifecycle
1. **Balance Data Collection:** Attestation nodes independently fetch balance data from custodian APIs or certified statements.
2. **Quorum Signature Aggregation:** Each attester signs payload `(eligibleReserves, timestamp, nonce)`. Once threshold quorum (e.g., 2-of-3) is reached, transaction is submitted on-chain.
3. **On-Chain Verification:** Reserve Verifier validates attester signatures, ensures `timestamp` is within allowed window, and updates `eligibleReserves`.
4. **Stale Data Handling (Fail-Closed):** If `block.timestamp > lastAttestationTimestamp + HEARTBEAT_WINDOW`, reserve status becomes `STALE`. `mint()` calls revert immediately until fresh quorum attestation is provided.

### 5.4 Emergency Controls & Fail-Closed Behavior
- **Stale/Invalid Reserve Halt:** Automatic on-chain rejection of mint calls whenever reserve attestation is stale, missing, or contradictory.
- **Emergency Pause Circuit Breaker:** Designated `EmergencyController` role can instantly invoke `pause()` to freeze transfers, minting, and burning during security events.
- **Narrow Scope:** `EmergencyController` can ONLY pause/freeze; it has NO authority to mint tokens, transfer funds, or upgrade contracts.
- **Unpause & Governance Recovery:** Unpausing requires explicit action by the `Governance Multisig` after passing through security review.
- **Compliance Blacklist / Freeze:** Designated compliance role can freeze specific addresses on-chain in compliance with legal mandates.

---

## 6. Governance & Role Separation

Production governance employs strict multi-signature management and timelocks:

| Role Name | Authority Scope | Key Model / Threshold |
| :--- | :--- | :--- |
| **Governance Multisig** | Contract upgrades, timelock administration, role assignments, unpausing | 3-of-5 Hardware Multisig + 48h Timelock |
| **Emergency Controller** | Trigger contract pause, freeze specific blacklisted addresses | 2-of-3 Fast-Response Multisig |
| **Operational Minter** | Call `mint()` within reserve ceiling and velocity limits | Automated KMS / HSM Key |
| **Operational Redeemer** | Call `burn()` for verified redemption orders | Automated KMS / HSM Key |
| **Reserve Attester Quorum** | Submit threshold signed `updateReserves()` payloads | Independent 2-of-3 Oracle / Auditor Keys |

---

## 7. Production Upgradeability Architecture

USDX adopts the **UUPS (Universal Upgradeable Proxy Standard)** pattern combined with a **Timelock Controller** and **3-of-5 Governance Multisig**:

1. **Privileged Upgrades:** Upgrades can only be executed by passing implementation code through the 48-hour Timelock Controller driven by the Governance Multisig.
2. **No Emergency Upgrade Path:** Emergency Controller keys CANNOT trigger code upgrades or alter storage layouts.
3. **Storage Layout Safety:** Storage layout compatibility must be validated via storage layout checks and dedicated upgrade tests in CI pipelines before deployment.
4. **Testnet Verification:** All proxy upgrade implementations must be fully tested and verified on TRON testnets (Nile/Shasta) prior to mainnet execution.

---

## 8. Controlled Launch & DEX Sequencing

DEX liquidity (e.g., SunSwap) is **not** a prerequisite for USDX mainnet deployment. The protocol enforces a strictly phased launch sequence:

1. Core Smart Contract Implementation & Verification
2. Multi-Attestor Reserve Attestation Quorum Implementation
3. Backend Orchestration, Custody & Compliance Integration
4. Testnet Deployment & Adversarial Simulation
5. Independent External Security Audits & Remediation
6. Governance Multisig & Timelock Deployment
7. Controlled Mainnet Deployment with Initial Minting Limits
8. Operational Monitoring & Reserve Verification Period
9. **Post-Launch Optional DEX Liquidity Provisioning (SunSwap)**
10. Gradual Expansion of Minting Limits Based on Operational Evidence
