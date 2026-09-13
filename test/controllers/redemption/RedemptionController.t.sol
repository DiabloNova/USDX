// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../../src/controllers/redemption/RedemptionController.sol";
import "../../../src/interfaces/redemption/IRedemptionController.sol";
import "./MockUSDXToken.sol";

contract RedemptionControllerTest {
    RedemptionController public controller;
    MockUSDXToken public token;

    address public admin = address(0x1);
    address public requester = address(0x2);
    address public approver = address(0x3);
    address public burner = address(0x4);
    address public payoutOperator = address(0x5);
    address public reconciler = address(0x6);
    address public user = address(0x7);
    address public unauthorizedUser = address(0x8);

    bytes32 public constant REQ_1 = keccak256("REQ_1");
    bytes32 public constant PAYOUT_REF_1 = keccak256("PAYOUT_REF_1");
    uint256 public constant INITIAL_BALANCE = 1_000_000_000; // 1000 USDX (6 decimals)

    // Standard Cheatcodes address in EVM execution (Foundry default)
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    event RedemptionRequested(bytes32 indexed requestId, address indexed account, uint256 amount);
    event RedemptionApproved(bytes32 indexed requestId, address indexed approver);
    event RedemptionBurned(bytes32 indexed requestId, address indexed account, uint256 amount);
    event RedemptionPayoutPending(bytes32 indexed requestId);
    event RedemptionPaid(bytes32 indexed requestId, bytes32 indexed payoutTxRef);
    event RedemptionFailed(bytes32 indexed requestId, string reason);
    event RedemptionReconciliationRequired(bytes32 indexed requestId, string reason);
    event RedemptionReconciliationResolved(bytes32 indexed requestId, IRedemptionController.State finalState, bytes32 payoutTxRef);

    function setUp() public {
        token = new MockUSDXToken();
        controller = new RedemptionController(address(token), admin);

        token.mint(user, INITIAL_BALANCE);

        vm.startPrank(admin);
        controller.grantRole(controller.REQUESTER_ROLE(), requester);
        controller.grantRole(controller.APPROVER_ROLE(), approver);
        controller.grantRole(controller.BURNER_ROLE(), burner);
        controller.grantRole(controller.PAYOUT_OPERATOR_ROLE(), payoutOperator);
        controller.grantRole(controller.RECONCILER_ROLE(), reconciler);
        vm.stopPrank();
    }

    // --- Happy Path Full Flow Test ---
    function test_FullRedemptionLifecycle() public {
        uint256 amount = 100_000_000; // 100 USDX

        // 1. Request
        vm.expectEmit(true, true, false, true);
        emit RedemptionRequested(REQ_1, user, amount);
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, amount);

        IRedemptionController.Redemption memory r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.Requested, "State should be Requested");
        require(r.account == user, "Account mismatch");
        require(r.amount == amount, "Amount mismatch");

        // 2. Approve
        vm.expectEmit(true, true, false, true);
        emit RedemptionApproved(REQ_1, approver);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);

        r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.Approved, "State should be Approved");

        // 3. Burn
        uint256 userBalBefore = token.balanceOf(user);
        vm.expectEmit(true, true, false, true);
        emit RedemptionBurned(REQ_1, user, amount);
        vm.prank(burner);
        controller.burnRedemption(REQ_1);

        r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.Burned, "State should be Burned");
        require(token.balanceOf(user) == userBalBefore - amount, "User token balance not decreased");
        require(controller.totalBurnedAmount() == amount, "Total burned amount mismatch");

        // 4. Mark Payout Pending
        vm.expectEmit(true, false, false, true);
        emit RedemptionPayoutPending(REQ_1);
        vm.prank(payoutOperator);
        controller.markPayoutPending(REQ_1);

        r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.PayoutPending, "State should be PayoutPending");

        // 5. Confirm Payout
        vm.expectEmit(true, true, false, true);
        emit RedemptionPaid(REQ_1, PAYOUT_REF_1);
        vm.prank(payoutOperator);
        controller.confirmPayout(REQ_1, PAYOUT_REF_1);

        r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.Paid, "State should be Paid");
        require(r.payoutTxRef == PAYOUT_REF_1, "Payout tx ref mismatch");
    }

    // --- Security Test: Unauthorized Access ---
    function test_Revert_UnauthorizedRedemptionRequest() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert(IRedemptionController.Unauthorized.selector);
        controller.requestRedemption(REQ_1, user, 100);
    }

    function test_Revert_UnauthorizedApproval() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);

        vm.prank(unauthorizedUser);
        vm.expectRevert(IRedemptionController.Unauthorized.selector);
        controller.approveRedemption(REQ_1);
    }

    function test_Revert_UnauthorizedBurn() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);

        vm.prank(unauthorizedUser);
        vm.expectRevert(IRedemptionController.Unauthorized.selector);
        controller.burnRedemption(REQ_1);
    }

    function test_Revert_UnauthorizedPayoutConfirmation() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);
        vm.prank(burner);
        controller.burnRedemption(REQ_1);
        vm.prank(payoutOperator);
        controller.markPayoutPending(REQ_1);

        vm.prank(unauthorizedUser);
        vm.expectRevert(IRedemptionController.Unauthorized.selector);
        controller.confirmPayout(REQ_1, PAYOUT_REF_1);
    }

    // --- Security Test: Invalid Inputs & Amounts ---
    function test_Revert_InvalidAmount() public {
        vm.prank(requester);
        vm.expectRevert(IRedemptionController.InvalidAmount.selector);
        controller.requestRedemption(REQ_1, user, 0);
    }

    function test_Revert_InvalidAccount() public {
        vm.prank(requester);
        vm.expectRevert(IRedemptionController.InvalidAccount.selector);
        controller.requestRedemption(REQ_1, address(0), 100);
    }

    function test_Revert_InvalidRequestId() public {
        vm.prank(requester);
        vm.expectRevert(IRedemptionController.InvalidRequestId.selector);
        controller.requestRedemption(bytes32(0), user, 100);
    }

    // --- Security Test: Duplicate Requests ---
    function test_Revert_DuplicateRequest() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);

        vm.prank(requester);
        vm.expectRevert(IRedemptionController.DuplicateRequest.selector);
        controller.requestRedemption(REQ_1, user, 200);
    }

    // --- Security Test: Approval Replay / State Replay ---
    function test_Revert_ApprovalReplay() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);

        // Attempting to approve again
        vm.prank(approver);
        vm.expectRevert(abi.encodeWithSelector(IRedemptionController.InvalidStateTransition.selector, REQ_1, IRedemptionController.State.Approved, IRedemptionController.State.Requested));
        controller.approveRedemption(REQ_1);
    }

    // --- Security Test: Duplicate Payout Confirmation ---
    function test_Revert_DuplicatePayoutConfirmation() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);
        vm.prank(burner);
        controller.burnRedemption(REQ_1);
        vm.prank(payoutOperator);
        controller.markPayoutPending(REQ_1);
        vm.prank(payoutOperator);
        controller.confirmPayout(REQ_1, PAYOUT_REF_1);

        // Attempting second confirmPayout
        vm.prank(payoutOperator);
        vm.expectRevert(abi.encodeWithSelector(IRedemptionController.InvalidStateTransition.selector, REQ_1, IRedemptionController.State.Paid, IRedemptionController.State.PayoutPending));
        controller.confirmPayout(REQ_1, keccak256("PAYOUT_REF_2"));
    }

    // --- Security Test: Failure and Reconciliation Flow ---
    function test_FailureAndReconciliationFlow() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);
        vm.prank(burner);
        controller.burnRedemption(REQ_1);
        vm.prank(payoutOperator);
        controller.markPayoutPending(REQ_1);

        // Mark Payout Failed
        vm.expectEmit(true, false, false, true);
        emit RedemptionFailed(REQ_1, "Wire transfer rejected by beneficiary bank");
        vm.prank(payoutOperator);
        controller.markPayoutFailed(REQ_1, "Wire transfer rejected by beneficiary bank");

        IRedemptionController.Redemption memory r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.Failed, "State should be Failed");

        // Flag for Reconciliation
        vm.expectEmit(true, false, false, true);
        emit RedemptionReconciliationRequired(REQ_1, "Manual audit needed");
        vm.prank(reconciler);
        controller.flagForReconciliation(REQ_1, "Manual audit needed");

        r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.ReconciliationRequired, "State should be ReconciliationRequired");

        // Resolve Reconciliation as Paid
        vm.expectEmit(true, true, false, true);
        emit RedemptionPaid(REQ_1, PAYOUT_REF_1);
        vm.prank(reconciler);
        controller.resolveReconciliation(REQ_1, true, PAYOUT_REF_1, "");

        r = controller.getRedemption(REQ_1);
        require(r.state == IRedemptionController.State.Paid, "State should be Paid");
        require(r.payoutTxRef == PAYOUT_REF_1, "Payout tx ref mismatch");
    }

    // --- Security Test: Invalid State Transitions / Skipping States ---
    function test_Revert_BurnWithoutApproval() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);

        vm.prank(burner);
        vm.expectRevert(abi.encodeWithSelector(IRedemptionController.InvalidStateTransition.selector, REQ_1, IRedemptionController.State.Requested, IRedemptionController.State.Approved));
        controller.burnRedemption(REQ_1);
    }

    function test_Revert_ConfirmPayoutBeforePending() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);
        vm.prank(burner);
        controller.burnRedemption(REQ_1);

        vm.prank(payoutOperator);
        vm.expectRevert(abi.encodeWithSelector(IRedemptionController.InvalidStateTransition.selector, REQ_1, IRedemptionController.State.Burned, IRedemptionController.State.PayoutPending));
        controller.confirmPayout(REQ_1, PAYOUT_REF_1);
    }

    // --- Terminal State Protection ---
    function test_Revert_TransitionFromPaid() public {
        vm.prank(requester);
        controller.requestRedemption(REQ_1, user, 100);
        vm.prank(approver);
        controller.approveRedemption(REQ_1);
        vm.prank(burner);
        controller.burnRedemption(REQ_1);
        vm.prank(payoutOperator);
        controller.markPayoutPending(REQ_1);
        vm.prank(payoutOperator);
        controller.confirmPayout(REQ_1, PAYOUT_REF_1);

        // Attempting any transition from Paid
        vm.prank(approver);
        vm.expectRevert();
        controller.approveRedemption(REQ_1);

        vm.prank(burner);
        vm.expectRevert();
        controller.burnRedemption(REQ_1);

        vm.prank(payoutOperator);
        vm.expectRevert();
        controller.markPayoutFailed(REQ_1, "Late fail");
    }

    // --- Fuzz Testing ---
    function testFuzz_RedemptionAmount(uint256 amount) public {
        if (amount == 0 || amount > INITIAL_BALANCE) return;
        bytes32 reqId = keccak256(abi.encodePacked("FUZZ_REQ", amount));

        vm.prank(requester);
        controller.requestRedemption(reqId, user, amount);

        vm.prank(approver);
        controller.approveRedemption(reqId);

        vm.prank(burner);
        controller.burnRedemption(reqId);

        require(token.balanceOf(user) == INITIAL_BALANCE - amount, "Fuzz token balance mismatch");
        require(controller.totalBurnedAmount() == amount, "Fuzz total burned mismatch");
    }
}

interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool, bool, bool, bool) external;
}
