/**
 * Unit tests for wallet callables (`applyPurchaseFilter`, `applyCreditCoinsFromIAP`,
 * `applyProSubscriptionUpdate`, `applyRefundRequest`) using an in-memory Firestore stub.
 */
import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";

import {
  applyPurchaseFilter,
  applyCreditCoinsFromIAP,
  applyProSubscriptionUpdate,
  applyRefundRequest,
} from "../lib/http/wallet.js";

function makeFakeFirestore(initial = {}) {
  const data = new Map(Object.entries(initial));
  let autoId = 0;

  const docRef = (path) => ({
    _path: path,
    id: path.split("/").pop(),
    collection(name) { return collectionRef(`${path}/${name}`); },
    async get() {
      const record = data.get(path);
      return { exists: record !== undefined, data: () => record };
    },
    async set(payload, opts) {
      const merged = opts && opts.merge ? data.get(path) : undefined;
      data.set(path, { ...(merged ?? {}), ...payload });
    },
  });

  const collectionRef = (path) => ({
    _path: path,
    doc(id) {
      if (id === undefined) {
        autoId += 1;
        return docRef(`${path}/auto-${autoId}`);
      }
      return docRef(`${path}/${id}`);
    },
  });

  const tx = {
    async get(ref) {
      const record = data.get(ref._path);
      return { exists: record !== undefined, data: () => record };
    },
    set(ref, payload, opts) {
      const merged = opts && opts.merge ? data.get(ref._path) : undefined;
      data.set(ref._path, { ...(merged ?? {}), ...payload });
    },
  };

  return {
    _data: data,
    collection(name) { return collectionRef(name); },
    async runTransaction(fn) { return fn(tx); },
  };
}

describe("applyPurchaseFilter", () => {
  let firestore;
  beforeEach(() => {
    firestore = makeFakeFirestore({
      "filters/free-1": { title: "Free", status: "approved", priceCoins: 0 },
      "filters/paid-1": { title: "Paid", status: "approved", priceCoins: 50 },
      "filters/expensive-1": { title: "Expensive", status: "approved", priceCoins: 1000 },
      "filters/pending-1": { title: "Pending", status: "pending_review", priceCoins: 50 },
    });
  });

  it("debits balance and grants entitlement on first purchase", async () => {
    firestore._data.set("users/u-1/wallet/balance", { value: 200 });
    const result = await applyPurchaseFilter("u-1", { filterId: "paid-1" }, { firestore });
    assert.equal(result.ok, true);
    assert.equal(result.balance, 150);
    assert.equal(result.alreadyOwned, false);
    assert.equal(firestore._data.get("users/u-1/wallet/balance").value, 150);
    assert.ok(firestore._data.get("users/u-1/entitlements/paid-1"));
  });

  it("returns alreadyOwned without changing balance on repeat purchase", async () => {
    firestore._data.set("users/u-1/wallet/balance", { value: 200 });
    firestore._data.set("users/u-1/entitlements/paid-1", { filterId: "paid-1" });
    const result = await applyPurchaseFilter("u-1", { filterId: "paid-1" }, { firestore });
    assert.equal(result.alreadyOwned, true);
    assert.equal(result.balance, 200);
  });

  it("rejects when balance is insufficient", async () => {
    firestore._data.set("users/u-1/wallet/balance", { value: 10 });
    await assert.rejects(
      () => applyPurchaseFilter("u-1", { filterId: "expensive-1" }, { firestore }),
      (err) => err && err.code === "failed-precondition" && /insufficient_balance/.test(err.message),
    );
  });

  it("rejects non-approved filters", async () => {
    firestore._data.set("users/u-1/wallet/balance", { value: 200 });
    await assert.rejects(
      () => applyPurchaseFilter("u-1", { filterId: "pending-1" }, { firestore }),
      (err) => err && err.code === "failed-precondition",
    );
  });

  it("rejects missing filter", async () => {
    await assert.rejects(
      () => applyPurchaseFilter("u-1", { filterId: "nope" }, { firestore }),
      (err) => err && err.code === "not-found",
    );
  });

  it("validates filterId payload", async () => {
    await assert.rejects(
      () => applyPurchaseFilter("u-1", {}, { firestore }),
      (err) => err && err.code === "invalid-argument",
    );
  });
});

describe("applyCreditCoinsFromIAP", () => {
  let firestore;
  beforeEach(() => {
    firestore = makeFakeFirestore({});
  });

  const validInput = {
    originalTransactionId: "tx-1",
    productId: "com.jayl2kor.moodit.coins.550",
    signedJWS: "fake-jws",
  };

  it("credits coins on first call", async () => {
    const result = await applyCreditCoinsFromIAP(
      "u-1",
      validInput,
      { firestore, verifyReceipt: async () => true },
    );
    assert.equal(result.ok, true);
    assert.equal(result.creditedAmount, 550);
    assert.equal(result.balance, 550);
    assert.equal(result.duplicate, false);
    assert.equal(firestore._data.get("users/u-1/wallet/balance").value, 550);
    assert.ok(firestore._data.get("walletReceipts/tx-1"));
  });

  it("is idempotent on duplicate transaction id", async () => {
    await applyCreditCoinsFromIAP("u-1", validInput, { firestore, verifyReceipt: async () => true });
    const result = await applyCreditCoinsFromIAP(
      "u-1",
      validInput,
      { firestore, verifyReceipt: async () => true },
    );
    assert.equal(result.duplicate, true);
    assert.equal(firestore._data.get("users/u-1/wallet/balance").value, 550);
  });

  it("rejects unknown product SKU", async () => {
    await assert.rejects(
      () => applyCreditCoinsFromIAP(
        "u-1",
        { ...validInput, productId: "not.real.sku" },
        { firestore, verifyReceipt: async () => true },
      ),
      (err) => err && err.code === "invalid-argument",
    );
  });

  it("rejects when receipt verifier returns false", async () => {
    await assert.rejects(
      () => applyCreditCoinsFromIAP(
        "u-1",
        validInput,
        { firestore, verifyReceipt: async () => false },
      ),
      (err) => err && err.code === "permission-denied",
    );
  });

  it("validates payload", async () => {
    await assert.rejects(
      () => applyCreditCoinsFromIAP("u-1", {}, { firestore, verifyReceipt: async () => true }),
      (err) => err && err.code === "invalid-argument",
    );
  });
});

describe("applyProSubscriptionUpdate", () => {
  it("activates Pro for known SKU", async () => {
    const firestore = makeFakeFirestore({});
    const result = await applyProSubscriptionUpdate(
      "u-1",
      { originalTransactionId: "tx-1", productId: "com.jayl2kor.moodit.pro.monthly", signedJWS: "x" },
      { firestore },
    );
    assert.equal(result.active, true);
    assert.equal(firestore._data.get("users/u-1/proStatus/status").active, true);
  });

  it("rejects non-Pro SKU", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applyProSubscriptionUpdate(
        "u-1",
        { originalTransactionId: "tx-1", productId: "com.jayl2kor.moodit.coins.100", signedJWS: "x" },
        { firestore },
      ),
      (err) => err && err.code === "invalid-argument",
    );
  });
});

describe("applyRefundRequest", () => {
  it("creates refund request doc", async () => {
    const firestore = makeFakeFirestore({});
    const result = await applyRefundRequest(
      "u-1",
      { orderId: "ord-1", reason: "wrong charge" },
      { firestore },
    );
    assert.equal(result.ok, true);
    assert.ok(result.requestId);
  });

  it("rejects empty reason", async () => {
    const firestore = makeFakeFirestore({});
    await assert.rejects(
      () => applyRefundRequest("u-1", { orderId: "ord-1", reason: "" }, { firestore }),
      (err) => err && err.code === "invalid-argument",
    );
  });
});
