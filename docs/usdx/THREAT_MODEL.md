# USDX Threat Model & Security Controls Architecture

## 1. Overview & Methodology

This document outlines the security architecture and threat landscape for the USDX fiat-backed stablecoin protocol. Threat vectors are systematically analyzed across on-chain smart contracts, reserve attestation feeds, backend services, custodian banking, and compliance operations.

Mitigations are strictly classified into five distinct security control domains:
1. **Protocol-Enforced Controls:** Technical invariants and rules hard-coded in smart contract logic.
2. **Reserve-Attestation Controls:** Threshold cryptographic quorum rules and heartbeat checks enforcing solvency ceilings.
3. **Backend / Operational Controls:** Off-chain infrastructure security, HSM/KMS key management, velocity limits, and multi-party approvals.
4. **Custodian / Banking Controls:** Legal custody agreements, bankruptcy-remote asset segregation, and audited bank balance statements.
5. **Compliance / Legal Controls:** Mandatory real-time wallet screening, KYC/AML enforcement, and protocol-enforced sanctions freezing.

---

## 2. Comprehensive Threat Analysis Matrix

| ID | Threat Vector | Severity | Attack Description | Mitigation Domain | Primary Defense Mechanism |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TH-01** | **Compromised Mint Key** | **Critical** | Attacker compromises private key of an authorized operational minter account. | Protocol-Enforced & Reserve-Attestation | On-chain `totalSupply <= eligibleReserves` invariant limits minting to accepted reserve ceiling. Emergency Controller can pause contract immediately. |
| **TH-02** | **Compromised Core Backend** | **Critical** | Attacker breaches backend server infrastructure and attempts to forge mint requests or manipulate user state. | Protocol-Enforced & Operational | Backend has no direct minting rights. Mint requests require multi-party operational signatures and are constrained on-chain by the attestation quorum. |
| **TH-03** | **Stale or Compromised Attestation Feed** | **High** | Attestation feed halts or an individual attestor key is compromised to inflate reserves. | Reserve-Attestation | Multi-attestor threshold quorum (e.g., 2-of-3) prevents single-attestor inflation. On-chain heartbeat expiration forces fail-closed halt on stale data. |
| **TH-04** | **Bank Outage or Custodian Insolvency** | **High** | Partner custodian bank halts wire operations or faces financial distress. | Custodian & Operational | Off-chain banking agreements and operational pause controls. Solvency invariant prevents new token minting if reserves are inaccessible. |
| **TH-05** | **Replay or Duplicate Mint Requests** | **Medium** | Replaying valid signed mint payloads across network forks or within the same contract. | Protocol-Enforced | On-chain nonce tracking, chain ID inclusion in signatures, and request expiration timestamps. |
| **TH-06** | **Governance Key Compromise / Malicious Upgrade** | **Critical** | Governance multisig keys compromised to push malicious UUPS implementation upgrade. | Protocol-Enforced & Operational | 3-of-5 Hardware Multisig + mandatory 48-hour Timelock execution delay allowing public detection and emergency intervention. |
| **TH-07** | **Emergency Controller Key Compromise** | **High** | Attacker steals emergency key to maliciously pause contract (Denial of Service). | Protocol-Enforced & Governance | Emergency Controller can ONLY pause/freeze; cannot mint, burn, or transfer funds. Governance Multisig can override, unpause, and replace key. |
| **TH-08** | **DEX Price De-peg / Arbitrage Attack** | **Medium** | Secondary DEX (SunSwap) price fluctuates due to market volatility or flash loans. | Secondary Market | Core protocol mint/burn operates strictly at 1:1 fiat redemption parity. Protocol does not rely on DEX price oracles for solvency. DEX is post-launch. |
| **TH-09** | **TRON Network Congestion / Energy Exhaustion** | **Medium** | Network spam spikes Energy costs or exhausts transaction `feeLimit`, stalling mint/burn operations. | Operational & Technical | Automated fee-limit buffer configuration, pre-staked TRX Energy reserves, and transaction retry queues. |
| **TH-10** | **Sanctions / Illicit Address Exposure** | **High** | Sanctioned or illicit actor attempts to hold or transfer USDX tokens on-chain. | Protocol-Enforced & Compliance | Real-time compliance screening prior to mint/redemption, and mandatory protocol-level `blacklist` / `freeze` capability. |

---

## 3. Explicit Security Domain Control Mapping

```
+-----------------------------------------------------------------------------------+
|                            SECURITY CONTROL DOMAINS                               |
+-----------------------------------------------------------------------------------+

 [ PROTOCOL-ENFORCED CONTROLS ] (Hard On-Chain Smart Contract Logic)
  - Solvency Enforcer: totalSupply <= eligibleReserves
  - UUPS Timelock Governance: 48-hour delay on code upgrades
  - AccessControl Roles: Isolation of MINTER, REDEEMER, PAUSER, DEFAULT_ADMIN
  - Protocol Blacklist: Freezing transfers to/from sanctioned addresses

 [ RESERVE-ATTESTATION CONTROLS ] (On-Chain Cryptographic Quorum)
  - Multi-Attestor Quorum: Threshold signature validation (e.g., 2-of-3 attesters)
  - Heartbeat Expiration: Automated fail-closed halt if data age exceeds max threshold
  - No Unilateral Authority: Zero single-attestor ability to increase reserves

 [ BACKEND / OPERATIONAL CONTROLS ] (Off-Chain Systems & Key Management)
  - AWS KMS / Hardware Security Modules (HSM) for operational transaction signing
  - Operational Velocity Caps: 24-hour rolling mint/burn limits per key
  - Asynchronous Redemption State Machine: Reconciled order state tracking

 [ CUSTODIAN / BANKING CONTROLS ] (Off-Chain Financial Institutions)
  - Segregated bankruptcy-remote USD fiat accounts at regulated banking institutions
  - Independent periodic reserve audit statements

 [ COMPLIANCE / LEGAL CONTROLS ] (Legal & Regulatory Frameworks)
  - Automated OFAC, UN, and EU sanctions screening (TRM / Chainalysis webhooks)
  - Full KYC/AML onboarding prior to approving direct fiat-to-token operations
+-----------------------------------------------------------------------------------+
```

---

## 4. Technical Scope & External Dependencies

1. **TRON Network Security:** Protocol execution depends on TRON DPoS consensus integrity and active TVM parameters.
2. **Attestation Quorum Dependency:** If a threshold quorum of attesters goes offline, new minting fails closed automatically. Secondary transfers continue unless globally paused.
3. **No Unsubstantiated Claims:** Off-chain banking partners, specific Treasury allocation percentages, and legal jurisdictions remain subject to formal operational setup in Phase 3 and Phase 4.
