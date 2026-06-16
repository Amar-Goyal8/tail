import { NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { setPlan } from "@/lib/r2";

// Stripe webhook: on successful checkout / active subscription, mark the
// account Pro; on cancellation, drop to free. Needs STRIPE_WEBHOOK_SECRET.
export async function POST(req: Request) {
  const s = stripe();
  const whSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!s || !whSecret) return NextResponse.json({ error: "not configured" }, { status: 503 });

  const sig = req.headers.get("stripe-signature") ?? "";
  const raw = await req.text();
  let event;
  try {
    event = s.webhooks.constructEvent(raw, sig, whSecret);
  } catch (e) {
    return NextResponse.json({ error: `bad signature: ${(e as Error).message}` }, { status: 400 });
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object as { metadata?: { accountId?: string }; client_reference_id?: string };
    const accountId = session.metadata?.accountId ?? session.client_reference_id;
    if (accountId) await setPlan(accountId, "pro");
  } else if (event.type === "customer.subscription.deleted") {
    const sub = event.data.object as { metadata?: { accountId?: string } };
    const accountId = sub.metadata?.accountId;
    if (accountId) await setPlan(accountId, "free");
  }
  return NextResponse.json({ received: true });
}
