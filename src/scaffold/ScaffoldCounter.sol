// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ScaffoldCounter
/// @notice Minimal contract to verify project toolchain compilation and test harness execution.
/// @dev This is strictly for Phase 0 toolchain validation and is NOT part of the USDX stablecoin protocol.
contract ScaffoldCounter {
    uint256 public count;

    function increment() external {
        count += 1;
    }
}
