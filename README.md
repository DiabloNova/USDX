# USDX Stablecoin — Phase 0 Foundation

## Overview

**USDX** is a proposed fiat-backed stablecoin engineered for the TRON blockchain (TRC-20 standard). Designed with 6 decimal places and a 1:1 USD reserve backing target, USDX incorporates strict financial invariants to ensure circulating supply never exceeds eligible fiat reserves held in audited custodian bank accounts.

This repository represents **Phase 0: Architecture, Technical Validation, Security Modeling, and Toolchain Foundation**. In accordance with Phase 0 requirements, no production smart contracts, backend services, or mainnet infrastructure are implemented in this phase.

---

## Directory Structure

```
.
├── .gitignore                      # Git ignore rules for Foundry build artifacts & logs
├── foundry.toml                    # Smart contract toolchain config (solc 0.8.20, EVM london)
├── README.md                       # Project overview and directory guide
├── docs/
│   └── usdx/
│       ├── ARCHITECTURE.md         # System architecture, trust boundaries, and invariants
│       ├── DECISIONS.md            # Architectural Decision Records (ADRs) & unresolved items
│       ├── ROADMAP.md              # Multi-phase implementation roadmap
│       ├── TECHNICAL_VALIDATION.md # TRON/TVM compatibility claims & evidence matrix
│       └── THREAT_MODEL.md         # Comprehensive security threat analysis & controls mapping
├── src/
│   └── scaffold/
│       └── ScaffoldCounter.sol     # Toolchain validation scaffold contract (non-production)
└── test/
    └── scaffold/
        └── ScaffoldCounter.t.sol   # Toolchain validation smoke test
```

---

## Documentation Map

- **[Architecture & Lifecycles (`docs/usdx/ARCHITECTURE.md`)](docs/usdx/ARCHITECTURE.md):** Defines core financial invariants (`totalSupply <= eligibleReserves`), trust boundaries, mint/burn lifecycles, and governance separation.
- **[Technical Validation (`docs/usdx/TECHNICAL_VALIDATION.md`)](docs/usdx/TECHNICAL_VALIDATION.md):** Analyzes TRON/TVM compatibility, `solc` versioning (`PUSH0` restriction), `0x41` address formatting, Energy/Bandwidth resource model, `feeLimit`, `CREATE2`, and OpenZeppelin compatibility.
- **[Threat Model & Security Controls (`docs/usdx/THREAT_MODEL.md`)](docs/usdx/THREAT_MODEL.md):** Details 10 threat vectors across On-Chain, Off-Chain, Operational, Custodian, and Compliance security control domains.
- **[Architectural Decisions & Assumptions (`docs/usdx/DECISIONS.md`)](docs/usdx/DECISIONS.md):** Records formal ADRs and tracks unresolved technical and legal assumptions.
- **[Implementation Roadmap (`docs/usdx/ROADMAP.md`)](docs/usdx/ROADMAP.md):** Outlines the multi-phase path from smart contract development to testnet staging and mainnet launch.

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
- **Solidity Version:** `0.8.20`
- **EVM Target Version:** `london` (prevents unsupported `PUSH0` opcode generation default in `shanghai`)
