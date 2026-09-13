// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/governance/ITimelockController.sol";

/**
 * @title TimelockController
 * @notice Standalone Timelock contract for delaying privileged operations.
 * @dev Enforces a configurable delay between proposal/scheduling and execution of operations.
 */
contract TimelockController is ITimelockController {
    uint256 private _minDelay;
    address public admin;

    // Operation ID => Timestamp after which execution is allowed (0 = not queued, 1 = done)
    mapping(bytes32 => uint256) private _timestamps;

    uint256 private constant _DONE_TIMESTAMP = 1;

    modifier onlyAdmin() {
        if (msg.sender != admin) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlySelf() {
        if (msg.sender != address(this)) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    constructor(uint256 minDelay, address initialAdmin) {
        if (initialAdmin == address(0)) {
            revert Unauthorized(address(0));
        }
        _minDelay = minDelay;
        admin = initialAdmin;
        emit MinDelayChange(0, minDelay);
    }

    receive() external payable {}

    function getMinDelay() external view override returns (uint256) {
        return _minDelay;
    }

    function isOperation(bytes32 id) public view override returns (bool) {
        return getTimestamp(id) > 0;
    }

    function isOperationPending(bytes32 id) public view override returns (bool) {
        return getTimestamp(id) > _DONE_TIMESTAMP;
    }

    function isOperationReady(bytes32 id) public view override returns (bool) {
        uint256 ts = getTimestamp(id);
        return ts > _DONE_TIMESTAMP && block.timestamp >= ts;
    }

    function isOperationDone(bytes32 id) public view override returns (bool) {
        return getTimestamp(id) == _DONE_TIMESTAMP;
    }

    function getTimestamp(bytes32 id) public view override returns (uint256) {
        return _timestamps[id];
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public pure override returns (bytes32) {
        return keccak256(abi.encode(target, value, keccak256(data), predecessor, salt));
    }

    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external override onlyAdmin {
        if (delay < _minDelay) {
            revert InvalidMinDelay(delay);
        }

        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        if (isOperation(id)) {
            revert TimelockAlreadyQueued(id);
        }

        uint256 eta = block.timestamp + delay;
        _timestamps[id] = eta;

        emit OperationScheduled(id, 0, target, value, data, predecessor, delay);
    }

    function cancel(bytes32 id) external override onlyAdmin {
        if (!isOperationPending(id)) {
            revert TimelockNotQueued(id);
        }
        delete _timestamps[id];
        emit OperationCancelled(id);
    }

    function execute(
        address target,
        uint256 value,
        bytes calldata payload,
        bytes32 predecessor,
        bytes32 salt
    ) external payable override onlyAdmin {
        bytes32 id = hashOperation(target, value, payload, predecessor, salt);

        if (!isOperationPending(id)) {
            revert TimelockNotQueued(id);
        }
        if (block.timestamp < _timestamps[id]) {
            revert TimelockUnmet(id, _timestamps[id]);
        }

        if (predecessor != bytes32(0) && !isOperationDone(predecessor)) {
            revert PredecessorNotExecuted(predecessor);
        }

        _timestamps[id] = _DONE_TIMESTAMP;

        (bool success, ) = target.call{value: value}(payload);
        if (!success) {
            revert ExecutionFailed();
        }

        emit OperationExecuted(id, 0, target, value, payload);
    }

    function updateDelay(uint256 newDelay) external override onlySelf {
        uint256 oldDelay = _minDelay;
        _minDelay = newDelay;
        emit MinDelayChange(oldDelay, newDelay);
    }
}
