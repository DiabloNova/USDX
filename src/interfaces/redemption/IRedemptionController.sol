// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IRedemptionController
 * @notice Interface for the USDX on-chain redemption state machine.
 */
interface IRedemptionController {
    enum State {
        None,
        Requested,
        Approved,
        Burned,
        PayoutPending,
        Paid,
        Failed,
        ReconciliationRequired
    }

    struct Redemption {
        bytes32 requestId;
        address account;
        uint256 amount;
        State state;
        uint64 createdAt;
        uint64 updatedAt;
        bytes32 payoutTxRef;
        string failureReason;
    }

    // --- Events ---
    event RedemptionRequested(bytes32 indexed requestId, address indexed account, uint256 amount);
    event RedemptionApproved(bytes32 indexed requestId, address indexed approver);
    event RedemptionBurned(bytes32 indexed requestId, address indexed account, uint256 amount);
    event RedemptionPayoutPending(bytes32 indexed requestId);
    event RedemptionPaid(bytes32 indexed requestId, bytes32 indexed payoutTxRef);
    event RedemptionFailed(bytes32 indexed requestId, string reason);
    event RedemptionReconciliationRequired(bytes32 indexed requestId, string reason);
    event RedemptionReconciliationResolved(bytes32 indexed requestId, State finalState, bytes32 payoutTxRef);

    // --- Errors ---
    error InvalidAmount();
    error InvalidAccount();
    error InvalidRequestId();
    error DuplicateRequest();
    error InvalidStateTransition(bytes32 requestId, State currentState, State expectedState);
    error DuplicatePayoutConfirmation(bytes32 requestId, bytes32 existingPayoutRef);
    error Unauthorized();
    error TransferOrBurnFailed();

    // --- External Functions ---
    function getRedemption(bytes32 requestId) external view returns (Redemption memory);
    function totalBurnedAmount() external view returns (uint256);
}
