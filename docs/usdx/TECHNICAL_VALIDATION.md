# USDX Technical Validation & Claim Classification Record

## 1. Executive Summary

This document evaluates technical claims and operational assumptions concerning TRON/TVM compatibility, Solidity versions, address formats, resource models (Energy/Bandwidth), deterministic deployment (`CREATE2`), OpenZeppelin contract libraries, contract verification on TRONSCAN, Chainlink Proof of Reserve availability, and SunSwap DEX integration.

Claims are classified according to five status categories:
- **Verified:** Supported by verified EVM/TVM specifications or empirical testing.
- **Partially Verified:** Valid under specific network configurations or compiler flags.
- **Unverified:** Requires live network testing on TRON Nile/Shasta/Mainnet or external partner validation.
- **Rejected / Incorrect:** Architecturally or technically invalid based on verified platform behavior.
- **Requires Legal or Domain-Expert Validation:** Operational, regulatory, or custodial claims requiring specialized non-engineering review.

---

## 2. Technical Claims Evaluation Matrix

| ID | Claim Subject | Status | Summary Findings & Evidence |
| :--- | :--- | :--- | :--- |
| **TVM-01** | **TRC-20 Compatibility** | **Verified** | TRC-20 standard specification mirrors ERC-20 (`totalSupply`, `balanceOf`, `transfer`, `approve`, `transferFrom`, `Transfer`, `Approval`). TRON TVM natively executes ERC-20 compliant bytecode. |
| **TVM-02** | **Solidity Baseline & EVM Target Version** | **Partially Verified** | Solidity `0.8.20` with `evm_version = "london"` is the project's conservative compilation baseline. This baseline avoids opcode compatibility issues on networks lacking EVM Shanghai features. Shanghai/`PUSH0` availability is network/hardfork dependent and serves as a compatibility gate rather than a permanent TVM limitation. |
| **TVM-03** | **Address Representation** | **Verified** | On-chain TVM bytecodes use 20-byte EVM addresses prefixed with `0x41` in raw TRON protocol bytes (21 bytes total). User-facing displays format these as Base58Check strings starting with 'T'. Off-chain tools and SDKs must translate between Base58Check and `0x41` hex formats. |
| **TVM-04** | **TRON Account Permissions / Native Multisig** | **Partially Verified** | TRON native account structure supports Multi-Signature (Owner, Witness, Active permissions). However, contract execution authority managed by a smart contract Timelock/Multisig (e.g. Gnosis-style contract multisig) operates at the contract layer, distinct from native TRON account permissions. |
| **TVM-05** | **Energy & Bandwidth Model** | **Verified** | Execution on TRON consumes Energy (smart contract CPU/storage execution) and Bandwidth (transaction byte size). Accounts pay for execution via staked TRX resource allowances or direct TRX burning. |
| **TVM-06** | **`feeLimit` Parameter** | **Verified** | TRON transactions require an explicit `feeLimit` parameter (in SUN, 1 TRX = 1,000,000 SUN) set on the transaction envelope to cap maximum TRX burned. If execution exceeds `feeLimit`, the transaction reverts with `OUT_OF_ENERGY`. |
| **TVM-07** | **Deterministic Deployment (`CREATE2`)** | **Partially Verified** | The `CREATE2` opcode is supported by TVM, and high-level Solidity salted deployment syntax (`new Contract{salt: ...}()`) remains portable. However, manual address calculations and deployment tooling must account for TRON's `0x41` address prefix and address derivation algorithm. |
| **TVM-08** | **OpenZeppelin Module Compatibility** | **Partially Verified** | OpenZeppelin contracts cannot be assumed to have blanket TRON compatibility. Pinned official tagged releases must be evaluated at the specific module level, compiled under project settings (`solc 0.8.20` + `london`), and verified on target TRON testnets. |
| **TVM-09** | **Contract Verification on TRONSCAN** | **Verified** | TRONSCAN supports contract source verification via API or Web UI, requiring single-file flattened source or standard JSON input matching exact compiler version, optimization runs, and EVM target. |
| **TVM-10** | **Chainlink Proof of Reserve (PoR)** | **Unverified** | Chainlink PoR native feed availability on TRON Mainnet is limited. Architecture relies on a primary Multi-Attestor Quorum model for reserve updates rather than assuming native Chainlink PoR feeds are available. |
| **TVM-11** | **SunSwap Architecture & DEX Sequencing** | **Partially Verified** | SunSwap (V1/V2/V3 forks of Uniswap) operates standard constant-product or concentrated liquidity pairs. DEX deployment is strictly post-launch and is NOT a prerequisite for USDX mainnet deployment. |
| **REG-01** | **Regulatory / Custodial Requirements** | **Requires Legal/Domain Validation** | Claims regarding specific fiat banking permissions, reserve asset eligibility, attestation frequency, and jurisdiction-specific stablecoin rules require formal legal opinion. |

---

## 3. Detailed Technical Analysis

### 3.1 Solidity Compiler, Baseline & EVM Hardfork Gates
- **Project Baseline:** Solidity `0.8.20` is the current compiler baseline for USDX development, with `evm_version = "london"` configured in `foundry.toml` as a conservative compilation baseline.
- **EVM Versioning & Compatibility:** Pinned compilation to `london` is a conservative default for toolchain safety and portability across TRON target environments; it is not an irreversible lifetime decision.
- **TVM Hardfork & `PUSH0` Availability:** The `PUSH0` opcode introduced in the EVM Shanghai specification (default in `solc` >= 0.8.20) is supported on TRON TVM versions that have enabled the corresponding network proposal/hardfork. However, because hardfork capabilities vary by network environment (e.g. local test harness, Nile testnet, Shasta testnet, or Mainnet), Shanghai/`PUSH0` availability must be treated as a network/hardfork compatibility gate. Target networks must be validated before updating the baseline compilation target beyond `london`.

### 3.2 Address Formatting & `CREATE2` Semantics
- **TRON Address Representation:** TRON uses its own address representation:
  - **On-chain / Protocol level:** 21-byte hex array prefixed with `0x41` (e.g., `0x41` followed by the 20-byte EVM address slice).
  - **User / Display level:** Base58Check format string beginning with `'T'` (e.g., `TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t`).
  - **Solidity level:** Standard 20-byte `address` type in smart contract code.
- **`CREATE2` Deterministic Deployment:**
  - High-level Solidity salted creation syntax (`new Contract{salt: salt}(...)`) remains portable across EVM and TVM.
  - Manual `CREATE2` address calculations (such as in-contract helper functions or off-chain SDKs/scripts) and deployment tooling must account for TRON's address generation algorithm (`0x41` prefix + keccak256 hash truncation) and cannot be assumed to match standard Ethereum address calculation tools in every context.

### 3.3 OpenZeppelin Library Integration
- **No Blanket Compatibility:** Blanket compatibility with OpenZeppelin contract libraries cannot be assumed for TRON/TVM environments.
- **Validation Requirements:**
  1. **Tagged Releases:** Projects must use official tagged releases of OpenZeppelin Contracts.
  2. **Compilation Baseline Verification:** Selected contract modules (e.g., `AccessControl`, `Pausable`, `ReentrancyGuard`) must compile cleanly with the project's baseline compiler (`solc 0.8.20`) and target EVM version (`london`).
  3. **Module-Level Evaluation:** Compatibility must be demonstrated at the individual module and dependency version level, rather than asserted for the library as a whole.
  4. **Target Testnet Validation:** Critical modules must undergo functional and deployment testing on the target TRON testnet (Nile/Shasta) prior to production deployment.

### 3.4 Execution Resources & Transaction Costs
- **Energy:** Quantifies CPU and storage execution required by smart contract instructions.
- **Bandwidth:** Quantifies transaction data footprint in bytes.
- **Resource Acquisition:** Accounts cover execution costs using daily free Bandwidth, Bandwidth/Energy allowances obtained by staking TRX, or by burning TRX directly.
- **`feeLimit` Parameter:** Every TRON transaction envelope includes an explicit `feeLimit` parameter in SUN (1 TRX = 1,000,000 SUN). It caps the maximum TRX an account can burn for energy/bandwidth consumption. If execution exceeds `feeLimit` before completion, the transaction reverts with `OUT_OF_ENERGY` while consuming fees up to the limit.

---

## 4. Unresolved Technical & Domain Decisions

1. **Target Network Shanghai Verification:** Confirm active parameters on TRON Nile and Mainnet nodes prior to Phase 1 contract compilation finalizing EVM target flags.
2. **Attestor Quorum Key Management:** Selection of signature aggregation scheme (e.g., threshold Schnorr vs. ECDSA array verification) for the Reserve Verifier contract.
3. **Legal / Regulatory Framework:** Qualification of eligible reserve asset composition (cash deposits vs. short-term US Treasury bills) by qualified legal counsel.
