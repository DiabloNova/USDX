const assert = require('assert');

const UsdtxToken = artifacts.require('UsdtxToken');

const UNIT = 1000000; // 6 decimals
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000';

function normalize(value) {
  const raw = String(value);
  if (typeof tronWeb !== 'undefined' && tronWeb && tronWeb.address) {
    try {
      return tronWeb.address.fromHex(tronWeb.address.toHex(raw));
    } catch (error) {
      /* not a TRON address, fall through */
    }
  }
  return raw.toLowerCase();
}

function sameAddress(a, b) {
  return normalize(a) === normalize(b);
}

function num(value) {
  return String(value);
}

async function mustRevert(promise, label) {
  try {
    await promise;
  } catch (error) {
    return error;
  }
  assert.fail(`expected revert: ${label}`);
}

contract('UsdtxToken', (accounts) => {
  const [owner, admin2, alice, bob, feeCollector] = accounts;

  let token;

  beforeEach(async () => {
    token = await UsdtxToken.new(owner, { from: owner });
  });

  // --- deployment & metadata ------------------------------------------------

  it('deploys with the correct metadata', async () => {
    assert.strictEqual(await token.name(), 'USDTX');
    assert.strictEqual(await token.symbol(), 'USDTX');
    assert.strictEqual(num(await token.decimals()), '6');
  });

  it('has zero initial supply and no initial balances', async () => {
    assert.strictEqual(num(await token.totalSupply()), '0');
    for (let i = 0; i < Math.min(accounts.length, 5); i++) {
      assert.strictEqual(num(await token.balanceOf(accounts[i])), '0');
    }
  });

  it('starts unpaused, fee-free, with the owner as admin and multisig mode disabled', async () => {
    assert.strictEqual(await token.paused(), false);
    assert.strictEqual(num(await token.basisPointsRate()), '0');
    assert.strictEqual(num(await token.maximumFee()), '0');
    assert.strictEqual(num(await token.approvedReserve()), '0');
    assert.ok(sameAddress(await token.admin(), owner));
    assert.strictEqual(await token.multisigModeEnabled(), false);
  });

  it('rejects a zero-address owner at deployment', async () => {
    await mustRevert(UsdtxToken.new(ZERO_ADDRESS, { from: owner }), 'zero owner');
  });

  // --- reserve approval -----------------------------------------------------

  it('lets only the admin approve the bank reserve', async () => {
    await mustRevert(token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: alice }), 'unauthorized reserve');

    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    assert.strictEqual(num(await token.approvedReserve()), String(1000 * UNIT));
    assert.strictEqual(num(await token.mintableAmount()), String(1000 * UNIT));
    assert.notStrictEqual(num(await token.reserveUpdatedAt()), '0');
  });

  it('does not mint anything when the reserve is approved', async () => {
    await token.approveReserve(5000 * UNIT, ZERO_BYTES32, { from: owner });
    assert.strictEqual(num(await token.totalSupply()), '0');
    assert.strictEqual(num(await token.balanceOf(owner)), '0');
  });

  // --- minting --------------------------------------------------------------

  it('rejects unauthorized mint attempts', async () => {
    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await mustRevert(token.mint(alice, 100 * UNIT, { from: alice }), 'unauthorized mint');
    await mustRevert(token.mint(alice, 100 * UNIT, { from: bob }), 'unauthorized mint');
    assert.strictEqual(num(await token.totalSupply()), '0');
  });

  it('lets the admin mint within the approved reserve', async () => {
    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await token.mint(alice, 400 * UNIT, { from: owner });

    assert.strictEqual(num(await token.balanceOf(alice)), String(400 * UNIT));
    assert.strictEqual(num(await token.totalSupply()), String(400 * UNIT));
    assert.strictEqual(num(await token.mintableAmount()), String(600 * UNIT));
  });

  it('rejects minting above the approved reserve, to the zero address, or of zero', async () => {
    await mustRevert(token.mint(alice, 1 * UNIT, { from: owner }), 'no reserve approved yet');

    await token.approveReserve(100 * UNIT, ZERO_BYTES32, { from: owner });
    await mustRevert(token.mint(alice, 101 * UNIT, { from: owner }), 'above reserve');
    await mustRevert(token.mint(ZERO_ADDRESS, 10 * UNIT, { from: owner }), 'zero recipient');
    await mustRevert(token.mint(alice, 0, { from: owner }), 'zero amount');
    assert.strictEqual(num(await token.totalSupply()), '0');
  });

  // --- transfers, allowances ------------------------------------------------

  it('transfers tokens', async () => {
    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await token.mint(alice, 500 * UNIT, { from: owner });

    await token.transfer(bob, 200 * UNIT, { from: alice });

    assert.strictEqual(num(await token.balanceOf(alice)), String(300 * UNIT));
    assert.strictEqual(num(await token.balanceOf(bob)), String(200 * UNIT));
    assert.strictEqual(num(await token.totalSupply()), String(500 * UNIT));
  });

  it('rejects transfers above the balance and to the zero address (arithmetic safety)', async () => {
    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await token.mint(alice, 10 * UNIT, { from: owner });

    await mustRevert(token.transfer(bob, 11 * UNIT, { from: alice }), 'insufficient balance');
    await mustRevert(token.transfer(bob, 1 * UNIT, { from: bob }), 'empty balance');
    await mustRevert(token.transfer(ZERO_ADDRESS, 1 * UNIT, { from: alice }), 'zero recipient');
    assert.strictEqual(num(await token.balanceOf(alice)), String(10 * UNIT));
  });

  it('approves and reports allowances', async () => {
    await token.approve(bob, 250 * UNIT, { from: alice });
    assert.strictEqual(num(await token.allowance(alice, bob)), String(250 * UNIT));

    await token.approve(bob, 0, { from: alice });
    assert.strictEqual(num(await token.allowance(alice, bob)), '0');

    await mustRevert(token.approve(ZERO_ADDRESS, 1 * UNIT, { from: alice }), 'zero spender');
  });

  it('supports transferFrom within the allowance', async () => {
    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await token.mint(alice, 500 * UNIT, { from: owner });
    await token.approve(bob, 300 * UNIT, { from: alice });

    await token.transferFrom(alice, feeCollector, 120 * UNIT, { from: bob });

    assert.strictEqual(num(await token.balanceOf(feeCollector)), String(120 * UNIT));
    assert.strictEqual(num(await token.allowance(alice, bob)), String(180 * UNIT));

    await mustRevert(token.transferFrom(alice, bob, 181 * UNIT, { from: bob }), 'above allowance');
  });

  // --- pause ----------------------------------------------------------------

  it('pauses and unpauses, and rejects unauthorized pause calls', async () => {
    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await token.mint(alice, 100 * UNIT, { from: owner });

    await mustRevert(token.pause({ from: alice }), 'unauthorized pause');

    await token.pause({ from: owner });
    assert.strictEqual(await token.paused(), true);

    await mustRevert(token.transfer(bob, 1 * UNIT, { from: alice }), 'transfer while paused');
    await mustRevert(token.approve(bob, 1 * UNIT, { from: alice }), 'approve while paused');
    // Pausing must never open a mint path.
    await mustRevert(token.mint(alice, 1 * UNIT, { from: alice }), 'unauthorized mint while paused');
    await mustRevert(token.mint(alice, 1 * UNIT, { from: owner }), 'admin mint while paused');

    await mustRevert(token.unpause({ from: alice }), 'unauthorized unpause');
    await token.unpause({ from: owner });
    assert.strictEqual(await token.paused(), false);

    await token.transfer(bob, 1 * UNIT, { from: alice });
    assert.strictEqual(num(await token.balanceOf(bob)), String(1 * UNIT));
  });

  // --- admin & ownership ----------------------------------------------------

  it('lets only the owner change the admin, and moves admin rights with it', async () => {
    await mustRevert(token.setAdmin(admin2, { from: alice }), 'unauthorized setAdmin');

    await token.setAdmin(admin2, { from: owner });
    assert.ok(sameAddress(await token.admin(), admin2));
    assert.strictEqual(await token.multisigModeEnabled(), true);

    await mustRevert(token.approveReserve(1 * UNIT, ZERO_BYTES32, { from: owner }), 'owner is no longer admin');
    await token.approveReserve(50 * UNIT, ZERO_BYTES32, { from: admin2 });
    await mustRevert(token.mint(alice, 10 * UNIT, { from: owner }), 'owner cannot mint');
    await token.mint(alice, 10 * UNIT, { from: admin2 });
    assert.strictEqual(num(await token.balanceOf(alice)), String(10 * UNIT));

    // Disabling multisig mode hands admin rights back to the owner.
    await token.setAdmin(ZERO_ADDRESS, { from: owner });
    assert.ok(sameAddress(await token.admin(), owner));
    assert.strictEqual(await token.multisigModeEnabled(), false);
  });

  it('transfers ownership in two steps', async () => {
    await mustRevert(token.transferOwnership(alice, { from: alice }), 'unauthorized transfer');
    await mustRevert(token.transferOwnership(ZERO_ADDRESS, { from: owner }), 'zero owner');

    await token.transferOwnership(alice, { from: owner });
    assert.ok(sameAddress(await token.owner(), owner));
    await mustRevert(token.acceptOwnership({ from: bob }), 'wrong acceptor');

    await token.acceptOwnership({ from: alice });
    assert.ok(sameAddress(await token.owner(), alice));
    assert.ok(sameAddress(await token.admin(), alice));
    await mustRevert(token.setAdmin(bob, { from: owner }), 'previous owner lost rights');
  });

  // --- fees -----------------------------------------------------------------

  it('charges no fee by default', async () => {
    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await token.mint(alice, 100 * UNIT, { from: owner });

    assert.strictEqual(num(await token.calculateFee(100 * UNIT)), '0');
    await token.transfer(bob, 100 * UNIT, { from: alice });
    assert.strictEqual(num(await token.balanceOf(bob)), String(100 * UNIT));
  });

  it('applies bounded, admin-controlled fees only when explicitly configured', async () => {
    await mustRevert(token.setFeeParameters(10, 1 * UNIT, feeCollector, { from: alice }), 'unauthorized fee change');
    await mustRevert(token.setFeeParameters(21, 1 * UNIT, feeCollector, { from: owner }), 'rate above cap');
    await mustRevert(token.setFeeParameters(10, 1 * UNIT, ZERO_ADDRESS, { from: owner }), 'missing recipient');
    await mustRevert(token.setFeeParameters(10, 0, feeCollector, { from: owner }), 'zero cap with non-zero rate');

    await token.setFeeParameters(10, 1 * UNIT, feeCollector, { from: owner }); // 10 bps = 0.10%
    assert.strictEqual(num(await token.basisPointsRate()), '10');
    assert.strictEqual(num(await token.calculateFee(100 * UNIT)), '100000'); // 0.1 USDTX

    await token.approveReserve(1000 * UNIT, ZERO_BYTES32, { from: owner });
    await token.mint(alice, 100 * UNIT, { from: owner });
    await token.transfer(bob, 100 * UNIT, { from: alice });

    assert.strictEqual(num(await token.balanceOf(bob)), '99900000'); // 99.9 USDTX
    assert.strictEqual(num(await token.balanceOf(feeCollector)), '100000'); // 0.1 USDTX
    assert.strictEqual(num(await token.balanceOf(alice)), '0');
    assert.strictEqual(num(await token.totalSupply()), String(100 * UNIT));

    // Minting is never fee-charged.
    await token.mint(alice, 10 * UNIT, { from: owner });
    assert.strictEqual(num(await token.balanceOf(alice)), String(10 * UNIT));

    await token.setFeeParameters(0, 0, ZERO_ADDRESS, { from: owner });
    assert.strictEqual(num(await token.calculateFee(100 * UNIT)), '0');
  });
});
