# USDX Technical Validation & Claim Classification Record

## 1. Executive Summary

This document evaluates the technical claims and operational assumptions concerning TRON/TVM compatibility, Solidity versions, address formats, native TRON account permissions, resource models (Energy/Bandwidth), deterministic deployment (`CREATE2`), OpenZeppelin contract libraries, contract verification on TRONSCAN, Chainlink Proof of Reserve availability, and SunSwap DEX integration.

Claims are classified according to five status categories:
- **Verified:** Supported by verified EVM/TVM specifications or empirical testing.
- **Partially Verified:** Valid under specific conditions or configuration flags.
- **Unverified:** Requires live network testing on TRON Nile/Shasta/Mainnet or external partner validation.
- **Rejected / Incorrect:** Mathematically or architecturally invalid based on verified platform behavior.
- **Requires Legal or Domain-Expert Validation:** Operational, regulatory, or custodial claims requiring specialized non-engineering review.

---

## 2. Technical Claims Evaluation Matrix

| ID | Claim Subject | Status | Summary Findings & Evidence |
| :--- | :--- | :--- | :--- |
| **TVM-01** | **TRC-20 Compatibility** | **Verified** | TRC-20 standard specification mirrors ERC-20 (`totalSupply`, `balanceOf`, `transfer`, `approve`, `transferFrom`, `Transfer`, `Approval`). TRON TVM natively executes ERC-20 compliant bytecode. |
| **TVM-02** | **Solidity 0.8.x & EVM Version Support** | **Partially Verified** | TVM supports Solidity 0.8.x syntax, but compiler settings MUST restrict `evm_version` to `london` or `paris`. The `PUSH0` instruction introduced in EVM version `shanghai` (solc >= 0.8.20 default) is NOT supported by TVM and will cause deployment failure. |
| **TVM-03** | **Address Representation** | **Verified** | On-chain TVM bytecodes use 20-byte EVM addresses prefixed with `0x41` in raw bytes (21 bytes total). User-facing displays format these as Base58Check strings starting with 'T'. Off-chain tools must translate between Base58 and `0x41` hex formats. |
| **TVM-04** | **TRON Account Permissions / Native Multisig** | **Partially Verified** | TRON native account structure supports Multi-Signature (Owner, Witness, Active permissions). However, contract execution authority managed by a smart contract Timelock/Multisig (e.g. Gnosis-style contract multisig) operates at the contract layer, distinct from native TRON account permissions. |
| **TVM-05** | **Energy & Bandwidth Model** | **Verified** | Execution on TRON consumes Energy (smart contract CPU/storage) and Bandwidth (transaction byte size). Callers or fee limiters must stake TRX or rent Energy to avoid consuming liquid TRX or encountering `OUT_OF_ENERGY` errors. |
| **TVM-06** | **`feeLimit` Parameter** | **Verified** | TRON transactions require an explicit `feeLimit` parameter (in SUN, 1 TRX = 1,000,000 SUN) set on the transaction envelope. If `feeLimit` is set too low for complex contract calls, the transaction reverts with `OUT_OF_ENERGY`. |
| **TVM-07** | **Deterministic Deployment (`CREATE2`)** | **Partially Verified** | `CREATE2` opcode is supported by TVM, but deterministic address calculation uses TRON's address generation algorithm (`0x41` prefix + keccak256 hash slice). standard EVM `CREATE2` address calculation tools must be adapted for TRON address formats. |
| **TVM-08** | **OpenZeppelin Compatibility** | **Partially Verified** | OpenZeppelin v4.x / v5.x contracts (AccessControl, Pausable, ReentrancyGuard) can be compiled for TVM provided `evm_version` is constrained to `london` and EVM-specific precompiles/builtins are avoided. |
| **TVM-09** | **Contract Verification on TRONSCAN** | **Verified** | TRONSCAN supports contract source verification via API or Web UI, requiring single-file flattened source or standard JSON input matching exact compiler version, optimization runs, and EVM target. |
| **TVM-10** | **Chainlink Proof of Reserve (PoR)** | **Unverified** | Chainlink PoR native feed availability on TRON Mainnet is limited compared to Ethereum. Architecture must support fallback signature attestation mechanisms if native Chainlink PoR feeds are unavailable on TRON. |
| **TVM-11** | **SunSwap Architecture & Integration** | **Unverified** | SunSwap (V1/V2/V3 forks of Uniswap) operates standard constant-product or concentrated liquidity pairs. Token integration requires standard TRC-20 transfer compatibility without fee-on-transfer hooks or unexpected gas traps. |
| **REG-01** | **Regulatory / Custodial Requirements** | **Requires Legal/Domain Validation** | Claims regarding specific fiat banking permissions, reserve asset eligibility (e.g., Short-term Treasuries vs Cash), attestation frequency, and jurisdiction-specific stablecoin rules require formal legal opinion. |

---

## 3. Detailed Technical Analysis

### 3.1 Solidity Compiler & TVM Opcodes (`PUSH0` Risk)
- **Issue:** Solidity compiler version `0.8.20` introduced the `PUSH0` opcode as part of the `shanghai` EVM specification.
- **TVM Limitation:** TRON Virtual Machine does not currently support `PUSH0`. Compiling contracts with default `solc 0.8.20+` settings targeting `shanghai` results in invalid opcode deployment failures on TRON networks.
- **Resolution:** All USDX Foundry toolchain configurations must explicitly pin `evm_version = "london"` (or `"paris"`).

### 3.2 Address Formatting (`0x41` vs Base58Check)
- **TRON Native Format:** Base58Check string (e.g., `TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t` for USDT).
- **TVM Internal Format:** 21-byte hex array starting with `0x41` (e.g., `41a61741a292f790115235e6100aa72241...`), or standard 20-byte EVM address slice `0xa61741a2...`.
- **Engineering Rule:** Smart contract interfaces receive and process 20-byte EVM addresses (`address` type in Solidity). Conversion to Base58Check is strictly an off-chain presentation / client SDK responsibility.

### 3.3 Resource Consumption & Transaction Execution Costs
- **Energy:** Smart contract instruction execution consumes Energy.
- **Bandwidth:** Transaction payload size consumes Bandwidth (free daily allowance per account or staked TRX).
- **Fee Limit:** Maximum SUN allowance specified in transactions (e.g., `100_000_000 SUN` = 100 TRX). Complex transactions (such as multisig executions or batch minting) must estimate Energy usage accurately to prevent `OUT_OF_ENERGY` failure while burning fee limits.

---

## 4. Unresolved Technical & Domain Decisions

1. **Oracle Deployment on TRON:** Whether to rely on Chainlink PoR or deploy a custom Threshold Ed25519 / ECDSA signature verifier contract for reserve attestation.
2. **On-Chain Timelock Architecture:** Selection between OpenZeppelin `TimelockController` modified for TVM vs. a custom multisig execution delay contract.
3. **Legal / Regulatory Framework:** Clarification of eligible reserve assets and audit frequency mandated by target regulatory jurisdictions.
