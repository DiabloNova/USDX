// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../src/token/USDX.sol";

// Simple test caller proxy to simulate different msg.sender values without forge std dependencies
contract CallerProxy {
    function callContract(address target, bytes calldata data)
        external
        returns (bool success, bytes memory returnData)
    {
        (success, returnData) = target.call(data);
    }
}

contract USDXTest {
    USDX internal token;
    CallerProxy internal proxy;

    address internal owner = address(this);
    address internal minter = address(0x1111);
    address internal burner = address(0x2222);
    address internal alice = address(0x3333);
    address internal bob = address(0x4444);
    address internal unauthorizedUser = address(0x9999);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event MinterStatusUpdated(address indexed minter, bool status);
    event BurnerStatusUpdated(address indexed burner, bool status);

    function setUp() public {
        token = new USDX();
        proxy = new CallerProxy();
        token.setMinter(minter, true);
        token.setBurner(burner, true);
    }

    // Helper to send transactions from proxy
    function _executeAsProxy(bytes memory data) internal returns (bool success, bytes memory returnData) {
        return proxy.callContract(address(token), data);
    }

    // --- 1. Initial State & Metadata ---

    function test_InitialState() public view {
        require(token.totalSupply() == 0, "Initial supply should be 0");
        require(token.decimals() == 6, "Decimals should be 6");
        require(keccak256(bytes(token.name())) == keccak256(bytes("USDX")), "Name mismatch");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes("USDX")), "Symbol mismatch");
        require(token.owner() == owner, "Owner mismatch");
    }

    // --- 2. Ownership and Role Administration ---

    function test_SetMinter() public {
        token.setMinter(alice, true);
        require(token.isMinter(alice), "Alice should be minter");
        token.setMinter(alice, false);
        require(!token.isMinter(alice), "Alice should not be minter");
    }

    function test_SetBurner() public {
        token.setBurner(alice, true);
        require(token.isBurner(alice), "Alice should be burner");
        token.setBurner(alice, false);
        require(!token.isBurner(alice), "Alice should not be burner");
    }

    function test_TransferOwnership() public {
        token.transferOwnership(alice);
        require(token.owner() == alice, "Owner should be alice");

        // Old owner can no longer set minter
        (bool success,) = _executeAsProxy(abi.encodeWithSelector(USDX.setMinter.selector, bob, true));
        // proxy is not alice
        require(!success, "Non-owner setting minter should fail");
    }

    function test_TransferOwnership_RevertZeroAddress() public {
        _executeAsProxy(abi.encodeWithSelector(USDX.transferOwnership.selector, address(0)));
        (bool success2,) = address(token).call(abi.encodeWithSelector(USDX.transferOwnership.selector, address(0)));
        require(!success2, "Transfer ownership to zero address should fail");
    }

    function test_SetMinter_RevertUnauthorized() public {
        (bool success,) = _executeAsProxy(abi.encodeWithSelector(USDX.setMinter.selector, alice, true));
        require(!success, "Unauthorized setMinter should fail");
    }

    function test_SetBurner_RevertUnauthorized() public {
        (bool success,) = _executeAsProxy(abi.encodeWithSelector(USDX.setBurner.selector, alice, true));
        require(!success, "Unauthorized setBurner should fail");
    }

    function test_SetMinter_RevertZeroAddress() public {
        (bool success,) = address(token).call(abi.encodeWithSelector(USDX.setMinter.selector, address(0), true));
        require(!success, "setMinter zero address should fail");
    }

    function test_SetBurner_RevertZeroAddress() public {
        (bool success,) = address(token).call(abi.encodeWithSelector(USDX.setBurner.selector, address(0), true));
        require(!success, "setBurner zero address should fail");
    }

    // --- 3. Minting Authorization & Mechanics ---

    function test_AuthorizedMint() public {
        token.setMinter(address(proxy), true);
        bytes memory mintCalldata = abi.encodeWithSelector(USDX.mint.selector, alice, 1000_000000);

        (bool mintSuccess,) = _executeAsProxy(mintCalldata);
        require(mintSuccess, "Authorized mint failed");

        require(token.balanceOf(alice) == 1000_000000, "Alice balance mismatch");
        require(token.totalSupply() == 1000_000000, "Total supply mismatch");
    }

    function test_UnauthorizedMint_Reverts() public {
        bytes memory mintCalldata = abi.encodeWithSelector(USDX.mint.selector, alice, 1000_000000);
        (bool success,) = _executeAsProxy(mintCalldata);
        require(!success, "Unauthorized mint should revert");
        require(token.totalSupply() == 0, "Total supply should remain zero");
    }

    function test_MintToZeroAddress_Reverts() public {
        token.setMinter(address(proxy), true);
        (bool success,) = _executeAsProxy(abi.encodeWithSelector(USDX.mint.selector, address(0), 1000_000000));
        require(!success, "Mint to zero address should revert");
    }

    // --- 4. Burning Authorization & Mechanics ---

    function test_SelfBurn() public {
        // First mint tokens to proxy
        token.setMinter(address(this), true);
        token.mint(address(proxy), 500_000000);

        require(token.balanceOf(address(proxy)) == 500_000000, "Proxy initial balance");

        // Proxy burns its own tokens
        bytes memory burnCalldata = abi.encodeWithSelector(bytes4(keccak256("burn(uint256)")), 200_000000);
        (bool success,) = _executeAsProxy(burnCalldata);
        require(success, "Self burn failed");

        require(token.balanceOf(address(proxy)) == 300_000000, "Proxy remaining balance");
        require(token.totalSupply() == 300_000000, "Total supply after burn");
    }

    function test_AuthorizedBurnAnotherUser() public {
        token.setMinter(address(this), true);
        token.mint(alice, 1000_000000);

        // Make proxy an authorized burner
        token.setBurner(address(proxy), true);

        bytes memory burnCalldata =
            abi.encodeWithSelector(bytes4(keccak256("burn(address,uint256)")), alice, 400_000000);
        (bool success,) = _executeAsProxy(burnCalldata);
        require(success, "Authorized burn failed");

        require(token.balanceOf(alice) == 600_000000, "Alice balance after burn");
        require(token.totalSupply() == 600_000000, "Total supply after burn");
    }

    function test_UnauthorizedBurnAnotherUser_Reverts() public {
        token.setMinter(address(this), true);
        token.mint(alice, 1000_000000);

        // proxy is NOT a burner
        bytes memory burnCalldata =
            abi.encodeWithSelector(bytes4(keccak256("burn(address,uint256)")), alice, 400_000000);
        (bool success,) = _executeAsProxy(burnCalldata);
        require(!success, "Unauthorized burn of another user should fail");

        require(token.balanceOf(alice) == 1000_000000, "Alice balance untouched");
        require(token.totalSupply() == 1000_000000, "Total supply untouched");
    }

    function test_BurnFrom_WithAllowance() public {
        token.setMinter(address(this), true);

        // Make aliceProxy hold tokens and approve proxy to burn
        CallerProxy aliceProxy = new CallerProxy();
        token.mint(address(aliceProxy), 1000_000000);

        aliceProxy.callContract(
            address(token), abi.encodeWithSelector(USDX.approve.selector, address(proxy), 400_000000)
        );

        // Proxy burns from aliceProxy
        bytes memory burnFromCalldata = abi.encodeWithSelector(USDX.burnFrom.selector, address(aliceProxy), 400_000000);
        (bool success,) = _executeAsProxy(burnFromCalldata);
        require(success, "burnFrom with allowance failed");

        require(token.balanceOf(address(aliceProxy)) == 600_000000, "aliceProxy balance after burnFrom");
        require(token.allowance(address(aliceProxy), address(proxy)) == 0, "Allowance spent");
    }

    function test_BurnFrom_InsufficientAllowance_Reverts() public {
        CallerProxy aliceProxy = new CallerProxy();
        token.setMinter(address(this), true);
        token.mint(address(aliceProxy), 1000_000000);

        aliceProxy.callContract(
            address(token), abi.encodeWithSelector(USDX.approve.selector, address(proxy), 100_000000)
        );

        bytes memory burnFromCalldata = abi.encodeWithSelector(USDX.burnFrom.selector, address(aliceProxy), 400_000000);
        (bool success,) = _executeAsProxy(burnFromCalldata);
        require(!success, "burnFrom with insufficient allowance should revert");
    }

    function test_Burn_InsufficientBalance_Reverts() public {
        token.setMinter(address(this), true);
        token.mint(address(proxy), 100_000000);

        bytes memory burnCalldata = abi.encodeWithSelector(bytes4(keccak256("burn(uint256)")), 200_000000);
        (bool success,) = _executeAsProxy(burnCalldata);
        require(!success, "Burn exceeding balance should revert");
    }

    // --- 5. Transfers & Allowances ---

    function test_Transfer() public {
        token.setMinter(address(this), true);
        token.mint(address(this), 1000_000000);

        bool success = token.transfer(alice, 300_000000);
        require(success, "Transfer failed");

        require(token.balanceOf(address(this)) == 700_000000, "Sender balance");
        require(token.balanceOf(alice) == 300_000000, "Recipient balance");
    }

    function test_Transfer_InsufficientBalance_Reverts() public {
        (bool success,) = address(token).call(abi.encodeWithSelector(USDX.transfer.selector, alice, 100));
        require(!success, "Transfer with insufficient balance should revert");
    }

    function test_Transfer_ToZeroAddress_Reverts() public {
        token.setMinter(address(this), true);
        token.mint(address(this), 1000);

        (bool success,) = address(token).call(abi.encodeWithSelector(USDX.transfer.selector, address(0), 100));
        require(!success, "Transfer to zero address should revert");
    }

    function test_ApproveAndTransferFrom() public {
        token.setMinter(address(this), true);
        token.mint(address(this), 1000_000000);

        token.approve(address(proxy), 500_000000);
        require(token.allowance(address(this), address(proxy)) == 500_000000, "Allowance setup failed");

        bytes memory transferFromCalldata =
            abi.encodeWithSelector(USDX.transferFrom.selector, address(this), bob, 300_000000);
        (bool success,) = _executeAsProxy(transferFromCalldata);
        require(success, "transferFrom failed");

        require(token.balanceOf(bob) == 300_000000, "Bob balance mismatch");
        require(token.allowance(address(this), address(proxy)) == 200_000000, "Remaining allowance mismatch");
    }

    function test_TransferFrom_InfiniteAllowance() public {
        token.setMinter(address(this), true);
        token.mint(address(this), 1000_000000);

        token.approve(address(proxy), type(uint256).max);

        bytes memory transferFromCalldata =
            abi.encodeWithSelector(USDX.transferFrom.selector, address(this), bob, 300_000000);
        (bool success,) = _executeAsProxy(transferFromCalldata);
        require(success, "transferFrom with infinite allowance failed");

        require(
            token.allowance(address(this), address(proxy)) == type(uint256).max,
            "Infinite allowance should not decrease"
        );
    }

    // --- 6. Fuzz Tests ---

    function testFuzz_MintAndTransfer(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 0, type(uint128).max);
        transferAmount = bound(transferAmount, 0, mintAmount);

        token.setMinter(address(this), true);
        token.mint(alice, mintAmount);

        require(token.balanceOf(alice) == mintAmount, "Fuzz mint balance");
        require(token.totalSupply() == mintAmount, "Fuzz mint totalSupply");

        if (mintAmount > 0) {
            CallerProxy aliceProxy = new CallerProxy();
            token.mint(address(aliceProxy), mintAmount);

            bytes memory transferCalldata = abi.encodeWithSelector(USDX.transfer.selector, bob, transferAmount);
            (bool success,) = aliceProxy.callContract(address(token), transferCalldata);
            require(success, "Fuzz transfer failed");

            require(token.balanceOf(bob) == transferAmount, "Fuzz bob balance");
            require(token.balanceOf(address(aliceProxy)) == mintAmount - transferAmount, "Fuzz alice balance");
        }
    }

    function testFuzz_MintAndBurn(uint256 mintAmount, uint256 burnAmount) public {
        mintAmount = bound(mintAmount, 0, type(uint128).max);
        burnAmount = bound(burnAmount, 0, mintAmount);

        token.setMinter(address(this), true);
        token.setBurner(address(this), true);

        token.mint(alice, mintAmount);
        uint256 supplyAfterMint = token.totalSupply();

        token.burn(alice, burnAmount);

        require(token.balanceOf(alice) == mintAmount - burnAmount, "Fuzz balance after burn");
        require(token.totalSupply() == supplyAfterMint - burnAmount, "Fuzz supply after burn");
    }

    // Helper for fuzz test bounding
    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (min > max) revert();
        if (x >= min && x <= max) return x;
        uint256 range = max - min + 1;
        if (range == 0) return min;
        return min + (x % range);
    }
}
