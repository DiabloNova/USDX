// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IReserveAttestation
 * @notice Interface for the off-chain reserve attestation oracle boundary.
 * @dev Accepted reserve balances are established exclusively via an external multi-attestor
 * quorum mechanism. No single arbitrary caller or mint controller is permitted to inject or
 * increase accepted reserve values directly.
 *
 * Core Financial Invariant Enforced On-Chain:
 *   totalSupply <= eligibleReserves
 */
interface IReserveAttestation {
    /**
     * @notice Struct representing accepted reserve attestation status and balance.
     * @param amount The accepted eligible reserve amount in 6 decimal places (1 USD = 1,000,000 units).
     * @param timestamp The block timestamp when the latest attestation payload was accepted on-chain.
     * @param isAvailable True if reserve attestation data is available and valid; false if unavailable.
     * @param isStale True if reserve attestation data has exceeded its heartbeat validity window.
     */
    struct ReserveData {
        uint256 amount;
        uint256 timestamp;
        bool isAvailable;
        bool isStale;
    }

    /**
     * @notice Retrieves the current accepted eligible reserve state.
     * @dev Calling contracts MUST reject reserve data if `isAvailable` is false or `isStale` is true,
     * or if the call reverts, implementing fail-closed behavior.
     * @return data The current `ReserveData` record.
     */
    function getAcceptedEligibleReserves() external view returns (ReserveData memory data);
}
