import { NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { supaAdmin } from "@/lib/supabase";

async function setPlan(userId: string, plan: "free" | "pro") {
  await supaAdmin().from("profiles").update({ plan }).eq("id", userId);
}

// Stripe webhook -> flip profiles.plan on checkout / cancellation.
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
    const o = event.data.object as { metadata?: { userId?: string }; client_reference_id?: string };
    const uid = o.metadata?.userId ?? o.client_reference_id;
    if (uid) await setPlan(uid, "pro");
  } else if (event.type === "customer.subscription.deleted") {
    const o = event.data.object as { metadata?: { userId?: string } };
    if (o.metadata?.userId) await setPlan(o.metadata.userId, "free");
  }
  return NextResponse.json({ received: true });
}
