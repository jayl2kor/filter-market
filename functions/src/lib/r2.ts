/**
 * Cloudflare R2 (S3-compatible) signed URL generation.
 *
 * Endpoint: https://<accountId>.r2.cloudflarestorage.com
 * Uses @aws-sdk/client-s3 + @aws-sdk/s3-request-presigner.
 *
 * Required Firebase secrets (`firebase functions:secrets:set`):
 *   R2_ENDPOINT          full URL like https://<account>.r2.cloudflarestorage.com
 *   R2_ACCESS_KEY_ID
 *   R2_SECRET_ACCESS_KEY
 *   R2_BUCKET            bucket name (e.g., moodit-filters)
 */
import { S3Client, PutObjectCommand, GetObjectCommand, HeadObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

export interface PresignedRequest {
  url: string;
  method: "PUT" | "GET";
  headers: Record<string, string>;
  expiresAt: number; // unix seconds
}

export interface R2Config {
  endpoint: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
}

/**
 * Reads R2 config from process.env. Throws if any required secret is missing —
 * caller should map to an HttpsError("internal").
 */
export function loadR2Config(): R2Config {
  const endpoint = process.env.R2_ENDPOINT;
  const accessKeyId = process.env.R2_ACCESS_KEY_ID;
  const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
  const bucket = process.env.R2_BUCKET;
  if (!endpoint || !accessKeyId || !secretAccessKey || !bucket) {
    throw new Error(
      "R2 secrets not configured (R2_ENDPOINT / R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY / R2_BUCKET)",
    );
  }
  return { endpoint, accessKeyId, secretAccessKey, bucket };
}

function buildClient(cfg: R2Config): S3Client {
  return new S3Client({
    region: "auto",
    endpoint: cfg.endpoint,
    credentials: {
      accessKeyId: cfg.accessKeyId,
      secretAccessKey: cfg.secretAccessKey,
    },
    forcePathStyle: false,
  });
}

/**
 * Build a presigned PUT URL for the given (bucket, key). Client uploads
 * directly to R2; server only sees the manifest write afterwards.
 *
 * `contentSha256` is optional — if supplied, it's bound into the signature so
 * a tampered upload is rejected by R2 itself.
 */
export async function presignPut(
  cfg: R2Config,
  key: string,
  options: { expiresSeconds?: number; contentType?: string; contentSha256?: string } = {},
): Promise<PresignedRequest> {
  const expiresIn = options.expiresSeconds ?? 600;
  const client = buildClient(cfg);
  const command = new PutObjectCommand({
    Bucket: cfg.bucket,
    Key: key,
    ContentType: options.contentType,
    ChecksumSHA256: options.contentSha256,
  });
  const url = await getSignedUrl(client, command, { expiresIn });
  const headers: Record<string, string> = {};
  if (options.contentType) headers["Content-Type"] = options.contentType;
  if (options.contentSha256) headers["x-amz-checksum-sha256"] = options.contentSha256;
  return {
    url,
    method: "PUT",
    headers,
    expiresAt: Math.floor(Date.now() / 1000) + expiresIn,
  };
}

/** Build a presigned GET URL for download. */
export async function presignGet(
  cfg: R2Config,
  key: string,
  expiresSeconds = 600,
): Promise<PresignedRequest> {
  const client = buildClient(cfg);
  const command = new GetObjectCommand({ Bucket: cfg.bucket, Key: key });
  const url = await getSignedUrl(client, command, { expiresIn: expiresSeconds });
  return {
    url,
    method: "GET",
    headers: {},
    expiresAt: Math.floor(Date.now() / 1000) + expiresSeconds,
  };
}

/** Verify the object exists and has the declared sha256 checksum. */
export async function headWithChecksum(
  cfg: R2Config,
  key: string,
): Promise<{ contentLength?: number; sha256?: string }> {
  const client = buildClient(cfg);
  const result = await client.send(
    new HeadObjectCommand({
      Bucket: cfg.bucket,
      Key: key,
      ChecksumMode: "ENABLED",
    }),
  );
  return {
    contentLength: result.ContentLength,
    sha256: result.ChecksumSHA256,
  };
}
