const assert = require('assert');

const MultiSigWallet = artifacts.require('MultiSigWallet');
const UsdtxToken = artifacts.require('UsdtxToken');

const UNIT = 1000000; // 6 decimals
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';
const ZERO_BYTES32 = '0x0000000000000000000000000000000000000000000000000000000000000000';

function num(value) {
  return String(value);
}

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

function executedFlag(txn) {
  return txn.executed !== undefined ? txn.executed : txn[3];
}

async function mustRevert(promise, label) {
  try {
    await promise;
  } catch (error) {
    return error;
  }
  assert.fail(`expected revert: ${label}`);
}

/** Converts a TRON base58/hex address into the 0x form the ABI coder expects. */
function toAbiAddress(value) {
  const raw = String(value);
  if (raw.startsWith('0x') && raw.length === 42) {
    return raw;
  }
  if (typeof tronWeb !== 'undefined' && tronWeb && tronWeb.address) {
    const hex = tronWeb.address.toHex(raw); // 41-prefixed, 42 chars
    return `0x${hex.slice(2)}`;
  }
  return raw;
}

/**
 * Encodes a call for {MultiSigWallet.submitTransaction}. Uses the web3 ABI coder
 * when running under Truffle and TronWeb's bundled coder under TronBox.
 */
function encodeCall(instance, signature, types, args) {
  const method = signature.slice(0, signature.indexOf('('));

  if (instance.contract && instance.contract.methods && instance.contract.methods[method]) {
    return instance.contract.methods[method](...args).encodeABI();
  }

  if (typeof tronWeb !== 'undefined' && tronWeb && tronWeb.utils && tronWeb.utils.ethersUtils) {
    const { keccak256, toUtf8Bytes, defaultAbiCoder } = tronWeb.utils.ethersUtils;
    const selector = keccak256(toUtf8Bytes(signature)).slice(0, 10);
    const encodedArgs = types.length === 0 ? '' : defaultAbiCoder.encode(types, args).slice(2);
    return selector + encodedArgs;
  }

  throw new Error(`no ABI encoder available for ${signature}`);
}

contract('MultiSigWallet', (accounts) => {
  const [o1, o2, o3, o4, o5, outsider, alice] = accounts;
  const fiveOwners = [o1, o2, o3, o4, o5];

  // A harmless payload used to exercise the confirmation machinery.
  function noopPayload(wallet) {
    return encodeCall(wallet, 'changeRequirement(uint256)', ['uint256'], [1]);
  }

  // --- configuration --------------------------------------------------------

  it('accepts thresholds 0 through 5', async () => {
    for (let threshold = 0; threshold <= 5; threshold++) {
      const wallet = await MultiSigWallet.new(fiveOwners, threshold, { from: o1 });
      assert.strictEqual(num(await wallet.required()), String(threshold));
      assert.strictEqual(num(await wallet.ownerCount()), '5');
    }
  });

  it('treats threshold 0 as "confirmation requirement disabled", not as five signatures', async () => {
    const wallet = await MultiSigWallet.new(fiveOwners, 0, { from: o1 });
    await wallet.submitTransaction(wallet.address, 0, noopPayload(wallet), { from: o1 });
    const id = 0; // first submission on a fresh wallet

    assert.strictEqual(await wallet.isConfirmed(id), true);
    assert.strictEqual(num(await wallet.getConfirmationCount(id)), '0');

    await wallet.executeTransaction(id, { from: o2 });
    assert.strictEqual(executedFlag(await wallet.getTransaction(id)), true);
    assert.strictEqual(num(await wallet.required()), '1'); // payload applied
  });

  it('rejects thresholds above the owner count and above the 0-5 range', async () => {
    await mustRevert(MultiSigWallet.new([o1, o2], 3, { from: o1 }), 'threshold above owner count');
    await mustRevert(MultiSigWallet.new([o1], 2, { from: o1 }), 'threshold above owner count');
    await mustRevert(MultiSigWallet.new(fiveOwners, 6, { from: o1 }), 'threshold above range');
    await mustRevert(MultiSigWallet.new([], 0, { from: o1 }), 'no owners');
    await mustRevert(MultiSigWallet.new([o1, ZERO_ADDRESS], 1, { from: o1 }), 'zero-address owner');
    await mustRevert(MultiSigWallet.new([o1, o1], 1, { from: o1 }), 'duplicate owner');
  });

  it('executes with threshold 1 after the submitter auto-confirmation', async () => {
    const wallet = await MultiSigWallet.new(fiveOwners, 1, { from: o1 });
    await wallet.submitTransaction(wallet.address, 0, noopPayload(wallet), { from: o1 });

    assert.strictEqual(num(await wallet.getConfirmationCount(0)), '1');
    assert.strictEqual(await wallet.isConfirmed(0), true);
    await wallet.executeTransaction(0, { from: o1 });
    assert.strictEqual(executedFlag(await wallet.getTransaction(0)), true);
  });

  it('enforces threshold 3 end to end', async () => {
    const wallet = await MultiSigWallet.new(fiveOwners, 3, { from: o1 });
    const payload = encodeCall(wallet, 'changeRequirement(uint256)', ['uint256'], [2]);
    await wallet.submitTransaction(wallet.address, 0, payload, { from: o1 });

    // execution before the threshold is met
    await mustRevert(wallet.executeTransaction(0, { from: o1 }), 'below threshold');

    await wallet.confirmTransaction(0, { from: o2 });
    await mustRevert(wallet.executeTransaction(0, { from: o2 }), 'still below threshold');

    // duplicate confirmation
    await mustRevert(wallet.confirmTransaction(0, { from: o2 }), 'duplicate confirmation');

    // revocation drops the count again
    await wallet.revokeConfirmation(0, { from: o2 });
    assert.strictEqual(num(await wallet.getConfirmationCount(0)), '1');
    await mustRevert(wallet.executeTransaction(0, { from: o1 }), 'after revocation');
    await mustRevert(wallet.revokeConfirmation(0, { from: o4 }), 'revoke without confirmation');

    await wallet.confirmTransaction(0, { from: o2 });
    await wallet.confirmTransaction(0, { from: o3 });
    assert.strictEqual(num(await wallet.getConfirmationCount(0)), '3');
    assert.strictEqual(await wallet.isConfirmed(0), true);

    await wallet.executeTransaction(0, { from: o3 });
    assert.strictEqual(num(await wallet.required()), '2');

    // replay protection
    await mustRevert(wallet.executeTransaction(0, { from: o1 }), 'replayed execution');
  });

  it('enforces threshold 5 (unanimous)', async () => {
    const wallet = await MultiSigWallet.new(fiveOwners, 5, { from: o1 });
    await wallet.submitTransaction(wallet.address, 0, noopPayload(wallet), { from: o1 });

    await wallet.confirmTransaction(0, { from: o2 });
    await wallet.confirmTransaction(0, { from: o3 });
    await wallet.confirmTransaction(0, { from: o4 });
    await mustRevert(wallet.executeTransaction(0, { from: o1 }), '4 of 5 confirmations');

    await wallet.confirmTransaction(0, { from: o5 });
    assert.strictEqual(num(await wallet.getConfirmationCount(0)), '5');
    await wallet.executeTransaction(0, { from: o5 });
    assert.strictEqual(executedFlag(await wallet.getTransaction(0)), true);
  });

  it('restricts submission, confirmation and execution to owners', async () => {
    const wallet = await MultiSigWallet.new([o1, o2, o3], 2, { from: o1 });
    await mustRevert(
      wallet.submitTransaction(wallet.address, 0, noopPayload(wallet), { from: outsider }),
      'outsider submission'
    );

    await wallet.submitTransaction(wallet.address, 0, noopPayload(wallet), { from: o1 });
    await mustRevert(wallet.confirmTransaction(0, { from: outsider }), 'outsider confirmation');
    await wallet.confirmTransaction(0, { from: o2 });
    await mustRevert(wallet.executeTransaction(0, { from: outsider }), 'outsider execution');
    await mustRevert(wallet.confirmTransaction(7, { from: o2 }), 'unknown transaction');
    await mustRevert(
      wallet.submitTransaction(ZERO_ADDRESS, 0, noopPayload(wallet), { from: o1 }),
      'zero destination'
    );
  });

  it('only changes owners through the wallet itself', async () => {
    const wallet = await MultiSigWallet.new([o1, o2, o3], 2, { from: o1 });

    await mustRevert(wallet.addOwner(o4, { from: o1 }), 'direct addOwner');
    await mustRevert(wallet.removeOwner(o2, { from: o1 }), 'direct removeOwner');
    await mustRevert(wallet.changeRequirement(1, { from: o1 }), 'direct changeRequirement');

    const addPayload = encodeCall(wallet, 'addOwner(address)', ['address'], [toAbiAddress(o4)]);
    await wallet.submitTransaction(wallet.address, 0, addPayload, { from: o1 });
    await wallet.confirmTransaction(0, { from: o2 });
    await wallet.executeTransaction(0, { from: o1 });

    assert.strictEqual(await wallet.isOwner(o4), true);
    assert.strictEqual(num(await wallet.ownerCount()), '4');
  });

  it('rejects owner removal that would leave the threshold above the owner count', async () => {
    const wallet = await MultiSigWallet.new([o1, o2, o3], 3, { from: o1 });
    const removePayload = encodeCall(wallet, 'removeOwner(address)', ['address'], [toAbiAddress(o3)]);

    await wallet.submitTransaction(wallet.address, 0, removePayload, { from: o1 });
    await wallet.confirmTransaction(0, { from: o2 });
    await wallet.confirmTransaction(0, { from: o3 });

    await mustRevert(wallet.executeTransaction(0, { from: o1 }), 'threshold would exceed owner count');
    assert.strictEqual(num(await wallet.ownerCount()), '3');
  });

  // --- USDTX admin integration ---------------------------------------------

  it('acts as the USDTX admin without ever minting by itself', async () => {
    const wallet = await MultiSigWallet.new([o1, o2, o3], 2, { from: o1 });
    const token = await UsdtxToken.new(o1, { from: o1 });
    await token.setAdmin(wallet.address, { from: o1 });

    assert.ok(sameAddress(await token.admin(), wallet.address));
    assert.strictEqual(await token.multisigModeEnabled(), true);

    // Owners cannot mint directly, only through a confirmed wallet transaction.
    await mustRevert(token.mint(alice, 1 * UNIT, { from: o1 }), 'owner cannot mint in multisig mode');
    await mustRevert(token.approveReserve(1 * UNIT, ZERO_BYTES32, { from: o1 }), 'owner cannot approve reserve');

    const reservePayload = encodeCall(
      token,
      'approveReserve(uint256,bytes32)',
      ['uint256', 'bytes32'],
      [String(500 * UNIT), ZERO_BYTES32]
    );
    await wallet.submitTransaction(token.address, 0, reservePayload, { from: o1 });
    await wallet.confirmTransaction(0, { from: o2 });
    await wallet.executeTransaction(0, { from: o1 });
    assert.strictEqual(num(await token.approvedReserve()), String(500 * UNIT));

    const mintPayload = encodeCall(
      token,
      'mint(address,uint256)',
      ['address', 'uint256'],
      [toAbiAddress(alice), String(200 * UNIT)]
    );
    await wallet.submitTransaction(token.address, 0, mintPayload, { from: o1 });
    await mustRevert(wallet.executeTransaction(1, { from: o1 }), 'mint before threshold');

    await wallet.confirmTransaction(1, { from: o3 });
    await wallet.executeTransaction(1, { from: o1 });

    assert.strictEqual(num(await token.balanceOf(alice)), String(200 * UNIT));
    assert.strictEqual(num(await token.totalSupply()), String(200 * UNIT));
    assert.strictEqual(num(await token.balanceOf(wallet.address)), '0');

    // Replaying the mint transaction must fail.
    await mustRevert(wallet.executeTransaction(1, { from: o2 }), 'replayed mint');
    assert.strictEqual(num(await token.totalSupply()), String(200 * UNIT));
  });
});
