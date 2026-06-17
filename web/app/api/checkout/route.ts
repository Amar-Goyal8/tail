import { NextResponse } from "next/server";
import { stripe, PRO_PRICE_ID } from "@/lib/stripe";
import { bearer, userIdFromJWT } from "@/lib/supabase";
import { siteOrigin } from "@/lib/site";

// Start a Stripe Checkout for Tail Pro. User id rides in metadata so the webhook
// can flip profiles.plan after payment.
export async function POST(req: Request) {
  const uid = await userIdFromJWT(bearer(req));
  if (!uid) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const s = stripe();
  if (!s || !PRO_PRICE_ID) return NextResponse.json({ error: "billing not configured" }, { status: 503 });

  const origin = siteOrigin(req);
  const session = await s.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price: PRO_PRICE_ID, quantity: 1 }],
    client_reference_id: uid,
    metadata: { userId: uid },
    success_url: `${origin}/upgrade?status=success`,
    cancel_url: `${origin}/upgrade?status=cancel`,
  });
  return NextResponse.json({ url: session.url });
}
