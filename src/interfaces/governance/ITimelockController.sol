// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITimelockController
 * @notice Interface for a timelock execution contract for privileged operations.
 */
interface ITimelockController {
    event OperationScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        uint256 delay
    );
    event OperationExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data);
    event OperationCancelled(bytes32 indexed id);
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);

    error InvalidMinDelay(uint256 delay);
    error TimelockUnmet(bytes32 id, uint256 timestamp);
    error TimelockNotQueued(bytes32 id);
    error TimelockAlreadyQueued(bytes32 id);
    error Unauthorized(address account);
    error PredecessorNotExecuted(bytes32 predecessorId);
    error ExecutionFailed();

    function getMinDelay() external view returns (uint256);
    function isOperation(bytes32 id) external view returns (bool pending);
    function isOperationPending(bytes32 id) external view returns (bool pending);
    function isOperationReady(bytes32 id) external view returns (bool ready);
    function isOperationDone(bytes32 id) external view returns (bool done);
    function getTimestamp(bytes32 id) external view returns (uint256 timestamp);

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function cancel(bytes32 id) external;

    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external payable;

    function updateDelay(uint256 newDelay) external;
}
