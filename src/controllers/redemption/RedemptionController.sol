// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../interfaces/redemption/IRedemptionController.sol";
import "../../interfaces/redemption/IUSDXRedeemableToken.sol";

/**
 * @title RedemptionController
 * @notice On-chain state machine for USDX redemption processing.
 * @dev Manages the non-atomic lifecycle of USDX redemption:
 *      Requested -> Approved -> Burned -> PayoutPending -> Paid / Failed / ReconciliationRequired
 */
contract RedemptionController is IRedemptionController {
    // --- Roles ---
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant REQUESTER_ROLE = keccak256("REQUESTER_ROLE");
    bytes32 public constant APPROVER_ROLE = keccak256("APPROVER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAYOUT_OPERATOR_ROLE = keccak256("PAYOUT_OPERATOR_ROLE");
    bytes32 public constant RECONCILER_ROLE = keccak256("RECONCILER_ROLE");

    // --- State Variables ---
    IUSDXRedeemableToken public immutable token;
    uint256 public override totalBurnedAmount;

    mapping(bytes32 => Redemption) private _redemptions;
    mapping(bytes32 => mapping(address => bool)) private _roles;

    // --- Events for Access Control ---
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    // --- Modifiers ---
    modifier onlyRole(bytes32 role) {
        if (!_roles[role][msg.sender]) {
            revert Unauthorized();
        }
        _;
    }

    constructor(address _token, address _admin) {
        if (_token == address(0) || _admin == address(0)) {
            revert InvalidAccount();
        }
        token = IUSDXRedeemableToken(_token);
        _grantRole(ADMIN_ROLE, _admin);
    }

    // --- Role Management ---
    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        if (account == address(0)) revert InvalidAccount();
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        _roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    function _grantRole(bytes32 role, address account) internal {
        _roles[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    // --- Redemption State Machine ---

    /**
     * @notice Initiates a redemption request for a bound account and amount.
     * @param requestId Unique identifier for the redemption request.
     * @param account Target wallet account from which USDX will be redeemed/burned.
     * @param amount Amount of USDX to redeem (6 decimal precision).
     */
    function requestRedemption(
        bytes32 requestId,
        address account,
        uint256 amount
    ) external onlyRole(REQUESTER_ROLE) {
        if (requestId == bytes32(0)) revert InvalidRequestId();
        if (account == address(0)) revert InvalidAccount();
        if (amount == 0) revert InvalidAmount();
        if (_redemptions[requestId].state != State.None) revert DuplicateRequest();

        _redemptions[requestId] = Redemption({
            requestId: requestId,
            account: account,
            amount: amount,
            state: State.Requested,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp),
            payoutTxRef: bytes32(0),
            failureReason: ""
        });

        emit RedemptionRequested(requestId, account, amount);
    }

    /**
     * @notice Approves a pending redemption request after compliance and eligibility verification.
     * @param requestId Unique identifier for the redemption request.
     */
    function approveRedemption(bytes32 requestId) external onlyRole(APPROVER_ROLE) {
        Redemption storage redemption = _redemptions[requestId];
        if (redemption.state != State.Requested) {
            revert InvalidStateTransition(requestId, redemption.state, State.Requested);
        }

        redemption.state = State.Approved;
        redemption.updatedAt = uint64(block.timestamp);

        emit RedemptionApproved(requestId, msg.sender);
    }

    /**
     * @notice Executes on-chain USDX token burn for an approved redemption request.
     * @param requestId Unique identifier for the redemption request.
     */
    function burnRedemption(bytes32 requestId) external onlyRole(BURNER_ROLE) {
        Redemption storage redemption = _redemptions[requestId];
        if (redemption.state != State.Approved) {
            revert InvalidStateTransition(requestId, redemption.state, State.Approved);
        }

        redemption.state = State.Burned;
        redemption.updatedAt = uint64(block.timestamp);
        totalBurnedAmount += redemption.amount;

        emit RedemptionBurned(requestId, redemption.account, redemption.amount);

        // Execute token burn through interface
        token.burnFrom(redemption.account, redemption.amount);
    }

    /**
     * @notice Marks a burned redemption as PayoutPending prior to off-chain bank wire dispatch.
     * @param requestId Unique identifier for the redemption request.
     */
    function markPayoutPending(bytes32 requestId) external onlyRole(PAYOUT_OPERATOR_ROLE) {
        Redemption storage redemption = _redemptions[requestId];
        if (redemption.state != State.Burned) {
            revert InvalidStateTransition(requestId, redemption.state, State.Burned);
        }

        redemption.state = State.PayoutPending;
        redemption.updatedAt = uint64(block.timestamp);

        emit RedemptionPayoutPending(requestId);
    }

    /**
     * @notice Records fiat payout completion with banking transaction reference.
     * @param requestId Unique identifier for the redemption request.
     * @param payoutTxRef Off-chain fiat wire transaction identifier/hash reference.
     */
    function confirmPayout(
        bytes32 requestId,
        bytes32 payoutTxRef
    ) external onlyRole(PAYOUT_OPERATOR_ROLE) {
        if (payoutTxRef == bytes32(0)) revert InvalidRequestId();

        Redemption storage redemption = _redemptions[requestId];
        if (redemption.state != State.PayoutPending) {
            revert InvalidStateTransition(requestId, redemption.state, State.PayoutPending);
        }

        if (redemption.payoutTxRef != bytes32(0)) {
            revert DuplicatePayoutConfirmation(requestId, redemption.payoutTxRef);
        }

        redemption.state = State.Paid;
        redemption.payoutTxRef = payoutTxRef;
        redemption.updatedAt = uint64(block.timestamp);

        emit RedemptionPaid(requestId, payoutTxRef);
    }

    /**
     * @notice Marks a redemption payout as failed due to bank transfer rejection or error.
     * @param requestId Unique identifier for the redemption request.
     * @param reason Description of why payout failed.
     */
    function markPayoutFailed(
        bytes32 requestId,
        string calldata reason
    ) external {
        if (!hasRole(PAYOUT_OPERATOR_ROLE, msg.sender) && !hasRole(RECONCILER_ROLE, msg.sender)) {
            revert Unauthorized();
        }

        Redemption storage redemption = _redemptions[requestId];
        if (redemption.state != State.PayoutPending && redemption.state != State.Burned) {
            revert InvalidStateTransition(requestId, redemption.state, State.PayoutPending);
        }

        redemption.state = State.Failed;
        redemption.failureReason = reason;
        redemption.updatedAt = uint64(block.timestamp);

        emit RedemptionFailed(requestId, reason);
    }

    /**
     * @notice Flags a failed or stuck redemption for manual financial reconciliation.
     * @param requestId Unique identifier for the redemption request.
     * @param reason Detail for reconciliation trigger.
     */
    function flagForReconciliation(
        bytes32 requestId,
        string calldata reason
    ) external onlyRole(RECONCILER_ROLE) {
        Redemption storage redemption = _redemptions[requestId];
        if (redemption.state != State.Failed && redemption.state != State.PayoutPending) {
            revert InvalidStateTransition(requestId, redemption.state, State.Failed);
        }

        redemption.state = State.ReconciliationRequired;
        redemption.failureReason = reason;
        redemption.updatedAt = uint64(block.timestamp);

        emit RedemptionReconciliationRequired(requestId, reason);
    }

    /**
     * @notice Resolves a pending reconciliation, transitioning to Paid or Failed state.
     * @param requestId Unique identifier for the redemption request.
     * @param resolvedAsPaid True if fiat wire was successfully confirmed, false if permanently failed.
     * @param payoutTxRef Fiat transaction reference if resolved as Paid (must be non-zero if resolvedAsPaid).
     * @param reason Failure explanation if resolved as Failed.
     */
    function resolveReconciliation(
        bytes32 requestId,
        bool resolvedAsPaid,
        bytes32 payoutTxRef,
        string calldata reason
    ) external onlyRole(RECONCILER_ROLE) {
        Redemption storage redemption = _redemptions[requestId];
        if (redemption.state != State.ReconciliationRequired) {
            revert InvalidStateTransition(requestId, redemption.state, State.ReconciliationRequired);
        }

        if (resolvedAsPaid) {
            if (payoutTxRef == bytes32(0)) revert InvalidRequestId();
            if (redemption.payoutTxRef != bytes32(0)) {
                revert DuplicatePayoutConfirmation(requestId, redemption.payoutTxRef);
            }

            redemption.state = State.Paid;
            redemption.payoutTxRef = payoutTxRef;
            redemption.updatedAt = uint64(block.timestamp);

            emit RedemptionPaid(requestId, payoutTxRef);
            emit RedemptionReconciliationResolved(requestId, State.Paid, payoutTxRef);
        } else {
            redemption.state = State.Failed;
            redemption.failureReason = reason;
            redemption.updatedAt = uint64(block.timestamp);

            emit RedemptionFailed(requestId, reason);
            emit RedemptionReconciliationResolved(requestId, State.Failed, bytes32(0));
        }
    }

    // --- View Functions ---

    /**
     * @notice Returns redemption details for a given requestId.
     * @param requestId Unique identifier of the redemption request.
     */
    function getRedemption(bytes32 requestId) external view override returns (Redemption memory) {
        return _redemptions[requestId];
    }
}
