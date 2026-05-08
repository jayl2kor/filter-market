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
import { readFileSync } from "fs";
import { resolve } from "path";
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

const ROOT_CERT_FILES = [
  "AppleRootCA-G2.cer",
  "AppleRootCA-G3.cer",
  "AppleIncRootCertificate.cer",
];

const CERT_FETCH_TIMEOUT_MS = 10_000;

function certDirectory(): string {
  return resolve(__dirname, "../../certs");
}

export function loadBundledRootCerts(): Buffer[] {
  const dir = certDirectory();
  return ROOT_CERT_FILES.map((name) => readFileSync(resolve(dir, name)));
}

async function fetchCert(url: string): Promise<Buffer> {
  return new Promise<Buffer>((resolve, reject) => {
    const req = https.get(url, { timeout: CERT_FETCH_TIMEOUT_MS }, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`fetch_cert_failed: ${url} status=${res.statusCode}`));
        return;
      }
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    });
    req.on("timeout", () => {
      req.destroy(new Error(`fetch_cert_timeout: ${url}`));
    });
    req.on("error", reject);
  });
}

async function loadRootCerts(): Promise<Buffer[]> {
  try {
    return loadBundledRootCerts();
  } catch {
    return Promise.all(ROOT_CERT_URLS.map(fetchCert));
  }
}

/** Minimal contract we depend on — keeps tests free of the heavy Apple SDK. */
export interface AppleVerifierLike {
  verifyAndDecodeTransaction(signedJWS: string): Promise<{
    productId?: string;
    revocationDate?: number;
    expiresDate?: number;
  }>;
}

export interface AppleTransactionInfo {
  productId?: string;
  revocationDate?: number;
  expiresDate?: number;
}

export async function decodeWithVerifier(
  inner: AppleVerifierLike,
  signedJWS: string,
): Promise<AppleTransactionInfo> {
  return inner.verifyAndDecodeTransaction(signedJWS);
}

/** Pure verification logic — testable with a fake AppleVerifierLike. */
export async function verifyWithVerifier(
  inner: AppleVerifierLike,
  signedJWS: string,
  expectedProductId: string,
): Promise<boolean> {
  try {
    const tx = await decodeWithVerifier(inner, signedJWS);
    if (tx.productId !== expectedProductId) return false;
    if (tx.revocationDate !== undefined) return false;
    return true;
  } catch {
    return false;
  }
}

let verifierPromise: Promise<SignedDataVerifier> | null = null;

async function buildVerifier(): Promise<SignedDataVerifier> {
  const rootCerts = await loadRootCerts();
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
    verifierPromise = buildVerifier().catch((error) => {
      verifierPromise = null;
      throw error;
    });
  }
  return verifierPromise;
}

export function resetAppleVerifierForTests(): void {
  verifierPromise = null;
}

/** Production-ready verifier wired into wallet callables. */
export async function verifyAppleReceipt(
  signedJWS: string,
  expectedProductId: string,
): Promise<boolean> {
  const inner = await getVerifier();
  return verifyWithVerifier(inner, signedJWS, expectedProductId);
}

export async function verifyAppleTransaction(
  signedJWS: string,
  expectedProductId: string,
): Promise<AppleTransactionInfo | false> {
  const inner = await getVerifier();
  try {
    const tx = await decodeWithVerifier(inner, signedJWS);
    if (tx.productId !== expectedProductId) return false;
    return tx;
  } catch {
    return false;
  }
}
