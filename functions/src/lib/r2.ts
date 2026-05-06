/**
 * Cloudflare R2 (S3-compatible) signed URL generation.
 *
 * Endpoint: https://<accountId>.r2.cloudflarestorage.com
 * We use @aws-sdk/client-s3 + @aws-sdk/s3-request-presigner.
 *
 * Required env (set via `firebase functions:secrets:set` for production):
 *   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY,
 *   R2_BUCKET_FILTERS, R2_PUBLIC_HOST
 */
import type { Readable } from "node:stream";

export interface PresignedRequest {
  url: string;
  method: "PUT" | "GET";
  headers: Record<string, string>;
  expiresAt: number; // unix seconds
}

export interface R2Config {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
}

/**
 * Build a presigned PUT URL for the given (bucket, key). Client uploads
 * directly to R2; server only sees the manifest write afterwards.
 */
export async function presignPut(
  _cfg: R2Config,
  _bucket: string,
  _key: string,
  _expiresSeconds = 600,
): Promise<PresignedRequest> {
  // TODO:
  // 1. Construct S3Client with endpoint = `https://${cfg.accountId}.r2.cloudflarestorage.com`,
  //    region: "auto", forcePathStyle: false.
  // 2. getSignedUrl(client, new PutObjectCommand({ Bucket, Key }), { expiresIn }).
  // 3. Return shaped object.
  throw new Error("presignPut not implemented");
}

/** Build a presigned GET URL for the given (bucket, key). */
export async function presignGet(
  _cfg: R2Config,
  _bucket: string,
  _key: string,
  _expiresSeconds = 600,
): Promise<PresignedRequest> {
  throw new Error("presignGet not implemented");
}

/** Helper: stream a readable into R2 directly (used by triggers if needed). */
export async function _streamToR2(_body: Readable): Promise<void> {
  // Reserved for server-side ingest paths (thumbnail post-processing, etc.).
}
