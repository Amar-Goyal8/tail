import { NextResponse } from "next/server";
import { bearer, userIdFromJWT, supaUser } from "@/lib/supabase";

// List the user's folders.
export async function GET(req: Request) {
  const jwt = bearer(req);
  const uid = await userIdFromJWT(jwt);
  if (!uid || !jwt) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { data, error } = await supaUser(jwt)
    .from("folders").select("id,name,created_at").eq("owner", uid).order("name");
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ folders: data ?? [] });
}

// Create a folder.
export async function POST(req: Request) {
  const jwt = bearer(req);
  const uid = await userIdFromJWT(jwt);
  if (!uid || !jwt) return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  const { name } = await req.json().catch(() => ({}));
  if (!name?.trim()) return NextResponse.json({ error: "missing name" }, { status: 400 });
  const { data, error } = await supaUser(jwt)
    .from("folders").insert({ owner: uid, name: name.trim() }).select("id,name").single();
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });
  return NextResponse.json({ folder: data });
}
