// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IUSDXRedeemableToken {
    /// @notice Burns specified amount of tokens from account
    /// @param account Address from which tokens are burned
    /// @param amount Amount of tokens to burn (6 decimals)
    function burnFrom(address account, uint256 amount) external;

    /// @notice Returns the token balance of an account
    /// @param account Address to check balance
    function balanceOf(address account) external view returns (uint256);
}
