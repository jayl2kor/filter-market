export const VALID_PRICE_TIERS = [0, 30, 50, 80, 120] as const;

export type FilterPriceTier = (typeof VALID_PRICE_TIERS)[number];

export function isValidPriceTier(price: unknown): price is FilterPriceTier {
  return typeof price === "number" &&
    Number.isInteger(price) &&
    (VALID_PRICE_TIERS as readonly number[]).includes(price);
}
