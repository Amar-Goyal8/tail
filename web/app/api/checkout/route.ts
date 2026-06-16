import { NextResponse } from "next/server";
import { stripe, PRO_PRICE_ID } from "@/lib/stripe";
import { accountFrom } from "@/lib/auth";

// Start a Stripe Checkout for Tail Pro. Account id rides in metadata so the
// webhook can flip the plan after payment.
export async function POST(req: Request) {
  const accountId = accountFrom(req);
  if (!accountId) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const s = stripe();
  if (!s || !PRO_PRICE_ID) {
    return NextResponse.json({ error: "billing not configured" }, { status: 503 });
  }

  const origin = new URL(req.url).origin;
  const session = await s.checkout.sessions.create({
    mode: "subscription",
    line_items: [{ price: PRO_PRICE_ID, quantity: 1 }],
    client_reference_id: accountId,
    metadata: { accountId },
    success_url: `${origin}/upgrade?status=success`,
    cancel_url: `${origin}/upgrade?status=cancel`,
  });
  return NextResponse.json({ url: session.url });
}
