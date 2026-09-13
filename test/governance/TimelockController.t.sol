// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/governance/TimelockController.sol";
import "../../src/interfaces/governance/ITimelockController.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function expectRevert(bytes calldata) external;
}

contract TimelockTarget {
    uint256 public count;

    function increment() external {
        count++;
    }
}

contract TimelockControllerTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TimelockController internal timelock;
    TimelockTarget internal target;

    address internal admin = address(0x111);
    address internal nonAdmin = address(0x999);
    uint256 internal constant MIN_DELAY = 2 days;

    function setUp() public {
        timelock = new TimelockController(MIN_DELAY, admin);
        target = new TimelockTarget();
    }

    function test_TimelockInitialization() public view {
        require(timelock.getMinDelay() == MIN_DELAY, "Min delay mismatch");
        require(timelock.admin() == admin, "Admin mismatch");
    }

    function test_UnauthorizedScheduleRejection() public {
        bytes memory data = abi.encodeWithSelector(TimelockTarget.increment.selector);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt1");

        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(ITimelockController.Unauthorized.selector, nonAdmin));
        timelock.schedule(address(target), 0, data, predecessor, salt, MIN_DELAY);
    }

    function test_ScheduleAndExecuteWorkflow() public {
        bytes memory data = abi.encodeWithSelector(TimelockTarget.increment.selector);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt1");

        vm.prank(admin);
        timelock.schedule(address(target), 0, data, predecessor, salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(target), 0, data, predecessor, salt);
        require(timelock.isOperationPending(id), "Operation should be pending");

        uint256 eta = timelock.getTimestamp(id);

        // Attempt early execution
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ITimelockController.TimelockUnmet.selector, id, eta));
        timelock.execute(address(target), 0, data, predecessor, salt);

        // Warp time past delay
        vm.warp(block.timestamp + MIN_DELAY + 1);

        require(timelock.isOperationReady(id), "Operation should be ready");

        vm.prank(admin);
        timelock.execute(address(target), 0, data, predecessor, salt);

        require(target.count() == 1, "Target count should be 1");
        require(timelock.isOperationDone(id), "Operation should be marked done");
    }

    function test_CancelOperation() public {
        bytes memory data = abi.encodeWithSelector(TimelockTarget.increment.selector);
        bytes32 predecessor = bytes32(0);
        bytes32 salt = keccak256("salt1");

        vm.prank(admin);
        timelock.schedule(address(target), 0, data, predecessor, salt, MIN_DELAY);

        bytes32 id = timelock.hashOperation(address(target), 0, data, predecessor, salt);

        vm.prank(admin);
        timelock.cancel(id);

        require(!timelock.isOperation(id), "Operation should no longer exist");
    }
}
