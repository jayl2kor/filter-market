import { describe, it } from "node:test";
import assert from "node:assert/strict";

import { verifyWithVerifier } from "../lib/lib/appleReceiptVerifier.js";

class FakeVerifier {
  constructor(payload) {
    this.payload = payload;
  }
  async verifyAndDecodeTransaction(_jws) {
    if (this.payload instanceof Error) throw this.payload;
    return this.payload;
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
});
