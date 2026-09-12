# USDX Threat Model & Security Controls Architecture

## 1. Overview & Security Architecture

This document defines the comprehensive threat model and security control architecture for the USDX fiat-backed stablecoin protocol on the TRON blockchain. The threat model establishes clear trust boundaries, categorizes security mitigations across five distinct domains, and analyzes potential attack vectors against both on-chain smart contracts and off-chain operational components.

### 1.1 Confirmed Architectural Safeguards

The USDX security model relies on the following confirmed architectural elements:
- **Mandatory Solvency Invariant (`totalSupply <= eligibleReserves`):** Protocol smart contracts strictly prevent token minting if the post-operation `totalSupply` would exceed the on-chain accepted `eligibleReserves`.
- **Mandatory Blacklist/Freeze Capability:** The TRC-20 token contract implements address freezing and blacklisting mechanisms to comply with legal freeze orders and restrict sanctioned actors.
- **3-of-5 Governance Multisig:** Administrative authority, role assignments, and critical protocol updates require approval from a 3-of-5 multi-signature threshold.
- **UUPS Proxy + Timelock Upgrade Model:** Smart contract upgrades utilize the Universal Upgradeable Proxy Standard (UUPS) controlled by a mandatory execution timelock delay managed by Governance.
- **Fail-Closed Emergency Controls:** Dedicated Emergency Controller roles can immediately pause contract state transitions (transfers, mints, burns) upon detecting security incidents or stale attestation data.
- **Multi-Attestor Quorum-Based Reserve Attestation:** Reserve data updates require signature thresholds from a multi-attestor quorum rather than a single oracle feed.

### 1.2 Distinction Between Attested Reserves and Physical Bank Reserves

> **Core Security Principle:** The protocol-enforced solvency invariant (`totalSupply <= eligibleReserves`) strictly constrains circulating token supply relative to the accepted on-chain attested reserve value (`eligibleReserves`). It mathematically guarantees that minting cannot exceed the reserve figure recorded in the verifier contract. However, the solvency invariant **does not independently verify or prove the underlying physical reality** of fiat balances held in off-chain custodian bank accounts. The fidelity of `eligibleReserves` relies on the integrity of the off-chain reserve-attestation mechanism, multi-attestor signatures, and custodian reporting.

---

## 2. Security Control Domains

Mitigation mechanisms are explicitly categorized into five distinct control domains:

1. **Protocol-Enforced Controls (On-Chain):**
   - Hard programmatic checks executed directly by smart contract code.
   - Includes invariant assertions (`totalSupply <= eligibleReserves`), role-based access control (RBAC), UUPS proxy storage checks, timelock delays, fail-closed pause state checks, and mandatory address blacklist/freeze logic.

2. **Reserve-Attestation Controls:**
   - Cryptographic mechanisms bridging off-chain bank balance reports to on-chain state.
   - Includes multi-attestor signature quorum verification, payload nonce/timestamp validation, and maximum age heartbeat timeouts (failing closed if data is stale).

3. **Backend / Operational Controls:**
   - Mitigations embedded within off-chain orchestration services, APIs, and key management systems.
   - Includes Hardware Security Modules (HSM) / Key Management Service (KMS) for signing operational transactions, input validation, transaction idempotency locks, separation of duties, and daily/per-transaction operational velocity limits.

4. **Custodian / Banking Controls:**
   - Legal, financial, and institutional safeguards governing off-chain fiat reserves.
   - Includes bankruptcy-remote segregated custodial accounts, tier-1 regulated banking partner agreements, liquid cash/equivalent reserve management, and independent audit attestations.

5. **Compliance / Legal Controls:**
   - Procedures and tools for regulatory adherence and law enforcement cooperation.
   - Includes automated KYC/AML verification, real-time wallet sanctions screening, Suspicious Activity Report (SAR) filing, and execution procedures for on-chain freezing/blacklisting orders.

---

## 3. Threat Analysis Matrix

| ID | Threat Vector | Severity | Control Domain | Primary Defense Mechanism |
| :--- | :--- | :--- | :--- | :--- |
| **TH-01** | **Compromised Mint Authority** | Critical | Protocol & Operational | On-chain invariant (`totalSupply <= eligibleReserves`), daily/per-tx velocity limits, instant Emergency Controller pause. |
| **TH-02** | **Compromised Backend Infrastructure** | Critical | Protocol & Operational | Backend lacks unilateral minting capability; all mint requests require valid role signatures and must satisfy on-chain solvency constraints. |
| **TH-03** | **Compromised or Colluding Reserve Attestors** | Critical | Attestation & Governance | Multi-attestor quorum threshold ($m$-of-$n$), governance revocation of compromised attestors, custodian cross-checks, manual/emergency pause. |
| **TH-04** | **Stale or Manipulated Reserve Data** | High | Attestation & Protocol | On-chain heartbeat expiration timeout forcing a fail-closed state (disabling mints), quorum payload validation. |
| **TH-05** | **Bank / Custodian Outage or Insolvency** | High | Custodian & Operational | Diversified regulated custodial accounts, bankruptcy-remote structures, immediate protocol pause upon detected custodial impairment. |
| **TH-06** | **Duplicate Issuance (Replay / Double-Mint)** | Medium | Protocol & Operational | Mandatory unique transaction nonces, chain ID signature binding, database state idempotency locks. |
| **TH-07** | **Governance Key Compromise** | Critical | Protocol & Governance | 3-of-5 hardware multisig quorum requirement, public timelock delay prior to administrative execution, Emergency Controller veto pause. |
| **TH-08** | **Upgrade Abuse** | Critical | Protocol & Governance | UUPS proxy architecture requiring 3-of-5 governance approval and mandatory timelock delay before executing proxy implementation upgrades. |
| **TH-09** | **Emergency-Controller Compromise** | High | Protocol & Governance | Emergency Controller role is strictly pause-only (cannot mint, burn, upgrade, or seize funds); 3-of-5 Governance multisig retains override and role revocation authority. |
| **TH-10** | **Blacklist / Freeze Abuse or Operational Error** | Medium | Compliance & Governance | Mandatory blacklist/freeze capability gated by multi-party compliance approvals, audit logging, and Governance unfreeze override procedures. |
| **TH-11** | **DEX Manipulation & Arbitrage Exploits** | Medium | Protocol & Market | Core mint/burn operations enforce fixed 1:1 fiat parity; protocol does not consume secondary DEX price oracles for solvency or mint/burn logic. |
| **TH-12** | **TRON Resource / Congestion Issues** | Medium | Operational & Protocol | Pre-staked TRX Energy/Bandwidth pools, automated dynamic fee-limit buffer calculations, backend order batching and retry queues. |
| **TH-13** | **Sanctions / Compliance Misuse** | High | Compliance & Protocol | Automated pre-transaction KYC/sanctions screening APIs, on-chain mandatory `blacklist`/`freeze` enforcement blocking transfers for flagged addresses. |

---

## 4. Detailed Threat Vector Analysis

### TH-01: Compromised Mint Authority
- **Attack Vector:** An attacker compromises the private key or HSM credentials of an operational minter role.
- **Mitigation Strategy:**
  - *Protocol:* The smart contract strictly enforces `totalSupply + amount <= eligibleReserves`. Even with a stolen minter key, the attacker cannot mint beyond the accepted on-chain attested reserves.
  - *Operational:* Operational minters are subject to rolling daily and per-transaction velocity caps enforced off-chain and on-chain. Emergency Controllers can immediately revoke minter roles or pause the contract.

### TH-02: Compromised Backend Infrastructure
- **Attack Vector:** An adversary gains full administrative access to the core off-chain backend services, attempting to forge mint orders or alter transaction databases.
- **Mitigation Strategy:**
  - *Protocol:* The backend is treated as an untrusted entity by smart contracts. All state-changing calls must be signed by authorized cryptographic keys and pass on-chain role, cap, and solvency checks.
  - *Operational:* API requests require multi-factor authorization, and database state transitions utilize strict idempotency locks.

### TH-03: Compromised or Colluding Reserve Attestors
- **Attack Vector:** A threshold quorum of reserve attestors is compromised or colludes to submit artificially inflated reserve balances (`eligibleReserves`), enabling over-issuance.
- **Mitigation Strategy:**
  - *Attestation:* Requires a multi-attestor signature quorum (e.g., $m$-of-$n$ independent attestation nodes) rather than a single feed provider.
  - *Governance & Operational:* Off-chain monitoring cross-references independent bank APIs and audit statements. Governance can instantly remove compromised attestor keys, and Emergency Controllers can pause minting.

### TH-04: Stale or Manipulated Reserve Data
- **Attack Vector:** Oracle network outages, network partition, or malicious delay of attestation updates leading to outdated or manipulated reserve figures being relied upon for minting.
- **Mitigation Strategy:**
  - *Attestation & Protocol:* Every attestation update contains a timestamp. The smart contract enforces a maximum heartbeat period (`MAX_ATTESTATION_AGE`). If current time exceeds `lastAttestationTimestamp + MAX_ATTESTATION_AGE`, the reserve state transitions to `STALE`, automatically halting all new mint operations (fail-closed).

### TH-05: Bank / Custodian Outage or Insolvency
- **Attack Vector:** A partner custodial bank experiences operational outages, regulatory freezing, or insolvency, making physical reserve backing inaccessible or impaired.
- **Mitigation Strategy:**
  - *Custodian:* Reserves are distributed across multiple tier-1 regulated banking partners in bankruptcy-remote segregated accounts holding cash and highly liquid cash equivalents.
  - *Operational:* Real-time monitoring of banking partner health triggers an immediate operational pause on new minting and redemptions for affected channels.

### TH-06: Duplicate Issuance (Replay / Double-Mint)
- **Attack Vector:** An attacker attempts to replay previously executed mint or redemption payload signatures across network re-orgs, forks, or within the same chain.
- **Mitigation Strategy:**
  - *Protocol:* All signed payloads must include unique sequential nonces, transaction expiration timestamps, and explicit chain ID domain separators (EIP-712 style). On-chain contracts track and mark nonces as used.
  - *Operational:* Off-chain backend databases enforce strict unique constraint locks per mint/burn order ID.

### TH-07: Governance Key Compromise
- **Attack Vector:** Adversaries gain control of governance keys to modify contract logic, assign arbitrary roles, or steal funds.
- **Mitigation Strategy:**
  - *Protocol & Governance:* Governance authority is vested in a 3-of-5 hardware-backed multi-signature wallet. All administrative actions (role changes, timelock adjustments) are subject to a mandatory public timelock execution delay (e.g., 48 hours), allowing time for detection and emergency pause intervention.

### TH-08: Upgrade Abuse
- **Attack Vector:** A compromised or malicious governance entity attempts to deploy a backdoored contract implementation via proxy upgrade.
- **Mitigation Strategy:**
  - *Protocol:* The protocol utilizes a UUPS proxy architecture. Implementation upgrades must be queued through the Governance Timelock contract. The 48-hour timelock delay ensures token holders and security monitors can inspect upgrade bytecode before execution.

### TH-09: Emergency-Controller Compromise
- **Attack Vector:** An attacker compromises the Emergency Controller key and maliciously invokes pause, causing denial-of-service for users.
- **Mitigation Strategy:**
  - *Protocol:* The Emergency Controller role is strictly **pause-only**. It possesses no capability to mint, burn, transfer funds, or alter contract implementations.
  - *Governance:* The 3-of-5 Governance Multisig retains authority to override an illegitimate pause, unpause the contract, and replace the compromised Emergency Controller key.

### TH-10: Blacklist / Freeze Abuse or Operational Error
- **Attack Vector:** A legitimate user address is mistakenly blacklisted due to operational error, or an attacker attempts to bypass address freeze controls.
- **Mitigation Strategy:**
  - *Compliance & Protocol:* Mandatory blacklist/freeze logic is embedded in the TRC-20 transfer standard, blocking transfers to/from flagged accounts. Blacklist actions require multi-party compliance sign-off and audit logging. Governance retains override authority to rectify erroneous address freezes.

### TH-11: DEX Manipulation & Arbitrage Exploits
- **Attack Vector:** Manipulating secondary market (DEX) token prices via flash loans or market dumping to exploit protocol mint/redemption mechanisms.
- **Mitigation Strategy:**
  - *Protocol & Market:* USDX core contracts do not query or depend on secondary DEX price oracles (AMM spot prices) for solvency or mint/burn conversions. Minting and burning operate strictly at 1:1 fiat parity through authorized channels, isolating the core protocol from DEX price fluctuations.

### TH-12: TRON Resource / Congestion Issues
- **Attack Vector:** TRON network congestion or sudden spikes in Energy/Bandwidth costs exhaust the contract `feeLimit`, causing transaction failures and operational stalls.
- **Mitigation Strategy:**
  - *Operational:* Protocol operational accounts maintain pre-staked TRX reserves to generate dedicated Energy and Bandwidth.
  - *Off-Chain:* Backend systems dynamically calculate required `feeLimit` parameters with buffer margins and manage retry queues for pending transactions.

### TH-13: Sanctions / Compliance Misuse
- **Attack Vector:** Sanctioned individuals or illicit actors attempt to utilize USDX for money laundering or evasion of legal restrictions.
- **Mitigation Strategy:**
  - *Compliance:* Off-chain onboarding requires strict KYC/AML verification. Real-time sanctions screening APIs analyze recipient addresses prior to initiating mint or redemption operations.
  - *Protocol:* The mandatory on-chain `blacklist`/`freeze` mechanism allows compliance officers to immediately freeze tokens held by sanctioned addresses upon receiving valid regulatory or legal orders.

---

## 5. Residual Risks & Trust Assumptions

1. **TRON Blockchain Consensus & Infrastructure:** The protocol relies on the underlying security, availability, and Delegated Proof of Stake (DPoS) consensus of the TRON network. Re-organizations or network-wide outages remain external dependencies.
2. **Attester Quorum Integrity:** If a colluding majority of reserve attestors submits false data alongside compromised operational minter keys, over-issuance could theoretically occur up to the false attested limit before human/emergency intervention pauses the protocol.
3. **Off-Chain Legal and Banking System Dependencies:** Protocol smart contracts cannot unilaterally resolve real-world bank receiverships, asset seizures, or fiat transfer freezes imposed by banking regulators. In such events, administrative pause controls are deployed to align protocol state with legal realities.
