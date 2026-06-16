import Stripe from "stripe";

// Lazily constructed so the app builds/runs without Stripe keys until paid
// tier is actually enabled.
export function stripe(): Stripe | null {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) return null;
  return new Stripe(key);
}

export const PRO_PRICE_ID = process.env.STRIPE_PRO_PRICE_ID ?? "";
