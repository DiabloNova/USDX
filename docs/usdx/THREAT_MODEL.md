# USDX Threat Model & Security Controls Architecture

## 1. Overview & Methodology

This document outlines the security architecture and threat landscape for the USDX fiat-backed stablecoin protocol. The threat model analyzes attack vectors across both on-chain smart contracts and off-chain operational systems, categorizing mitigation mechanisms across five security control domains:

1. **On-Chain Security Guarantees:** Hard rules enforced strictly by smart contract code.
2. **Off-Chain Security Controls:** Mitigations implemented in backend infrastructure, APIs, and key management systems (HSM/KMS).
3. **Operational Controls:** Human processes, multi-party approvals, separation of duties, and velocity limits.
4. **Custodian Controls:** Banking agreements, bankruptcy-remote segregation, and independent third-party audits.
5. **Compliance Controls:** Real-time wallet screening, KYC/AML enforcement, and regulatory sanctions freeze procedures.

---

## 2. Comprehensive Threat Analysis Matrix

| ID | Threat Vector | Severity | Attack Description | Mitigation Domain | Primary Defense Mechanism |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TH-01** | **Compromised Mint Authority** | **Critical** | Attacker steals or compromises the private key of an authorized operational minter. | On-Chain & Operational | On-chain hard solvency cap (`totalSupply + amount <= eligibleReserves`), daily/per-tx velocity mint caps, and instant revocation by Emergency Controller. |
| **TH-02** | **Compromised Core Backend** | **Critical** | Backend infrastructure compromised; attacker attempts to forge mint requests or manipulate user databases. | On-Chain & Off-Chain | On-chain verification enforces reserve limits and minter signatures. Compromised backend cannot bypass on-chain solvency checks or governance timelocks. |
| **TH-03** | **Stale or Manipulated Reserve Attestation** | **High** | Attestation feed fails, oracle halts, or attester key compromised to post false high reserve values. | On-Chain & Custodian | On-chain heartbeat expiration timeout (fail-closed state on stale data), multi-attester signature thresholds, and direct custodian API cross-checks. |
| **TH-04** | **Bank / Custodian Insolvency or Outage** | **High** | Reserve bank goes into receivership or halts wire operations, rendering reserves inaccessible. | Custodian & Operational | Diversification across multiple tier-1 regulated banking partners, overnight US Treasury bill allocations, and instant pause of minting/redemptions. |
| **TH-05** | **Replay or Duplicate Issuance Requests** | **Medium** | Replaying previously valid signed mint transactions across network forks or within the same contract. | On-Chain & Off-Chain | Mandatory unique request nonces, chain ID inclusion in signatures, and on-chain used-nonce tracking. |
| **TH-06** | **Governance Key Compromise / Upgrade Abuse** | **Critical** | Governance multisig keys compromised to push malicious contract upgrades or drain reserves. | On-Chain & Operational | Multi-signature requirement (3-of-5), mandatory 48-hour timelock for contract upgrades, public event emitting, and emergency pause veto. |
| **TH-07** | **Emergency Controller Compromise** | **High** | Compromised emergency key maliciously pauses the contract to create denial-of-service. | On-Chain & Governance | Emergency Controller can ONLY pause (cannot mint, burn, or transfer funds). Governance multisig retains authority to override/unpause and replace key. |
| **TH-08** | **DEX Price Manipulation & Arbitrage Exploits** | **Medium** | Price of USDX on secondary DEXs (SunSwap) de-pegs due to market panic or flash loan attacks. | Secondary Market | Core protocol mint/burn operates strictly at 1:1 fiat redemption parity. Protocol does not rely on AMM price oracles for solvency. |
| **TH-09** | **TRON Network Congestion / Energy Exhaustion** | **Medium** | Network spam spikes Energy prices or exhausts contract `feeLimit`, stalling mint/redemption calls. | Operational & Technical | Automated fee-limit buffer configuration, pre-staked TRX Energy reserves, and fallback batching mechanisms. |
| **TH-10** | **Sanctions / Illicit Flow Exposure** | **High** | Malicious actor attempts to bridge or transfer USDX into sanctioned wallets. | Compliance & On-Chain | Automated real-time wallet screening prior to minting/redemption, on-chain contract `blacklist` / `freeze` capability for law enforcement compliance. |

---

## 3. Detailed Security Domain Control Mapping

```
+-----------------------------------------------------------------------------------+
|                            SECURITY CONTROL DOMAINS                               |
+-----------------------------------------------------------------------------------+

 [ ON-CHAIN GUARANTEES ]
  - Solvency assertion: totalSupply <= eligibleReserves
  - Access Control: Role-based permissions (MINTER, BURNER, PAUSER, DEFAULT_ADMIN)
  - Timelock Enforcement: Execution delay on administrative functions
  - Blacklist / Freeze: Block transfers to/from sanctioned addresses

 [ OFF-CHAIN CONTROLS ]
  - Hardware Security Modules (HSM) / AWS KMS for signing operational transactions
  - Strict input validation and sanitization on all backend APIs
  - Distributed database state machines with idempotency locks

 [ OPERATIONAL CONTROLS ]
  - Separation of duties: Operational minters cannot alter governance roles
  - Velocity limits: Rolling 24-hour mint/burn caps per operator
  - Multi-party approval workflows for fiat wire disbursements

 [ CUSTODIAN CONTROLS ]
  - Segregated bankruptcy-remote reserve accounts
  - Daily independent third-party reserve attestations
  - Tier-1 regulated banking institutions with Federal Reserve / Central Bank access

 [ COMPLIANCE CONTROLS ]
  - Automated OFAC, UN, and EU sanctions screening (TRM / Chainanalysis APIs)
  - Full KYC/AML verification prior to approving fiat-to-crypto minting
  - Suspicious Activity Report (SAR) filing protocols
+-----------------------------------------------------------------------------------+
```

---

## 4. Residual Risks & Technical Assumptions

1. **TRON Network Security:** The protocol relies on the security and consensus mechanism of the TRON network (Delegated Proof of Stake). Network re-orgs or consensus failures represent external dependencies.
2. **Oracle / Attestation Reliability:** If all authorized reserve attesters go offline, new minting is disabled (fail-closed). Secondary trading continues uninterrupted unless emergency pause is triggered.
3. **Legal Regulatory Actions:** Regulatory orders freezing custodian bank accounts cannot be resolved solely on-chain; emergency pause controls exist to prevent systemic imbalance.
