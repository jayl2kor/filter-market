/**
 * Apple App Store Server Library JWS verifier.
 *
 * StoreKit 2 transactions arrive as signed JWS strings. We verify:
 *   1. JWS signature chain against Apple root CAs (handled by SignedDataVerifier)
 *   2. bundleId matches our app
 *   3. environment matches deployed stage (PRODUCTION | SANDBOX)
 *   4. productId matches what the client claimed
 *   5. transaction is not revoked
 *
 * Secrets (configure via `firebase functions:secrets:set`):
 *   APP_STORE_ENV  — "PRODUCTION" | "SANDBOX"  (defaults to SANDBOX if unset)
 *   APP_APPLE_ID   — numeric App Apple ID, required only when env=PRODUCTION
 */
import * as https from "https";
import {
  Environment,
  SignedDataVerifier,
} from "@apple/app-store-server-library";

export const APPLE_BUNDLE_ID = "com.jayl2kor.moodit";

/** Apple root CA download URLs — see https://www.apple.com/certificateauthority/ */
const ROOT_CERT_URLS = [
  "https://www.apple.com/certificateauthority/AppleRootCA-G2.cer",
  "https://www.apple.com/certificateauthority/AppleRootCA-G3.cer",
  "https://www.apple.com/appleca/AppleIncRootCertificate.cer",
];

async function fetchCert(url: string): Promise<Buffer> {
  return new Promise<Buffer>((resolve, reject) => {
    const req = https.get(url, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`fetch_cert_failed: ${url} status=${res.statusCode}`));
        return;
      }
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    });
    req.on("error", reject);
  });
}

/** Minimal contract we depend on — keeps tests free of the heavy Apple SDK. */
export interface AppleVerifierLike {
  verifyAndDecodeTransaction(signedJWS: string): Promise<{
    productId?: string;
    revocationDate?: number;
  }>;
}

/** Pure verification logic — testable with a fake AppleVerifierLike. */
export async function verifyWithVerifier(
  inner: AppleVerifierLike,
  signedJWS: string,
  expectedProductId: string,
): Promise<boolean> {
  try {
    const tx = await inner.verifyAndDecodeTransaction(signedJWS);
    if (tx.productId !== expectedProductId) return false;
    if (tx.revocationDate !== undefined) return false;
    return true;
  } catch {
    return false;
  }
}

let verifierPromise: Promise<SignedDataVerifier> | null = null;

async function buildVerifier(): Promise<SignedDataVerifier> {
  const rootCerts = await Promise.all(ROOT_CERT_URLS.map(fetchCert));
  const envStr = process.env.APP_STORE_ENV ?? "SANDBOX";
  const isProd = envStr === "PRODUCTION";
  const env = isProd ? Environment.PRODUCTION : Environment.SANDBOX;
  const appAppleIdRaw = process.env.APP_APPLE_ID;
  const appAppleId = appAppleIdRaw ? Number(appAppleIdRaw) : undefined;
  if (isProd && (appAppleId === undefined || Number.isNaN(appAppleId))) {
    throw new Error("APP_APPLE_ID required when APP_STORE_ENV=PRODUCTION");
  }
  return new SignedDataVerifier(
    rootCerts,
    true,
    env,
    APPLE_BUNDLE_ID,
    appAppleId,
  );
}

function getVerifier(): Promise<SignedDataVerifier> {
  if (!verifierPromise) {
    verifierPromise = buildVerifier();
  }
  return verifierPromise;
}

/** Production-ready verifier wired into wallet callables. */
export async function verifyAppleReceipt(
  signedJWS: string,
  expectedProductId: string,
): Promise<boolean> {
  const inner = await getVerifier();
  return verifyWithVerifier(inner, signedJWS, expectedProductId);
}
