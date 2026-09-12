# USDX Phased Implementation Roadmap

## 1. Overview

This roadmap defines the sequential development phases for the USDX fiat-backed stablecoin project on TRON. Implementation proceeds in strict stages to ensure safety, multi-layered testing, formal verification of invariants, third-party security auditing, and operational readiness prior to mainnet launch.

---

## 2. Implementation Phases Overview

```
+-----------------------------------------------------------------------------------+
| PHASE 0: Architecture & Baseline Validation (CURRENT PHASE)                       |
|  - Toolchain setup (Foundry, solc 0.8.20, EVM london target)                      |
|  - Core Invariants, System Architecture, Threat Model, Technical Validation       |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 1: Core Smart Contract Implementation & Security Properties                 |
|  - TRC-20 Base Implementation (6 Decimals, Initial Supply 0)                      |
|  - UUPS Upgradeable Proxy Architecture & Storage Layout Checks                    |
|  - AccessControl (Governance, Minter, Redeemer, Emergency Controller)             |
|  - Solvency Enforcer (`totalSupply <= eligibleReserves`), Blacklist, Pause        |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 2: Reserve Attestation & Quorum Verification Mechanism                      |
|  - Multi-Attestor Threshold Signature Verification Contract                        |
|  - Heartbeat Expiration & Stale Data Enforcement (Fail-Closed)                    |
|  - Fallback Oracle Integration (e.g., Chainlink PoR Adapter)                      |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 3: Backend, Custody, Redemption & Compliance Integration                    |
|  - Asynchronous Redemption State Machine Engine & Reconciliation Workflows        |
|  - Custodian Bank API Ingestion & Attestation Relay Nodes                         |
|  - Automated KYC / AML / Sanctions Screening Integration                          |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 4: Comprehensive Validation, Testnet Staging & Audits                       |
|  - Multi-Layered Testing Suite (Unit, Invariant/Fuzz, Storage Layout, Negative)   |
|  - Formal Verification / Analysis of High-Value Solvency Invariants               |
|  - TRON Testnet (Nile / Shasta) Deployment & Staging Verification                 |
|  - Independent External Security Audits (2+ Reputable Audit Firms)                |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| PHASE 5: Governance Setup & Controlled Mainnet Launch                             |
|  - 3-of-5 Hardware Multisig Governance & 48h Timelock Controller Initialization   |
|  - Controlled Mainnet Deployment & Source Verification on TRONSCAN                 |
|  - Limited Initial Minting Limits & Operational Monitoring                        |
+-----------------------------------------------------------------------------------+
                                        |
                                        v
+-----------------------------------------------------------------------------------+
| POST-LAUNCH: Secondary Market & DEX Integration                                   |
|  - Operational evidence review and minting limit scaling                          |
|  - Optional DEX Liquidity Provisioning (SunSwap Pools)                            |
+-----------------------------------------------------------------------------------+
```

---

## 3. Phase Details & Explicit Readiness Gates

### Phase 0: Architecture & Baseline Validation (Current)
- **Focus:** Technical validation, toolchain setup, threat modeling, architectural decision records.
- **Exit Criteria:** Approved architecture, verified toolchain smoke tests passing, zero production smart contract code committed.

### Phase 1: Core Smart Contract Implementation & Security Properties
- **Focus:** Solidity implementation of UUPS proxy core token contract, role isolation, pause circuit breaker, blacklist/freeze hooks, and solvency checking modifiers.
- **Exit Criteria:** Unit test suite passing; storage layout compatibility verified for upgrades.

### Phase 2: Reserve Attestation & Quorum Verification Mechanism
- **Focus:** Reserve Verifier contract development supporting multi-attestor threshold signature validation and automated heartbeat timeouts.
- **Exit Criteria:** Simulated attester quorum tests passing, fail-closed verification on stale or contradictory data.

### Phase 3: Backend, Custody, Redemption & Compliance Integration
- **Focus:** Backend orchestrator, HSM key signing infrastructure, custodian balance aggregation, automated sanctions webhooks, and asynchronous redemption reconciliation handling.
- **Exit Criteria:** End-to-end integration tests passing in staging environment.

### Phase 4: Comprehensive Validation, Testnet Staging & Audits
- **Focus:** Executing a multi-layered security validation strategy beyond basic code coverage:
  - **Unit & Negative Tests:** Edge-case authorization and parameter validation.
  - **Invariant & Fuzz Testing:** Stateful property testing enforcing `totalSupply <= eligibleReserves`.
  - **Storage Layout & Upgrade Testing:** Differential storage layout verification for UUPS proxy upgrades.
  - **Formal Verification / Analysis:** Mathematical verification of core solvency logic.
  - **External Security Audits:** Formal code review by independent security firms and remediation of findings.
  - **TRON Testnet Deployment:** Live testnet deployment on Nile/Shasta.
- **Exit Criteria:** All high/medium audit findings resolved, green testnet operational trial.

### Phase 5: Governance Setup & Controlled Mainnet Launch
- **Focus:** Initialization of 3-of-5 Hardware Multisig and 48-hour Timelock Controller, mainnet deployment, TRONSCAN code verification, and controlled initial minting limits.
- **Mandatory Launch Readiness Gates:**
  1. **Reserve & Custody Readiness Gate:** Fully executed custody agreements and verified multi-attestor feeds.
  2. **Redemption Readiness Gate:** Operational non-atomic redemption workflow and reconciliation procedures tested.
  3. **Compliance / Legal Sign-off Gate:** Formal legal opinion on stablecoin structure and active sanctions webhooks.
  4. **Monitoring & Alerting Gate:** 24/7 real-time transaction monitoring and anomaly detection.
  5. **Key Management & Governance Gate:** 3-of-5 hardware multisig configured with 48h timelock.
  6. **Emergency Response Gate:** Drill-tested emergency pause procedures.
  7. **Controlled Issuance Limits Gate:** Strict initial minting caps enforced for monitoring period.

### Post-Launch: Secondary Market & DEX Integration
- **Focus:** Gradual expansion of minting limits based on operational evidence, followed by optional DEX liquidity provisioning (SunSwap pools).
- **Rule:** DEX integration is strictly post-launch and is **never** a prerequisite for mainnet deployment.
