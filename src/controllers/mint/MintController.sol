// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IReserveAttestation} from "../../interfaces/reserve/IReserveAttestation.sol";
import {IUSDXToken} from "./IUSDXToken.sol";

/**
 * @title MintController
 * @notice Enforces the protocol mint authorization boundary and the hard solvency invariant:
 *         totalSupply + mintAmount <= acceptedEligibleReserves
 * @dev This controller does NOT trust arbitrary callers for reserve data. Accepted reserves
 *      are established solely through an external multi-attestor quorum mechanism via
 *      the IReserveAttestation interface.
 */
contract MintController {
    // --- Custom Errors ---
    error UnauthorizedMinter(address caller);
    error UnauthorizedAdmin(address caller);
    error InvalidMintAmount();
    error InvalidRecipient();
    error MintAuthorizationAlreadyUsed(bytes32 authHash);
    error MintAuthorizationExpired(uint256 deadline, uint256 currentTimestamp);
    error MintNotAuthorized(bytes32 authHash);
    error ReserveDataUnavailable();
    error ReserveDataStale();
    error SolvencyInvariantViolated(uint256 currentSupply, uint256 mintAmount, uint256 acceptedReserves);
    error ZeroAddressNotAllowed();

    // --- Events ---
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event MintAuthorized(bytes32 indexed authHash, address indexed recipient, uint256 amount, uint256 nonce, address indexed minter);
    event MintExecuted(bytes32 indexed authHash, address indexed recipient, uint256 amount, uint256 totalSupplyAfter, uint256 acceptedReserves);

    // --- State Variables ---
    IUSDXToken public immutable usdxToken;
    IReserveAttestation public immutable reserveAttestation;

    address public admin;
    mapping(address => bool) public minters;
    mapping(bytes32 => bool) public usedAuthorizations;
    mapping(bytes32 => bool) public authorizedMintHashes;

    // --- EIP-712 Constants ---
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant MINT_AUTHORIZATION_TYPEHASH =
        keccak256("MintAuthorization(address recipient,uint256 amount,uint256 nonce,uint256 deadline)");

    modifier onlyAdmin() {
        if (msg.sender != admin) revert UnauthorizedAdmin(msg.sender);
        _;
    }

    modifier onlyMinter() {
        if (!minters[msg.sender]) revert UnauthorizedMinter(msg.sender);
        _;
    }

    /**
     * @notice Initializes the MintController contract.
     * @param _usdxToken Address of the USDX TRC-20 token contract.
     * @param _reserveAttestation Address of the Reserve Attestation contract.
     * @param _admin Address of the governance admin.
     */
    constructor(address _usdxToken, address _reserveAttestation, address _admin) {
        if (_usdxToken == address(0) || _reserveAttestation == address(0) || _admin == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        usdxToken = IUSDXToken(_usdxToken);
        reserveAttestation = IReserveAttestation(_reserveAttestation);
        admin = _admin;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("USDX Mint Controller")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        emit AdminTransferred(address(0), _admin);
    }

    // --- Admin Functions ---

    function addMinter(address minter) external onlyAdmin {
        if (minter == address(0)) revert ZeroAddressNotAllowed();
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external onlyAdmin {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert ZeroAddressNotAllowed();
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    // --- Mint Authorization & Execution ---

    /**
     * @notice Computes the unique authorization hash for a mint operation.
     * @param recipient Target address for minted tokens.
     * @param amount Token amount to mint (6 decimals).
     * @param nonce Unique nonce preventing replay.
     * @return Unique authorization hash.
     */
    function getAuthorizationHash(address recipient, uint256 amount, uint256 nonce) public view returns (bytes32) {
        return keccak256(abi.encode(recipient, amount, nonce, block.chainid, address(this)));
    }

    /**
     * @notice Executes a mint operation directly by an authorized minter role.
     * @param recipient Target address to receive minted USDX.
     * @param amount Amount of USDX to mint (6 decimals).
     * @param nonce Unique authorization nonce.
     */
    function executeMint(address recipient, uint256 amount, uint256 nonce) external onlyMinter {
        bytes32 authHash = getAuthorizationHash(recipient, amount, nonce);
        _executeMint(recipient, amount, authHash);
    }

    /**
     * @notice Pre-authorizes a mint request on-chain by an authorized minter.
     * @param recipient Target address to receive minted USDX.
     * @param amount Amount of USDX to mint.
     * @param nonce Unique authorization nonce.
     */
    function authorizeMintRequest(address recipient, uint256 amount, uint256 nonce) external onlyMinter {
        if (amount == 0) revert InvalidMintAmount();
        if (recipient == address(0)) revert InvalidRecipient();

        bytes32 authHash = getAuthorizationHash(recipient, amount, nonce);
        if (usedAuthorizations[authHash]) revert MintAuthorizationAlreadyUsed(authHash);

        authorizedMintHashes[authHash] = true;
        emit MintAuthorized(authHash, recipient, amount, nonce, msg.sender);
    }

    /**
     * @notice Executes a previously pre-authorized mint request.
     * @param recipient Target address to receive minted USDX.
     * @param amount Amount of USDX to mint.
     * @param nonce Unique authorization nonce.
     */
    function executeAuthorizedMint(address recipient, uint256 amount, uint256 nonce) external {
        bytes32 authHash = getAuthorizationHash(recipient, amount, nonce);
        if (!authorizedMintHashes[authHash]) revert MintNotAuthorized(authHash);

        _executeMint(recipient, amount, authHash);
    }

    /**
     * @notice Executes a mint operation backed by an EIP-712 signature from an authorized minter.
     * @param recipient Target address to receive minted USDX.
     * @param amount Amount of USDX to mint.
     * @param nonce Unique authorization nonce.
     * @param deadline Expiration timestamp for the authorization.
     * @param signature Cryptographic EIP-712 signature from an authorized minter.
     */
    function executeMintWithSignature(
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) revert MintAuthorizationExpired(deadline, block.timestamp);

        bytes32 structHash = keccak256(abi.encode(MINT_AUTHORIZATION_TYPEHASH, recipient, amount, nonce, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));

        address signer = _recoverSigner(digest, signature);
        if (signer == address(0) || !minters[signer]) revert UnauthorizedMinter(signer);

        bytes32 authHash = getAuthorizationHash(recipient, amount, nonce);
        _executeMint(recipient, amount, authHash);
    }

    // --- Internal Logic ---

    function _executeMint(
        address recipient,
        uint256 amount,
        bytes32 authHash
    ) internal {
        if (amount == 0) revert InvalidMintAmount();
        if (recipient == address(0)) revert InvalidRecipient();
        if (usedAuthorizations[authHash]) revert MintAuthorizationAlreadyUsed(authHash);

        usedAuthorizations[authHash] = true;

        uint256 acceptedReserves = _getValidatedReserves();
        uint256 currentSupply = usdxToken.totalSupply();

        // Enforce hard solvency invariant: currentTotalSupply + mintAmount <= acceptedEligibleReserves
        uint256 newSupply = currentSupply + amount;
        if (newSupply < currentSupply || newSupply > acceptedReserves) {
            revert SolvencyInvariantViolated(currentSupply, amount, acceptedReserves);
        }

        emit MintExecuted(authHash, recipient, amount, newSupply, acceptedReserves);

        // Delegate minting to token (which enforces token's own authorization boundary)
        usdxToken.mint(recipient, amount);
    }

    function _getValidatedReserves() internal view returns (uint256) {
        try reserveAttestation.getAcceptedEligibleReserves() returns (IReserveAttestation.ReserveData memory data) {
            if (!data.isAvailable) revert ReserveDataUnavailable();
            if (data.isStale) revert ReserveDataStale();
            return data.amount;
        } catch {
            revert ReserveDataUnavailable();
        }
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        if (signature.length != 65) return address(0);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (v < 27) v += 27;
        if (v != 27 && v != 28) return address(0);
        // Prevent signature malleability
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E735E5A921246676F611E0089D0) {
            return address(0);
        }
        return ecrecover(digest, v, r, s);
    }
}
