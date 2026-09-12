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
| **TVM-02** | **Solidity 0.8.20 & EVM Target Baseline** | **Partially Verified** | `solc 0.8.20` is the current Phase 0 baseline compiler version, not an irreversible lifetime decision. The `PUSH0` instruction was added to TVM via TRON's Shanghai hardfork gate (TIP-572 / GreatVoyage-v4.7.4). However, `evm_version = "london"` remains the pinned project compatibility baseline to ensure maximum safety across all testnet/mainnet node configurations until target network parameters are verified. |
| **TVM-03** | **Address Representation (`0x41` Prefix)** | **Verified** | On-chain TVM bytecodes use 20-byte EVM addresses prefixed with `0x41` in raw bytes (21 bytes total). User-facing displays format these as Base58Check strings starting with 'T'. Off-chain tools must translate between Base58 and `0x41` hex formats. |
| **TVM-04** | **TRON Account Permissions / Native Multisig** | **Partially Verified** | TRON native account structure supports Multi-Signature (Owner, Witness, Active permissions). Contract execution authority managed by a smart contract Timelock/Multisig operates at the contract layer, distinct from native TRON account permissions. |
| **TVM-05** | **Energy & Bandwidth Model** | **Verified** | Execution on TRON consumes Energy (smart contract CPU/storage) and Bandwidth (transaction byte size). Callers or fee limiters must stake TRX or rent Energy to avoid consuming liquid TRX or encountering `OUT_OF_ENERGY` errors. |
| **TVM-06** | **`feeLimit` Parameter** | **Verified** | TRON transactions require an explicit `feeLimit` parameter (in SUN, 1 TRX = 1,000,000 SUN) set on the transaction envelope. If `feeLimit` is set too low for complex contract calls, the transaction reverts with `OUT_OF_ENERGY`. |
| **TVM-07** | **Deterministic Deployment (`CREATE2`)** | **Partially Verified** | `CREATE2` opcode is supported by TVM. High-level Solidity salted deployment is portable, but off-chain address calculation tools, scripts, and assumptions must account for TRON's `0x41` address representation prefix. `CREATE2` is not identical to Ethereum in every tooling context. |
| **TVM-08** | **OpenZeppelin Compatibility** | **Partially Verified** | OpenZeppelin Contracts cannot be treated as blanket-verified for TRON. USDX must use official tagged releases (e.g., v4.9 / v5.x). Each required module (AccessControl, Pausable, UUPSUpgradeable) must be validated at the exact version/module level and tested on TRON testnets. |
| **TVM-09** | **Contract Verification on TRONSCAN** | **Verified** | TRONSCAN supports contract source verification via API or Web UI, requiring single-file flattened source or standard JSON input matching exact compiler version, optimization runs, and EVM target. |
| **TVM-10** | **Chainlink Proof of Reserve (PoR)** | **Unverified** | Chainlink PoR native feed availability on TRON Mainnet is limited. Architecture relies on a primary Multi-Attestor Quorum model for reserve updates rather than assuming native Chainlink PoR feeds are available. |
| **TVM-11** | **SunSwap Architecture & DEX Sequencing** | **Partially Verified** | SunSwap (V1/V2/V3 forks of Uniswap) operates standard constant-product or concentrated liquidity pairs. DEX deployment is strictly post-launch and is NOT a prerequisite for USDX mainnet deployment. |
| **REG-01** | **Regulatory / Custodial Requirements** | **Requires Legal/Domain Validation** | Claims regarding specific fiat banking permissions, reserve asset eligibility, attestation frequency, and jurisdiction-specific stablecoin rules require formal legal opinion. |

---

## 3. Detailed Technical Analysis

### 3.1 Solidity Compiler & TVM Shanghai / `PUSH0` Opcodes
- **Background:** `solc 0.8.20` introduced `PUSH0` as part of the `shanghai` EVM specification.
- **TVM Capability:** Recent TRON protocol upgrades introduced Shanghai EVM features (including `PUSH0` support via TIP-572 / GreatVoyage-v4.7.4). However, `PUSH0` availability is network-specific and depends on active chain parameters of the target deployment node/network.
- **Project Policy:** `solc 0.8.20` is selected as the current baseline. To guarantee execution safety across all TRON environments, `evm_version = "london"` remains pinned in project configuration. Changing EVM targets requires explicit verification against active target testnet/mainnet node parameters.

### 3.2 Address Representation & `CREATE2` Semantics
- **TRON Address Bytes:** On-chain TVM bytecodes prepend `0x41` (TRON mainnet/testnet network byte) to 20-byte EVM addresses.
- **`CREATE2` Tooling:** While high-level Solidity `new Contract{salt: salt}()` statements function natively in TVM, manual off-chain `CREATE2` address derivation (e.g., in deployment scripts or SDKs) must incorporate the `0x41` prefix into address slicing logic.

### 3.3 OpenZeppelin Module & Version Strategy
- OpenZeppelin Contracts do not come with an official blanket TRON compatibility guarantee.
- **Strategy:**
  1. Pin dependencies strictly to official tagged releases.
  2. Test every imported module (e.g., `UUPSUpgradeable`, `AccessControlEnumerable`, `Pausable`) against solc 0.8.20 with `london` EVM target.
  3. Perform full deployment and integration testing on TRON Nile testnet prior to mainnet deployment.

---

## 4. Unresolved Technical & Domain Decisions

1. **Target Network Shanghai Verification:** Confirm active parameters on TRON Nile and Mainnet nodes prior to Phase 1 contract compilation finalizing EVM target flags.
2. **Attestor Quorum Key Management:** Selection of signature aggregation scheme (e.g., threshold Schnorr vs. ECDSA array verification) for the Reserve Verifier contract.
3. **Legal / Regulatory Framework:** Qualification of eligible reserve asset composition (cash deposits vs. short-term US Treasury bills) by qualified legal counsel.
