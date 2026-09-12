# USDX Architectural Decision Records (ADRs) & Assumption Register

## 1. Context & Scope

This document records the confirmed Architectural Decision Records (ADRs) established for the USDX stablecoin protocol, alongside an explicit register of items deferred to subsequent phases.

---

## 2. Confirmed Architectural Decision Records (ADRs)

### ADR-01: Smart Contract Toolchain Selection
- **Status:** Approved
- **Decision:** Select **Foundry** (`forge`, `cast`) as the primary smart-contract compilation and testing framework.
- **Rationale:** Foundry provides fast compilation, native Solidity testing, gas profiling, and EVM target configuration capabilities.

### ADR-02: Compiler & EVM Target Baseline (`solc 0.8.20`, `london`)
- **Status:** Approved
- **Decision:** Pin `solc_version = "0.8.20"` with `evm_version = "london"` as the current project baseline in `foundry.toml`.
- **Rationale:** `solc 0.8.20` provides modern compiler features. Pinning `london` EVM target avoids bytecode containing unsupported opcodes (such as `PUSH0`) on TRON networks where Shanghai features are not active.
- **Consequences:** `solc 0.8.20` is the Phase 0 compatibility baseline, not an irreversible lifetime decision. EVM target updates require live network parameter verification.

### ADR-03: Token Standard & Decimals
- **Status:** Approved
- **Decision:** Standard **TRC-20** token interface with **6 decimal places** and an initial supply of **zero**.
- **Rationale:** 6 decimals aligns with TRON USDT/USDC conventions and prevents rounding discrepancies during USD fiat conversions (1 cent = 10,000 base units).

### ADR-04: Hard On-Chain Solvency Invariant
- **Status:** Approved
- **Decision:** The core token contract must enforce `totalSupply + amount <= eligibleReserves` on every mint call.
- **Rationale:** Guarantees that token supply cannot exceed accepted reserve attestations recorded on-chain.
- **Note:** The on-chain invariant protects supply against the accepted attested reserve value; it does not independently verify underlying off-chain bank balances.

### ADR-05: Multi-Attestor Quorum Reserve Attestation
- **Status:** Approved
- **Decision:** Adopt a multi-attestor threshold quorum model (e.g., 2-of-3 attesters) for updating on-chain `eligibleReserves`.
- **Rationale:** Prevents any single off-chain entity or compromised key from unilaterally inflating reserve limits. Requires freshness heartbeats and fails closed when data is stale or invalid.

### ADR-06: 3-of-5 Multisig Governance & Timelock
- **Status:** Approved
- **Decision:** Production governance uses a **3-of-5 Hardware Multisig** linked to a **48-hour Timelock Controller**.
- **Rationale:** Isolates administrative authority, prevents single-key compromise vulnerabilities, and mandates public execution delay for all privileged configuration changes.

### ADR-07: UUPS Upgradeability Pattern
- **Status:** Approved
- **Decision:** Adopt **UUPS (Universal Upgradeable Proxy Standard)** for production contracts.
- **Rationale:** Separates proxy state from implementation logic, reduces gas overhead compared to Transparent Proxies, and restricts upgrade authorization to governance behind the timelock.

### ADR-08: Mandatory Blacklist / Freeze Compliance Capability
- **Status:** Approved
- **Decision:** USDX must incorporate protocol-level `blacklist` / `freeze` controls to restrict sanctioned addresses.
- **Rationale:** Required to fulfill legal and regulatory compliance obligations (e.g., OFAC sanctions enforcement).
- **Distinction:** Technical capability is fixed by protocol design; specific asset seizure policies require legal counsel input.

### ADR-09: Fail-Closed Emergency Controls
- **Status:** Approved
- **Decision:** Implement an `EmergencyController` role authorized strictly to invoke `pause()` and freeze blacklisted accounts.
- **Rationale:** Enables rapid response to exploits or legal mandates without granting emergency keys any minting, transfer, or upgrade authority.

### ADR-10: Asynchronous Redemption State Machine
- **Status:** Approved
- **Decision:** Model redemptions as a non-atomic cross-system state machine (`Requested -> Approved -> Burned -> Payout Pending -> Paid`).
- **Rationale:** On-chain token burning and off-chain fiat wire disbursement cannot occur in a single atomic blockchain transaction. Explicit failure and reconciliation states guarantee accounting integrity.

### ADR-11: Post-Launch DEX Sequencing
- **Status:** Approved
- **Decision:** Secondary market DEX liquidity (e.g., SunSwap) is strictly post-launch and is **NOT** a prerequisite for mainnet launch.
- **Rationale:** Core protocol launch focuses on primary mint/burn stability, reserve attestation, and regulatory compliance. DEX liquidity pools are external to protocol solvency.

---

## 3. Register of Items Requiring Implementation Validation

| ID | Item Subject | Category | Description / Next Steps |
| :--- | :--- | :--- | :--- |
| **VAL-01** | **Target Network Shanghai Verification** | Technical | Verify active TVM parameters on TRON Nile and Mainnet before finalizing Phase 1 compilation EVM target flags. |
| **VAL-02** | **Storage Layout Testing Tools** | Testing | Select and integrate Foundry storage layout check plugins for UUPS upgrade safety verification. |
| **VAL-03** | **Custodial Banking API Specifications** | Operations | Define exact JSON schema and payload format for multi-attestor bank balance feeds in Phase 3. |
