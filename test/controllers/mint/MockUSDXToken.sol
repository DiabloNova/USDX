// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IUSDXToken} from "../../../src/controllers/mint/IUSDXToken.sol";

contract MockUSDXToken is IUSDXToken {
    error UnauthorizedTokenMinter();

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => bool) public isAuthorizedMinter;

    constructor() {
        isAuthorizedMinter[msg.sender] = true;
    }

    function setAuthorizedMinter(address minter, bool status) external {
        isAuthorizedMinter[minter] = status;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function mint(address recipient, uint256 amount) external override {
        if (!isAuthorizedMinter[msg.sender]) {
            revert UnauthorizedTokenMinter();
        }
        _totalSupply += amount;
        _balances[recipient] += amount;
    }
}
