/**
 * Firestore /filters/{id} document shape. Mirrors docs/FMPKG_SCHEMA.md +
 * docs/API_SPEC.md §3 + docs/CURRENCY_DESIGN.md §2.2.
 */
export type FilterStatus =
  | "draft"
  | "uploading"
  | "pending_review"
  | "published"
  | "rejected"
  | "taken_down";

export type FilterCategory =
  | "cinematic"
  | "vintage"
  | "pastel"
  | "monochrome"
  | "portrait"
  | "food"
  | "travel"
  | "mood";

/** Coin price tier per CURRENCY_DESIGN.md §2.2. 0 = free. */
export type FilterPriceTier = 0 | 30 | 50 | 80 | 120;

export interface FilterDoc {
  ownerUid: string;
  name: string;
  slug: string;
  description: string;
  category: FilterCategory;
  tags: string[];
  status: FilterStatus;
  visibility: "public" | "unlisted";
  /** Coin price. 0 = free. Allowed values: 0, 30, 50, 80, 120 (CURRENCY_DESIGN §2.2). */
  priceCoins: FilterPriceTier;
  thumbnailUrl: string;
  packageUrl: string; // .fmpkg signed URL base
  packageBytes: number;
  packageSha256: string;
  useCount: number;
  likeCount: number;
  /** Cumulative coins earned by the maker (60% of all purchases). */
  earnedCoinsTotal: number;
  createdAt: FirebaseFirestore.Timestamp;
  updatedAt: FirebaseFirestore.Timestamp;
  publishedAt?: FirebaseFirestore.Timestamp;
}
