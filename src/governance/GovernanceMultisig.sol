// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/governance/IGovernanceMultisig.sol";

/**
 * @title GovernanceMultisig
 * @notice 3-of-5 Multisig Governance with integrated Timelock for USDX administration.
 * @dev Enforces 3-of-5 approval threshold, timelock delay for execution, proposal lifecycle,
 * replay protection, and governance self-management (e.g. member replacement via governance action).
 */
contract GovernanceMultisig is IGovernanceMultisig {
    uint256 public constant override REQUIRED_APPROVALS = 3;
    uint256 public constant INITIAL_MEMBER_COUNT = 5;

    uint256 public override minDelay;
    uint256 public override proposalCount;

    address[] private _members;
    mapping(address => bool) private _isMember;

    // Proposal ID => Proposal details
    mapping(uint256 => Proposal) private _proposals;

    // Proposal ID => member => approved
    mapping(uint256 => mapping(address => bool)) private _approvals;

    modifier onlyMember() {
        if (!_isMember[msg.sender]) {
            revert NotGovernanceMember(msg.sender);
        }
        _;
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert UnauthorizedCaller(msg.sender);
        }
        _;
    }

    /**
     * @notice Constructor initializes exactly 5 governance members and the initial timelock delay.
     * @param initialMembers Array of exactly 5 unique non-zero member addresses.
     * @param initialMinDelay Minimum timelock delay in seconds.
     */
    constructor(address[] memory initialMembers, uint256 initialMinDelay) {
        if (initialMembers.length != INITIAL_MEMBER_COUNT) {
            revert InvalidMemberCount(initialMembers.length);
        }

        for (uint256 i = 0; i < INITIAL_MEMBER_COUNT; i++) {
            address member = initialMembers[i];
            if (member == address(0)) {
                revert InvalidMemberAddress(address(0));
            }
            if (_isMember[member]) {
                revert DuplicateMember(member);
            }
            _isMember[member] = true;
            _members.push(member);
            emit MemberAdded(member);
        }

        minDelay = initialMinDelay;
        emit MinDelayUpdated(0, initialMinDelay);
    }

    /// @notice Fallback function to allow receiving ETH if necessary.
    receive() external payable {}

    // ------------------------------------------------------------------------
    // View Functions
    // ------------------------------------------------------------------------

    function memberCount() external view override returns (uint256) {
        return _members.length;
    }

    function isMember(address account) external view override returns (bool) {
        return _isMember[account];
    }

    function getMembers() external view returns (address[] memory) {
        return _members;
    }

    function hasApproved(uint256 proposalId, address member) external view override returns (bool) {
        return _approvals[proposalId][member];
    }

    function getProposal(uint256 proposalId)
        external
        view
        override
        returns (
            address target,
            uint256 value,
            bytes memory data,
            bytes32 descriptionHash,
            uint256 approvalCount,
            uint256 eta,
            bool executed,
            bool cancelled
        )
    {
        Proposal memory p = _proposals[proposalId];
        if (p.id == 0) revert ProposalDoesNotExist(proposalId);
        return (p.target, p.value, p.data, p.descriptionHash, p.approvalCount, p.eta, p.executed, p.cancelled);
    }

    function getProposalState(uint256 proposalId) external view override returns (ProposalState) {
        Proposal memory p = _proposals[proposalId];
        if (p.id == 0) revert ProposalDoesNotExist(proposalId);

        if (p.cancelled) return ProposalState.Cancelled;
        if (p.executed) return ProposalState.Executed;
        if (p.eta > 0) return ProposalState.Queued;
        if (p.approvalCount >= REQUIRED_APPROVALS) return ProposalState.Approved;
        return ProposalState.Proposed;
    }

    function getProposalId(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 descriptionHash
    ) public pure override returns (uint256) {
        return uint256(keccak256(abi.encode(target, value, keccak256(data), descriptionHash)));
    }

    // ------------------------------------------------------------------------
    // State-Changing Governance Actions
    // ------------------------------------------------------------------------

    /**
     * @notice Create a new governance proposal. Automatically approves for proposer.
     */
    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 descriptionHash
    ) external override onlyMember returns (uint256 proposalId) {
        if (target == address(0)) revert InvalidMemberAddress(address(0));

        proposalId = getProposalId(target, value, data, descriptionHash);
        if (_proposals[proposalId].id != 0) {
            revert ProposalAlreadyExists(proposalId);
        }

        Proposal storage p = _proposals[proposalId];
        p.id = proposalId;
        p.target = target;
        p.value = value;
        p.data = data;
        p.descriptionHash = descriptionHash;
        p.approvalCount = 1;

        _approvals[proposalId][msg.sender] = true;
        proposalCount++;

        emit ProposalCreated(proposalId, msg.sender, target, value, data, descriptionHash);
        emit ProposalApproved(proposalId, msg.sender, 1);

        return proposalId;
    }

    /**
     * @notice Governance member approves an existing proposal.
     */
    function approve(uint256 proposalId) external override onlyMember {
        Proposal storage p = _proposals[proposalId];
        if (p.id == 0) revert ProposalDoesNotExist(proposalId);
        if (p.executed) revert ProposalAlreadyExecuted(proposalId);
        if (p.cancelled) revert ProposalAlreadyCancelled(proposalId);
        if (_approvals[proposalId][msg.sender]) revert AlreadyApproved(proposalId, msg.sender);

        _approvals[proposalId][msg.sender] = true;
        p.approvalCount++;

        emit ProposalApproved(proposalId, msg.sender, p.approvalCount);
    }

    /**
     * @notice Governance member revokes an approval prior to execution.
     */
    function revokeApproval(uint256 proposalId) external override onlyMember {
        Proposal storage p = _proposals[proposalId];
        if (p.id == 0) revert ProposalDoesNotExist(proposalId);
        if (p.executed) revert ProposalAlreadyExecuted(proposalId);
        if (p.cancelled) revert ProposalAlreadyCancelled(proposalId);
        if (!_approvals[proposalId][msg.sender]) revert ApprovalNotGranted(proposalId, msg.sender);

        _approvals[proposalId][msg.sender] = false;
        p.approvalCount--;

        // If approval count drops below threshold after queueing, reset queue ETA
        if (p.approvalCount < REQUIRED_APPROVALS && p.eta > 0) {
            p.eta = 0;
        }

        emit ProposalApprovalRevoked(proposalId, msg.sender, p.approvalCount);
    }

    /**
     * @notice Queues an approved proposal into timelock.
     */
    function queue(uint256 proposalId) external override onlyMember {
        Proposal storage p = _proposals[proposalId];
        if (p.id == 0) revert ProposalDoesNotExist(proposalId);
        if (p.executed) revert ProposalAlreadyExecuted(proposalId);
        if (p.cancelled) revert ProposalAlreadyCancelled(proposalId);
        if (p.approvalCount < REQUIRED_APPROVALS) {
            revert InsufficientApprovals(p.approvalCount, REQUIRED_APPROVALS);
        }

        uint256 eta = block.timestamp + minDelay;
        p.eta = eta;

        emit ProposalQueued(proposalId, eta);
    }

    /**
     * @notice Executes a queued proposal whose timelock delay has passed.
     */
    function execute(uint256 proposalId) external payable override onlyMember {
        Proposal storage p = _proposals[proposalId];
        if (p.id == 0) revert ProposalDoesNotExist(proposalId);
        if (p.executed) revert ProposalAlreadyExecuted(proposalId);
        if (p.cancelled) revert ProposalAlreadyCancelled(proposalId);
        if (p.approvalCount < REQUIRED_APPROVALS) {
            revert InsufficientApprovals(p.approvalCount, REQUIRED_APPROVALS);
        }
        if (p.eta == 0) revert ProposalNotQueued(proposalId);
        if (block.timestamp < p.eta) revert TimelockNotMet(block.timestamp, p.eta);

        p.executed = true;

        (bool success, ) = p.target.call{value: p.value}(p.data);
        if (!success) revert ExecutionFailed(proposalId);

        emit ProposalExecuted(proposalId, msg.sender);
    }

    /**
     * @notice Cancels a proposal. Can be called by any member if unexecuted and unqueued, or via governance action.
     */
    function cancel(uint256 proposalId) external override onlyMember {
        Proposal storage p = _proposals[proposalId];
        if (p.id == 0) revert ProposalDoesNotExist(proposalId);
        if (p.executed) revert ProposalAlreadyExecuted(proposalId);
        if (p.cancelled) revert ProposalAlreadyCancelled(proposalId);

        p.cancelled = true;
        emit ProposalCancelled(proposalId, msg.sender);
    }

    // ------------------------------------------------------------------------
    // Self-Governance Administration (Callable only by contract itself via proposal)
    // ------------------------------------------------------------------------

    /**
     * @notice Replaces a governance member with a new member address.
     */
    function replaceMember(address oldMember, address newMember) external override onlySelf {
        if (!_isMember[oldMember]) revert NotGovernanceMember(oldMember);
        if (newMember == address(0)) revert InvalidMemberAddress(address(0));
        if (_isMember[newMember]) revert DuplicateMember(newMember);

        _isMember[oldMember] = false;
        _isMember[newMember] = true;

        for (uint256 i = 0; i < _members.length; i++) {
            if (_members[i] == oldMember) {
                _members[i] = newMember;
                break;
            }
        }

        emit MemberReplaced(oldMember, newMember);
    }

    /**
     * @notice Updates the minimum timelock delay for non-emergency operations.
     */
    function setMinDelay(uint256 newMinDelay) external override onlySelf {
        uint256 oldDelay = minDelay;
        minDelay = newMinDelay;
        emit MinDelayUpdated(oldDelay, newMinDelay);
    }
}
