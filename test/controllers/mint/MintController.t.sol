// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {MintController} from "../../../src/controllers/mint/MintController.sol";
import {IReserveAttestation} from "../../../src/interfaces/reserve/IReserveAttestation.sol";
import {MockUSDXToken} from "./MockUSDXToken.sol";
import {MockReserveAttestation} from "./MockReserveAttestation.sol";

interface Vm {
    function prank(address) external;
    function addr(uint256) external returns (address);
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function expectRevert(bytes calldata) external;
    function expectRevert(bytes4) external;
    function expectRevert() external;
    function warp(uint256) external;
}

contract MintControllerTest {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MintController public mintController;
    MockUSDXToken public token;
    MockReserveAttestation public reserveAttestation;

    address public admin = address(0x1111);
    uint256 public minterPrivateKey = 0xA11CE;
    address public minter;
    address public recipient = address(0x3333);
    address public unauthorizedUser = address(0x9999);

    function setUp() public {
        vm.warp(100_000); // Set block.timestamp to 100,000 seconds

        minter = vm.addr(minterPrivateKey);

        token = new MockUSDXToken();
        reserveAttestation = new MockReserveAttestation(1_000_000 * 1e6, block.timestamp, true, false);

        mintController = new MintController(address(token), address(reserveAttestation), admin);

        // Grant minter role on MintController and grant MintController minter role on MockUSDXToken
        vm.prank(admin);
        mintController.addMinter(minter);

        token.setAuthorizedMinter(address(mintController), true);
    }

    // --- Assertions ---
    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq uint256 failed");
    }

    function assertEq(bytes32 a, bytes32 b) internal pure {
        require(a == b, "assertEq bytes32 failed");
    }

    function assertTrue(bool cond) internal pure {
        require(cond, "assertTrue failed");
    }

    function assertFalse(bool cond) internal pure {
        require(!cond, "assertFalse failed");
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        require(min <= max, "bound: min > max");
        if (x >= min && x <= max) return x;
        uint256 range = max - min + 1;
        return min + (x % range);
    }

    // --- Basic Requirement Tests ---

    function test_MintWithinReserves_Succeeds() public {
        uint256 mintAmount = 500_000 * 1e6;
        uint256 nonce = 1;

        vm.prank(minter);
        mintController.executeMint(recipient, mintAmount, nonce);

        assertEq(token.totalSupply(), mintAmount);
        assertEq(token.balanceOf(recipient), mintAmount);
    }

    function test_MintExceedingReserves_Fails() public {
        uint256 mintAmount = 1_000_001 * 1e6; // Reserves are 1,000,000 * 1e6
        uint256 nonce = 1;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintController.SolvencyInvariantViolated.selector,
                0,
                mintAmount,
                1_000_000 * 1e6
            )
        );
        mintController.executeMint(recipient, mintAmount, nonce);
    }

    function test_ExactBoundary_Succeeds() public {
        uint256 mintAmount = 1_000_000 * 1e6; // Exact reserves balance
        uint256 nonce = 1;

        vm.prank(minter);
        mintController.executeMint(recipient, mintAmount, nonce);

        assertEq(token.totalSupply(), 1_000_000 * 1e6);
    }

    function test_OneUnitAboveBoundary_Fails() public {
        uint256 mintAmount = 1_000_000 * 1e6 + 1; // 1 base unit above boundary
        uint256 nonce = 1;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintController.SolvencyInvariantViolated.selector,
                0,
                mintAmount,
                1_000_000 * 1e6
            )
        );
        mintController.executeMint(recipient, mintAmount, nonce);
    }

    function test_ZeroAmount_Fails() public {
        vm.prank(minter);
        vm.expectRevert(MintController.InvalidMintAmount.selector);
        mintController.executeMint(recipient, 0, 1);
    }

    function test_ZeroRecipient_Fails() public {
        vm.prank(minter);
        vm.expectRevert(MintController.InvalidRecipient.selector);
        mintController.executeMint(address(0), 100 * 1e6, 1);
    }

    function test_UnauthorizedMintAuthorization_Fails() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(MintController.UnauthorizedMinter.selector, unauthorizedUser));
        mintController.executeMint(recipient, 100 * 1e6, 1);
    }

    function test_BypassingTokenAuthorization_Fails() public {
        // Revoke MintController's minter authorization on the token contract itself
        token.setAuthorizedMinter(address(mintController), false);

        vm.prank(minter);
        vm.expectRevert(MockUSDXToken.UnauthorizedTokenMinter.selector);
        mintController.executeMint(recipient, 100 * 1e6, 1);
    }

    function test_Replay_Fails() public {
        uint256 amount = 100 * 1e6;
        uint256 nonce = 42;

        vm.prank(minter);
        mintController.executeMint(recipient, amount, nonce);

        bytes32 authHash = mintController.getAuthorizationHash(recipient, amount, nonce);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(MintController.MintAuthorizationAlreadyUsed.selector, authHash));
        mintController.executeMint(recipient, amount, nonce);
    }

    function test_StaleReserveState_Fails() public {
        reserveAttestation.setReserveData(1_000_000 * 1e6, block.timestamp - 3600, true, true);

        vm.prank(minter);
        vm.expectRevert(MintController.ReserveDataStale.selector);
        mintController.executeMint(recipient, 100 * 1e6, 1);
    }

    function test_UnavailableReserveState_FailsClosed() public {
        // Test case A: isAvailable is false
        reserveAttestation.setReserveData(1_000_000 * 1e6, block.timestamp, false, false);

        vm.prank(minter);
        vm.expectRevert(MintController.ReserveDataUnavailable.selector);
        mintController.executeMint(recipient, 100 * 1e6, 1);

        // Test case B: Reserve contract call reverts
        reserveAttestation.setShouldRevert(true);

        vm.prank(minter);
        vm.expectRevert(MintController.ReserveDataUnavailable.selector);
        mintController.executeMint(recipient, 100 * 1e6, 2);
    }

    // --- EIP-712 Signature Authorization Tests ---

    function test_SignatureMint_Succeeds() public {
        uint256 amount = 250_000 * 1e6;
        uint256 nonce = 100;
        uint256 deadline = block.timestamp + 1000;

        bytes32 structHash = keccak256(
            abi.encode(mintController.MINT_AUTHORIZATION_TYPEHASH(), recipient, amount, nonce, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", mintController.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(minterPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        mintController.executeMintWithSignature(recipient, amount, nonce, deadline, signature);

        assertEq(token.totalSupply(), amount);
        assertEq(token.balanceOf(recipient), amount);
    }

    function test_SignatureMint_Expired_Fails() public {
        uint256 amount = 250_000 * 1e6;
        uint256 nonce = 101;
        uint256 deadline = block.timestamp - 1;

        bytes32 structHash = keccak256(
            abi.encode(mintController.MINT_AUTHORIZATION_TYPEHASH(), recipient, amount, nonce, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", mintController.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(minterPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(MintController.MintAuthorizationExpired.selector, deadline, block.timestamp)
        );
        mintController.executeMintWithSignature(recipient, amount, nonce, deadline, signature);
    }

    function test_SignatureMint_UnauthorizedSigner_Fails() public {
        uint256 unauthorizedKey = 0xBAD;
        uint256 amount = 250_000 * 1e6;
        uint256 nonce = 102;
        uint256 deadline = block.timestamp + 1000;

        bytes32 structHash = keccak256(
            abi.encode(mintController.MINT_AUTHORIZATION_TYPEHASH(), recipient, amount, nonce, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", mintController.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(unauthorizedKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        address badSigner = vm.addr(unauthorizedKey);
        vm.expectRevert(abi.encodeWithSelector(MintController.UnauthorizedMinter.selector, badSigner));
        mintController.executeMintWithSignature(recipient, amount, nonce, deadline, signature);
    }

    function test_WrongRecipientOrAmount_Fails() public {
        // Authorized minter signs authorization for recipient and amount X
        uint256 signedAmount = 500_000 * 1e6;
        uint256 nonce = 200;
        uint256 deadline = block.timestamp + 1000;

        bytes32 structHash = keccak256(
            abi.encode(mintController.MINT_AUTHORIZATION_TYPEHASH(), recipient, signedAmount, nonce, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", mintController.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(minterPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Attempting to execute with wrong recipient fails signature verification
        address wrongRecipient = address(0x8888);
        vm.expectRevert(); // Recovered signer will be random address, reverting with UnauthorizedMinter
        mintController.executeMintWithSignature(wrongRecipient, signedAmount, nonce, deadline, signature);

        // Attempting to execute with wrong amount fails signature verification
        uint256 wrongAmount = 600_000 * 1e6;
        vm.expectRevert();
        mintController.executeMintWithSignature(recipient, wrongAmount, nonce, deadline, signature);
    }

    function test_AuthorizedMintRequest_WrongRecipientOrAmount_Fails() public {
        uint256 amount = 100_000 * 1e6;
        uint256 nonce = 300;

        vm.prank(minter);
        mintController.authorizeMintRequest(recipient, amount, nonce);

        // Attempting to execute authorized mint with wrong recipient fails
        address wrongRecipient = address(0x7777);
        bytes32 wrongAuthHash = mintController.getAuthorizationHash(wrongRecipient, amount, nonce);
        vm.expectRevert(abi.encodeWithSelector(MintController.MintNotAuthorized.selector, wrongAuthHash));
        mintController.executeAuthorizedMint(wrongRecipient, amount, nonce);

        // Executing with correct parameters succeeds
        mintController.executeAuthorizedMint(recipient, amount, nonce);
    }

    // --- Admin Management Tests ---

    function test_AdminAccessControl() public {
        address newMinter = address(0x5555);

        // Non-admin cannot add minter
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSelector(MintController.UnauthorizedAdmin.selector, unauthorizedUser));
        mintController.addMinter(newMinter);

        // Admin adds minter
        vm.prank(admin);
        mintController.addMinter(newMinter);
        assertTrue(mintController.minters(newMinter));

        // Admin removes minter
        vm.prank(admin);
        mintController.removeMinter(newMinter);
        assertFalse(mintController.minters(newMinter));
    }

    // --- Fuzz / Property Test for Solvency Invariant ---

    function testFuzz_SolvencyInvariant(uint256 initialSupply, uint256 mintAmount, uint256 reserves) public {
        // Bound inputs to reasonable 6-decimal numbers to avoid scalar overflow issues
        initialSupply = bound(initialSupply, 0, 1e12 * 1e6);
        mintAmount = bound(mintAmount, 0, 1e12 * 1e6);
        reserves = bound(reserves, 0, 1e12 * 1e6);

        // Set initial supply directly on mock token
        token = new MockUSDXToken();
        if (initialSupply > 0) {
            token.setAuthorizedMinter(address(this), true);
            token.mint(address(0xAAAA), initialSupply);
        }

        reserveAttestation = new MockReserveAttestation(reserves, block.timestamp, true, false);
        mintController = new MintController(address(token), address(reserveAttestation), admin);

        vm.prank(admin);
        mintController.addMinter(minter);
        token.setAuthorizedMinter(address(mintController), true);

        bool expectSuccess = (mintAmount > 0) && (initialSupply + mintAmount <= reserves);

        vm.prank(minter);
        if (expectSuccess) {
            mintController.executeMint(recipient, mintAmount, 999);
            // Verify core invariant holding post-execution
            assertTrue(token.totalSupply() <= reserves);
            assertEq(token.totalSupply(), initialSupply + mintAmount);
        } else {
            vm.expectRevert();
            mintController.executeMint(recipient, mintAmount, 999);
        }
    }
}
