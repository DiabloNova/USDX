# USDX Stablecoin — Phase 0 Foundation

## Overview

**USDX** is a fiat-backed stablecoin engineered for the TRON blockchain (TRC-20 standard). Designed with 6 decimal places and a 1:1 USD reserve backing target, USDX incorporates strict financial invariants to ensure circulating supply never exceeds accepted eligible fiat reserves held in audited custodian bank accounts.

This repository represents **Phase 0: Architecture, Technical Validation, Security Modeling, and Baseline Foundation**. In accordance with Phase 0 requirements, no production smart contracts, backend services, or mainnet infrastructure are implemented in this phase.

---

## Directory Structure

```
.
├── .gitignore                      # Git ignore rules for Foundry build artifacts & logs
├── foundry.toml                    # Smart contract toolchain config (solc 0.8.20, EVM london)
├── README.md                       # Project overview and directory guide
├── docs/
│   └── usdx/
│       ├── ARCHITECTURE.md         # System architecture, trust boundaries, lifecycles, and invariants
│       ├── DECISIONS.md            # Architectural Decision Records (ADRs) & assumption register
│       ├── ROADMAP.md              # Multi-phase implementation roadmap & readiness gates
│       ├── TECHNICAL_VALIDATION.md # TRON/TVM compatibility claims & evidence matrix
│       └── THREAT_MODEL.md         # Comprehensive security threat analysis & 5-domain control mapping
├── src/
│   └── scaffold/
│       └── ScaffoldCounter.sol     # Toolchain validation scaffold contract (non-production)
└── test/
    └── scaffold/
        └── ScaffoldCounter.t.sol   # Toolchain validation smoke test
```

---

## Documentation Map

- **[Architecture & Lifecycles (`docs/usdx/ARCHITECTURE.md`)](docs/usdx/ARCHITECTURE.md):** Defines core financial invariants (`totalSupply <= eligibleReserves`), trust boundaries, multi-attestor quorum attestation, non-atomic redemption state machine, UUPS upgradeability + 3-of-5 multisig governance, and post-launch DEX sequencing.
- **[Technical Validation (`docs/usdx/TECHNICAL_VALIDATION.md`)](docs/usdx/TECHNICAL_VALIDATION.md):** Analyzes TRON/TVM compatibility, `solc 0.8.20` / `london` target baseline, TVM Shanghai hardfork gates (`PUSH0`), `0x41` address formatting for `CREATE2`, Energy/Bandwidth model, `feeLimit`, and OpenZeppelin module-level testing requirements.
- **[Threat Model & Security Controls (`docs/usdx/THREAT_MODEL.md`)](docs/usdx/THREAT_MODEL.md):** Details 10 threat vectors categorized across Protocol-Enforced, Reserve-Attestation, Operational, Custodian, and Compliance security control domains.
- **[Architectural Decisions (`docs/usdx/DECISIONS.md`)](docs/usdx/DECISIONS.md):** Records 11 confirmed ADRs and tracks items requiring implementation-level validation.
- **[Implementation Roadmap & Gates (`docs/usdx/ROADMAP.md`)](docs/usdx/ROADMAP.md):** Outlines the multi-phase path, multi-layered security testing strategy, and mandatory launch readiness gates.

---

## Toolchain & Verification

### Prerequisites
- [Foundry](https://book.getfoundry.sh/) (`forge` v1.8.1 or compatible)

### Execution Commands

To build the toolchain scaffold:
```bash
forge build
```

To run the foundation toolchain smoke tests:
```bash
forge test
```

### TVM Compatibility Configuration
Foundry configuration (`foundry.toml`) explicitly pins compiler settings for TRON Virtual Machine (TVM) execution safety:
- **Solidity Version:** `0.8.20` (Phase 0 baseline)
- **EVM Target Version:** `london` (ensures safety across all TRON node configurations)
