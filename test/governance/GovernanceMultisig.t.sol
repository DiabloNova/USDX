// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/governance/GovernanceMultisig.sol";
import "../../src/interfaces/governance/IGovernanceMultisig.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert(bytes calldata) external;
    function expectRevert(bytes4) external;
}

contract DummyTarget {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}

contract GovernanceMultisigTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    GovernanceMultisig internal gov;
    DummyTarget internal target;

    address internal m1 = address(0x101);
    address internal m2 = address(0x102);
    address internal m3 = address(0x103);
    address internal m4 = address(0x104);
    address internal m5 = address(0x105);
    address internal nonMember = address(0x999);

    uint256 internal constant MIN_DELAY = 1 days;

    function setUp() public {
        address[] memory members = new address[](5);
        members[0] = m1;
        members[1] = m2;
        members[2] = m3;
        members[3] = m4;
        members[4] = m5;

        gov = new GovernanceMultisig(members, MIN_DELAY);
        target = new DummyTarget();
    }

    // 1. Initialization tests
    function test_Initialization() public view {
        require(gov.REQUIRED_APPROVALS() == 3, "Threshold must be 3");
        require(gov.memberCount() == 5, "Member count must be 5");
        require(gov.isMember(m1), "m1 must be member");
        require(gov.isMember(m5), "m5 must be member");
        require(!gov.isMember(nonMember), "nonMember must not be member");
        require(gov.minDelay() == MIN_DELAY, "minDelay mismatch");
    }

    function test_RevertIfInvalidInitialMemberCount() public {
        address[] memory invalidMembers = new address[](4);
        invalidMembers[0] = m1;
        invalidMembers[1] = m2;
        invalidMembers[2] = m3;
        invalidMembers[3] = m4;

        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.InvalidMemberCount.selector, 4));
        new GovernanceMultisig(invalidMembers, MIN_DELAY);
    }

    function test_RevertIfDuplicateInitialMember() public {
        address[] memory duplicateMembers = new address[](5);
        duplicateMembers[0] = m1;
        duplicateMembers[1] = m2;
        duplicateMembers[2] = m3;
        duplicateMembers[3] = m4;
        duplicateMembers[4] = m1;

        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.DuplicateMember.selector, m1));
        new GovernanceMultisig(duplicateMembers, MIN_DELAY);
    }

    // 2. Proposal tests
    function test_UnauthorizedProposalRejection() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(nonMember);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.NotGovernanceMember.selector, nonMember));
        gov.propose(address(target), 0, data, descHash);
    }

    function test_ProposalCreationAutoApprovesProposer() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        require(gov.hasApproved(proposalId, m1), "Proposer should automatically approve");
        require(!gov.hasApproved(proposalId, m2), "m2 should not have approved yet");

        (,,,, uint256 approvalCount,,,) = gov.getProposal(proposalId);
        require(approvalCount == 1, "Approval count should be 1");
    }

    // 3. Approval tests
    function test_DuplicateApprovalPrevention() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        vm.prank(m1);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.AlreadyApproved.selector, proposalId, m1));
        gov.approve(proposalId);
    }

    function test_InsufficientApprovalsQueueRejection() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        vm.prank(m2);
        gov.approve(proposalId);

        // Only 2 approvals (m1 and m2)
        vm.prank(m1);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.InsufficientApprovals.selector, 2, 3));
        gov.queue(proposalId);
    }

    function test_ExactlyThreeApprovalsCanQueue() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        vm.prank(m2);
        gov.approve(proposalId);

        vm.prank(m3);
        gov.approve(proposalId);

        vm.prank(m1);
        gov.queue(proposalId);

        (,,,,, uint256 eta,,) = gov.getProposal(proposalId);
        require(eta > 0, "Proposal should be queued with eta > 0");
    }

    // 4. Execution & Timelock tests
    function test_UnauthorizedExecutionRejection() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        vm.prank(m2);
        gov.approve(proposalId);
        vm.prank(m3);
        gov.approve(proposalId);
        vm.prank(m1);
        gov.queue(proposalId);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(nonMember);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.NotGovernanceMember.selector, nonMember));
        gov.execute(proposalId);
    }

    function test_TimelockDelayEnforcement() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        vm.prank(m2);
        gov.approve(proposalId);
        vm.prank(m3);
        gov.approve(proposalId);

        vm.prank(m1);
        gov.queue(proposalId);

        (,,,,, uint256 eta,,) = gov.getProposal(proposalId);

        // Try executing before timelock delay
        vm.prank(m1);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.TimelockNotMet.selector, block.timestamp, eta));
        gov.execute(proposalId);

        // Warp past timelock delay
        vm.warp(eta);
        vm.prank(m1);
        gov.execute(proposalId);

        require(target.value() == 42, "Target value should be updated to 42");
    }

    function test_OperationReplayAndDuplicateExecutionPrevention() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        vm.prank(m2);
        gov.approve(proposalId);
        vm.prank(m3);
        gov.approve(proposalId);
        vm.prank(m1);
        gov.queue(proposalId);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(m1);
        gov.execute(proposalId);

        // Second execution must revert as already executed
        vm.prank(m1);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.ProposalAlreadyExecuted.selector, proposalId));
        gov.execute(proposalId);

        // Re-proposal with same parameters must fail as proposal already exists
        vm.prank(m1);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.ProposalAlreadyExists.selector, proposalId));
        gov.propose(address(target), 0, data, descHash);
    }

    // 5. Cancellation tests
    function test_ProposalCancellation() public {
        bytes memory data = abi.encodeWithSelector(DummyTarget.setValue.selector, 42);
        bytes32 descHash = keccak256("Set value to 42");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(target), 0, data, descHash);

        vm.prank(m2);
        gov.cancel(proposalId);

        vm.prank(m3);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.ProposalAlreadyCancelled.selector, proposalId));
        gov.approve(proposalId);
    }

    // 6. Member replacement restrictions tests
    function test_DirectMemberReplacementFailsIfNotSelf() public {
        address newMember = address(0x201);

        vm.prank(m1);
        vm.expectRevert(abi.encodeWithSelector(IGovernanceMultisig.UnauthorizedCaller.selector, m1));
        gov.replaceMember(m1, newMember);
    }

    function test_MemberReplacementViaGovernanceProposal() public {
        address newMember = address(0x201);
        bytes memory data = abi.encodeWithSelector(GovernanceMultisig.replaceMember.selector, m1, newMember);
        bytes32 descHash = keccak256("Replace m1 with newMember");

        vm.prank(m1);
        uint256 proposalId = gov.propose(address(gov), 0, data, descHash);

        vm.prank(m2);
        gov.approve(proposalId);
        vm.prank(m3);
        gov.approve(proposalId);

        vm.prank(m1);
        gov.queue(proposalId);

        vm.warp(block.timestamp + MIN_DELAY + 1);

        vm.prank(m1);
        gov.execute(proposalId);

        require(!gov.isMember(m1), "m1 should no longer be a member");
        require(gov.isMember(newMember), "newMember should now be a member");
    }
}
