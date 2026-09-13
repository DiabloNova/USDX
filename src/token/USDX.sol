// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interfaces/IUSDX.sol";

/**
 * @title USDX
 * @dev Core USDX TRC-20 / ERC-20 token contract.
 * Key characteristics:
 * - Decimals: 6
 * - Initial supply: 0
 * - Minting: Controlled by authorized minters.
 * - Burning: Controlled by authorized burners or self/allowance burning.
 * - No direct reserve attestation or banking logic embedded in token core.
 */
contract USDX is IUSDX {
    // Custom Errors
    error ZeroAddress();
    error Unauthorized();
    error InsufficientBalance(address account, uint256 available, uint256 required);
    error InsufficientAllowance(address owner, address spender, uint256 available, uint256 required);

    // Metadata
    string private constant NAME = "USDX";
    string private constant SYMBOL = "USDX";
    uint8 private constant DECIMALS = 6;

    // State Variables
    uint256 private _totalSupply;
    address private _owner;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _minters;
    mapping(address => bool) private _burners;

    modifier onlyOwner() {
        if (msg.sender != _owner) revert Unauthorized();
        _;
    }

    modifier onlyMinter() {
        if (!_minters[msg.sender]) revert Unauthorized();
        _;
    }

    /**
     * @dev Initializes contract setting deployer as the initial owner.
     * Initial total supply is zero.
     */
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // --- Metadata Views ---

    function name() external pure override returns (string memory) {
        return NAME;
    }

    function symbol() external pure override returns (string memory) {
        return SYMBOL;
    }

    function decimals() external pure override returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    // --- Role & Ownership Views ---

    function owner() external view override returns (address) {
        return _owner;
    }

    function isMinter(address account) external view override returns (bool) {
        return _minters[account];
    }

    function isBurner(address account) external view override returns (bool) {
        return _burners[account];
    }

    // --- Administrative Functions ---

    function transferOwnership(address newOwner) external override onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function setMinter(address minter, bool status) external override onlyOwner {
        if (minter == address(0)) revert ZeroAddress();
        _minters[minter] = status;
        emit MinterStatusUpdated(minter, status);
    }

    function setBurner(address burner, bool status) external override onlyOwner {
        if (burner == address(0)) revert ZeroAddress();
        _burners[burner] = status;
        emit BurnerStatusUpdated(burner, status);
    }

    // --- ERC-20 Standard Functions ---

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert InsufficientAllowance(from, msg.sender, currentAllowance, amount);
            }
            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }
        _transfer(from, to, amount);
        return true;
    }

    // --- Controlled Minting ---

    function mint(address to, uint256 amount) external override onlyMinter returns (bool) {
        if (to == address(0)) revert ZeroAddress();

        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }

        emit Transfer(address(0), to, amount);
        return true;
    }

    // --- Controlled Burning ---

    /**
     * @dev Burns tokens directly from `account`. Restricted to authorized burners.
     */
    function burn(address account, uint256 amount) external override returns (bool) {
        if (!_burners[msg.sender]) revert Unauthorized();
        _burnInternal(account, amount);
        return true;
    }

    /**
     * @dev Burns caller's own tokens.
     */
    function burn(uint256 amount) external override returns (bool) {
        _burnInternal(msg.sender, amount);
        return true;
    }

    /**
     * @dev Burns tokens from `account` using caller's allowance.
     */
    function burnFrom(address account, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[account][msg.sender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert InsufficientAllowance(account, msg.sender, currentAllowance, amount);
            }
            unchecked {
                _approve(account, msg.sender, currentAllowance - amount);
            }
        }
        _burnInternal(account, amount);
        return true;
    }

    // --- Internal Helpers ---

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0) || to == address(0)) revert ZeroAddress();

        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance(from, fromBalance, amount);

        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal {
        if (owner_ == address(0) || spender == address(0)) revert ZeroAddress();

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _burnInternal(address account, uint256 amount) internal {
        if (account == address(0)) revert ZeroAddress();

        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert InsufficientBalance(account, accountBalance, amount);

        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }
}
