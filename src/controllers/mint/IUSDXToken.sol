// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IUSDXToken
 * @notice Interface for the USDX TRC-20 token contract methods required by the MintController.
 */
interface IUSDXToken {
    /**
     * @notice Returns the total circulating supply of USDX tokens.
     * @return Current total supply in base units (6 decimals).
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Mints new USDX tokens to a recipient address.
     * @dev Must enforce the token's own authorization boundary (e.g. MINTER_ROLE).
     * @param recipient Address receiving the minted tokens.
     * @param amount Token amount to mint in base units (6 decimals).
     */
    function mint(address recipient, uint256 amount) external;
}
