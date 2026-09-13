// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IUSDX Interface
 * @dev Interface for the USDX TRC-20 / ERC-20 token contract.
 */
interface IUSDX {
    // Standard ERC-20 / TRC-20 Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Role & Ownership Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event MinterStatusUpdated(address indexed minter, bool status);
    event BurnerStatusUpdated(address indexed burner, bool status);

    // ERC-20 / TRC-20 Metadata & View Functions
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    // ERC-20 / TRC-20 Core Operations
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // Access Control & Role Operations
    function owner() external view returns (address);
    function isMinter(address account) external view returns (bool);
    function isBurner(address account) external view returns (bool);
    function setMinter(address minter, bool status) external;
    function setBurner(address burner, bool status) external;
    function transferOwnership(address newOwner) external;

    // Controlled Minting & Burning
    function mint(address to, uint256 amount) external returns (bool);
    function burn(address account, uint256 amount) external returns (bool);
    function burn(uint256 amount) external returns (bool);
    function burnFrom(address account, uint256 amount) external returns (bool);
}
