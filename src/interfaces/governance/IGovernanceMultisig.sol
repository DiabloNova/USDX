// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGovernanceMultisig
 * @notice Interface for USDX 3-of-5 Multisig Governance with integrated Timelock support.
 */
interface IGovernanceMultisig {
    enum ProposalState {
        Proposed,
        Approved,
        Queued,
        Executed,
        Cancelled
    }

    struct Proposal {
        uint256 id;
        address target;
        uint256 value;
        bytes data;
        bytes32 descriptionHash;
        uint256 approvalCount;
        uint256 eta; // Execution ETA timestamp once queued (0 if not queued)
        bool executed;
        bool cancelled;
    }

    // Events
    event MemberAdded(address indexed member);
    event MemberRemoved(address indexed member);
    event MemberReplaced(address indexed oldMember, address indexed newMember);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed target,
        uint256 value,
        bytes data,
        bytes32 descriptionHash
    );
    event ProposalApproved(uint256 indexed proposalId, address indexed approver, uint256 approvalCount);
    event ProposalApprovalRevoked(uint256 indexed proposalId, address indexed approver, uint256 approvalCount);
    event ProposalQueued(uint256 indexed proposalId, uint256 eta);
    event ProposalExecuted(uint256 indexed proposalId, address indexed executor);
    event ProposalCancelled(uint256 indexed proposalId, address indexed canceller);
    event MinDelayUpdated(uint256 oldMinDelay, uint256 newMinDelay);

    // Errors
    error InvalidMemberCount(uint256 count);
    error InvalidMemberAddress(address member);
    error DuplicateMember(address member);
    error NotGovernanceMember(address caller);
    error ProposalDoesNotExist(uint256 proposalId);
    error ProposalAlreadyExists(uint256 proposalId);
    error AlreadyApproved(uint256 proposalId, address member);
    error ApprovalNotGranted(uint256 proposalId, address member);
    error InsufficientApprovals(uint256 current, uint256 required);
    error ProposalNotApproved(uint256 proposalId);
    error ProposalNotQueued(uint256 proposalId);
    error TimelockNotMet(uint256 currentTime, uint256 eta);
    error ProposalAlreadyExecuted(uint256 proposalId);
    error ProposalAlreadyCancelled(uint256 proposalId);
    error ExecutionFailed(uint256 proposalId);
    error UnauthorizedCaller(address caller);
    error InvalidDelay(uint256 delay);
    error CannotRemoveBelowThreshold(uint256 currentMembers, uint256 threshold);

    // View functions
    function REQUIRED_APPROVALS() external view returns (uint256);
    function memberCount() external view returns (uint256);
    function isMember(address account) external view returns (bool);
    function minDelay() external view returns (uint256);
    function proposalCount() external view returns (uint256);
    function hasApproved(uint256 proposalId, address member) external view returns (bool);
    function getProposal(uint256 proposalId) external view returns (
        address target,
        uint256 value,
        bytes memory data,
        bytes32 descriptionHash,
        uint256 approvalCount,
        uint256 eta,
        bool executed,
        bool cancelled
    );
    function getProposalState(uint256 proposalId) external view returns (ProposalState);
    function getProposalId(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 descriptionHash
    ) external pure returns (uint256);

    // State-changing functions
    function propose(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 descriptionHash
    ) external returns (uint256 proposalId);

    function approve(uint256 proposalId) external;
    function revokeApproval(uint256 proposalId) external;
    function queue(uint256 proposalId) external;
    function execute(uint256 proposalId) external payable;
    function cancel(uint256 proposalId) external;

    // Self-governance functions (only executable via executed proposals from the contract itself)
    function replaceMember(address oldMember, address newMember) external;
    function setMinDelay(uint256 newMinDelay) external;
}
