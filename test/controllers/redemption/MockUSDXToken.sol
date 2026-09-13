// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../../src/interfaces/redemption/IUSDXRedeemableToken.sol";

contract MockUSDXToken is IUSDXRedeemableToken {
    mapping(address => uint256) public override balanceOf;
    uint256 public totalSupply;

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
        totalSupply += amount;
    }

    function burnFrom(address account, uint256 amount) external override {
        require(balanceOf[account] >= amount, "MockToken: insufficient balance");
        balanceOf[account] -= amount;
        totalSupply -= amount;
    }
}
