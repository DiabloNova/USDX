// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/scaffold/ScaffoldCounter.sol";

contract ScaffoldCounterTest {
    ScaffoldCounter internal counter;

    function setUp() public {
        counter = new ScaffoldCounter();
    }

    function test_InitialCountIsZero() public view {
        require(counter.count() == 0, "Initial count should be zero");
    }

    function test_Increment() public {
        counter.increment();
        require(counter.count() == 1, "Count after increment should be 1");
    }
}
