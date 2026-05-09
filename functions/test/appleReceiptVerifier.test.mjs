import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { EventEmitter } from "node:events";

import {
  CERT_FETCH_TIMEOUT_MS,
  decodeWithVerifier,
  fetchCertForTest,
  loadBundledRootCerts,
  verifyWithVerifier,
} from "../lib/lib/appleReceiptVerifier.js";

class FakeVerifier {
  constructor(payload) {
    this.payload = payload;
  }
  async verifyAndDecodeTransaction(_jws) {
    if (this.payload instanceof Error) throw this.payload;
    return this.payload;
  }
}

class FakeRequest extends EventEmitter {
  destroy(error) {
    this.emit("error", error);
  }
}

describe("verifyWithVerifier", () => {
  it("returns true when productId matches and not revoked", async () => {
    const inner = new FakeVerifier({ productId: "com.jayl2kor.moodit.coins.100" });
    const ok = await verifyWithVerifier(inner, "jws", "com.jayl2kor.moodit.coins.100");
    assert.equal(ok, true);
  });

  it("returns false when productId mismatches", async () => {
    const inner = new FakeVerifier({ productId: "com.other" });
    const ok = await verifyWithVerifier(inner, "jws", "com.jayl2kor.moodit.coins.100");
    assert.equal(ok, false);
  });

  it("returns false when revocationDate present", async () => {
    const inner = new FakeVerifier({
      productId: "com.jayl2kor.moodit.coins.100",
      revocationDate: 1700000000000,
    });
    const ok = await verifyWithVerifier(inner, "jws", "com.jayl2kor.moodit.coins.100");
    assert.equal(ok, false);
  });

  it("returns false when verifier throws", async () => {
    const inner = new FakeVerifier(new Error("invalid signature"));
    const ok = await verifyWithVerifier(inner, "jws", "com.jayl2kor.moodit.coins.100");
    assert.equal(ok, false);
  });

  it("returns false when productId missing on payload", async () => {
    const inner = new FakeVerifier({});
    const ok = await verifyWithVerifier(inner, "jws", "com.jayl2kor.moodit.coins.100");
    assert.equal(ok, false);
  });

  it("loads bundled Apple root certificates without network fetch", () => {
    const certs = loadBundledRootCerts();
    assert.equal(certs.length, 3);
    assert.ok(certs.every((cert) => cert.length > 0));
  });

  it("destroys certificate fetch requests on timeout", async () => {
    const request = new FakeRequest();
    const getImpl = (_url, options, _callback) => {
      assert.equal(options.timeout, CERT_FETCH_TIMEOUT_MS);
      queueMicrotask(() => request.emit("timeout"));
      return request;
    };

    await assert.rejects(
      () => fetchCertForTest("https://apple.example.test/root.cer", getImpl),
      /fetch_cert_timeout/,
    );
  });

  it("decodes transaction metadata needed for subscription status", async () => {
    const payload = {
      productId: "com.jayl2kor.moodit.pro.monthly",
      expiresDate: Date.now() + 86_400_000,
    };
    const decoded = await decodeWithVerifier(new FakeVerifier(payload), "jws");
    assert.deepEqual(decoded, payload);
  });
});
