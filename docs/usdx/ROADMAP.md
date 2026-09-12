# USDX Phased Implementation Roadmap

## 1. Overview

This roadmap defines the sequential development phases for the USDX fiat-backed stablecoin project on TRON. Implementation proceeds in strict, controlled stages to reflect the confirmed architecture, enforce core financial invariants (`totalSupply <= eligibleReserves`), validate operational readiness, and ensure a safe, phased mainnet deployment.

---

## 2. Implementation Phases Flow

```
+-----------------------------------------------------------------------------------+
| PHASE 0: Architecture & Baseline Validation (CURRENT PHASE)                       |
|  - Toolchain setup (Foundry, solc 0.8.20, EVM london target)                      |
|  - Core Invariants, System Architecture, Threat Model, Technical Validation       |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 1: Core Protocol Smart Contracts                                           |
|  - TRC-20 Token Behavior (6 Decimals) & Supply Controls                           |
|  - Solvency Invariant (`totalSupply <= eligibleReserves`) & Mint Authorization     |
|  - Blacklist / Freeze Compliance Hooks & Emergency Circuit Breakers (Pause)       |
|  - Governance Framework & Upgrade Safety                                          |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 2: Reserve Attestation Engine                                               |
|  - Multi-Attestor Model & Quorum Authorization Signatures                         |
|  - Data Freshness & Heartbeat Enforcement                                         |
|  - Invalid / Stale / Conflicting Data Handling (Fail-Closed Minting)              |
|  - Off-Chain Bank Reserve Reconciliation                                          |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 3: Backend, Custody, Redemption & Compliance Integration                    |
|  - Mint & Redemption Workflows & Custodian Integration                            |
|  - Non-Atomic Redemption State Machine & Payout Failure / Retry / Reconciliation  |
|  - KYC / AML and Sanctions Integration Boundaries                                 |
|  - Operational Controls & KMS / HSM Key Management                                |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 4: Testnet & Comprehensive Security Validation                              |
|  - Adversarial, Authorization, Fuzz, Invariant/Property & Negative Testing        |
|  - Upgrade / Storage-Layout Testing & Differential Testing                        |
|  - Formal Analysis / Verification & Independent Third-Party Audits                |
|  - Testnet Staging (TRON Nile / Shasta)                                           |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 5: Operational Readiness & Controlled Mainnet Launch                        |
|  - Explicit Operational Readiness Gates Pass                                      |
|  - Mainnet Deployment & Verification on TRONSCAN                                  |
|  - Controlled Initial Issuance Limits & Observation Period                        |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| POST-MAINNET: Secondary Market & DEX Integration                                  |
|  - SunSwap DEX / Secondary Liquidity Integration (After Mainnet Validation)       |
|  - Strict Exclusion: DEX Liquidity Excluded From Eligible Reserves                |
+-----------------------------------------------------------------------------------+
```

---

## 3. Phase Details & Explicit Readiness Gates

### Phase 0: Architecture & Baseline Validation (Current)
- **Focus:** Technical validation, toolchain setup, threat modeling, architectural decision records.
- **Exit Criteria:** Approved architecture, verified toolchain smoke tests passing, zero production smart contract code committed.

### Phase 0: Architecture & Foundation Baseline (Current)
- **Focus:** Technical validation, toolchain configuration, threat modeling, system architecture definition, and architectural decision records.
- **Scope:**
  - Pinned Foundry toolchain configuration (`solc 0.8.20`, `evm_version = "london"` for TVM compatibility).
  - Documentation of system architecture, financial invariants, threat vectors, and technical validation matrix.
- **Exit Criteria:** Approved architectural documentation, passing smoke tests on toolchain scaffold, zero production contract code committed.

### Phase 1: Core Protocol
- **Focus:** Development and testing of core on-chain smart contract components.
- **Scope:**
  - **TRC-20 Token Behavior:** Standard TRC-20 interface with 6 decimal places.
  - **Supply Controls & Solvency Invariant:** Hard enforcement of `totalSupply <= eligibleReserves` on token minting.
  - **Mint Authorization:** Permissioned minting requiring explicit authorized minter roles and rate limits.
  - **Blacklist / Freeze:** Compliance hooks for account-level freezing, unfreezing, and sanctioned address blocking.
  - **Emergency Controls:** Circuit breaker pause mechanism (`EmergencyController`) to halt transfers, mints, and burns during anomalous events.
  - **Governance & Upgrade Safety:** Role separation, timelocks, and storage layout safety checks for contract upgrades.
- **Exit Criteria:** Passing comprehensive unit and integration test suites; storage layout compatibility verified for upgrade paths.

### Phase 2: Reserve Attestation
- **Focus:** On-chain verification of off-chain bank reserve attestations prior to production issuance.
- **Scope:**
  - **Multi-Attestor Model:** Cryptographic signature verification supporting threshold signature feeds from independent attestors.
  - **Quorum Authorization:** On-chain enforcement requiring M-of-N valid attester signatures before reserve updates are accepted.
  - **Freshness & Heartbeat:** Enforcing strict expiration timestamps (`lastAttestationTimestamp + HEARTBEAT_PERIOD`).
  - **Invalid / Stale / Conflicting Data Handling:** Logic to reject out-of-order, stale, or contradictory attestation payloads.
  - **Fail-Closed Minting:** Automatic suspension of minting when attestation data is stale, missing, or indicates `eligibleReserves < totalSupply`.
  - **Reserve Reconciliation:** Standardized data formats for reconciliations between custodial bank balances and on-chain reserve feeds.
- **Exit Criteria:** Fully validated oracle/attestation verifier contract on testnet, demonstrating correct fail-closed transitions under simulated oracle delay, bad signature payloads, and data conflicts.

### Phase 3: Backend, Custody, Redemption & Compliance Integration
- **Focus:** Off-chain infrastructure, custodian banking workflows, non-atomic redemption state machines, and compliance enforcement.
- **Scope:**
  - **Mint Workflow:** Wire deposit detection, KYC/AML confirmation, signed payload creation, and submission to the on-chain minter.
  - **Redemption Workflow:** User redemption requests, on-chain token burning, and off-chain fiat payout execution.
  - **Custodian Integration:** Secure bank API connections and automated balance statement ingestion for attestation feeds.
  - **Non-Atomic Redemption State Machine:** Formal tracking of multi-step redemptions (On-Chain Burn -> Pending Payout -> Settled / Failed Payout).
  - **Payout Failure / Retry / Reconciliation:** Automated procedures for handling bank wire failures, user refund state transitions, and audit logging.
  - **KYC / AML & Sanctions Integration Boundaries:** Automated wallet screening (OFAC/sanctions) before mint or redemption processing.
  - **Operational Controls:** KMS / HSM key management with rate limiting, multi-party controls, and operational role separation.
- **Exit Criteria:** End-to-end integration tests in staging environment using mock bank APIs, confirming non-atomic redemption lifecycle resilience and compliance hook triggers.

### Phase 4: Testnet & Comprehensive Security Validation
- **Focus:** Multi-layered security testing, formal analysis, external audits, and public testnet deployment.
- **Scope:**
  - **Adversarial & Authorization Testing:** Permission bypass attempts, role spoofing, and privilege escalation scenarios.
  - **Invariant & Property-Based Testing:** Automated property checking in Foundry verifying `totalSupply <= eligibleReserves` under all random call sequences.
  - **Fuzzing & Negative Testing:** Stateful fuzzing with invalid inputs, boundary conditions, and reentrancy vectors.
  - **Upgrade & Storage-Layout Testing:** Storage collision checks between proxy contract revisions.
  - **Differential Testing:** Cross-checking behavior against reference standard implementations where applicable.
  - **Formal Analysis & Verification:** Formal verification of critical invariants (e.g. solvency and access control logic) where practical.
  - **Independent Security Audits:** Comprehensive audits conducted by reputable independent third-party security firms.
  - **Testnet Deployment:** Staging deployment on TRON Nile / Shasta testnets for multi-party operational exercises.
- **Security Proof Clarification:** Code coverage metrics (e.g., 100% line/branch coverage) are baseline metrics but do NOT constitute sufficient proof of security on their own. Formal verification, fuzzing, adversarial testing, and independent security audits are required.
- **Exit Criteria:** Completion of independent audits, resolution or mitigation of all identified security findings, and successful testnet operational period without incidents.

### Phase 5: Operational Readiness & Controlled Mainnet Launch
- **Focus:** Passing strict operational readiness gates and launching mainnet operations under controlled issuance constraints.
- **Scope:**
  - **Operational Readiness Gates:** Mandatory sign-off across eight domain gates prior to mainnet contract deployment:
    1. *Reserve / Custody Gate:* Custodian accounts established, attestation feeds operational, reserve accounting verified.
    2. *Redemption Operations Gate:* Bank payout rails, retry/refund workflows, and liquidity buffers operational.
    3. *Compliance & Legal Gate:* Legal opinions finalized, sanctions screening webhooks active, regulatory reporting operational.
    4. *Monitoring & Alerting Gate:* Real-time monitoring of on-chain events, reserve status, and anomalous transfers.
    5. *Multisig & Key Management Gate:* Hardware-backed multisigs deployed (3-of-5 with 48h timelock for governance, fast-response emergency keys), KMS/HSM keys configured.
    6. *Emergency Response Gate:* Incident response runbooks written, emergency pause circuit breaker tested, key rotation protocols established.
    7. *Upgrade Safety Gate:* Timelock governance active, proxy upgrade procedures verified on testnet.
    8. *Controlled Issuance Limits Gate:* Initial mainnet mint caps, daily velocity limits, and global supply ceilings configured.
  - **Mainnet Deployment:** Contract deployment and source code verification on TRONSCAN.
  - **Controlled Mainnet Launch:** Mainnet operations commence with restricted initial issuance and an extended observation period to monitor system stability before scaling limits.
- **Exit Criteria:** All operational readiness gates formally signed off; contracts deployed on TRON Mainnet; controlled issuance phase active with verified reserve attestations and real-time monitoring.

### Post-Mainnet: Secondary Market & DEX Integration
- **Focus:** Enabling secondary market liquidity after controlled mainnet deployment and operational validation.
- **Scope:**
  - **SunSwap DEX Integration:** Bootstrapping secondary market liquidity pools on SunSwap (or other TRON DEXes).
  - **Exclusion from Reserves:** Liquidity in DEX pools or secondary markets is strictly excluded from eligible reserve calculations (`eligibleReserves` strictly represents fiat/cash equivalents in audited custodian bank accounts).
  - **Deployment Decoupling:** DEX availability and secondary pool provisioning are NOT prerequisites for initial mainnet deployment.
- **Exit Criteria:** Stable secondary trading pairs operating with zero impact on primary mint/redemption solvency invariants.
