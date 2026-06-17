import { NextResponse } from "next/server";
import { bearer, userIdFromJWT, supaUser } from "@/lib/supabase";
import { keys, publicUrl } from "@/lib/r2";
import { siteOrigin } from "@/lib/site";

// List the signed-in user's clips ("my clips").
export async function GET(req: Request) {
  const jwt = bearer(req);
  const uid = await userIdFromJWT(jwt);
  if (!uid || !jwt) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  const { data, error } = await supaUser(jwt)
    .from("clips")
    .select("id,title,game,width,height,duration_sec,views,folder_id,created_at")
    .eq("owner", uid)
    .order("created_at", { ascending: false })
    .limit(500);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  const origin = siteOrigin(req);
  const clips = (data ?? []).map((c) => ({
    ...c,
    link: `${origin}/c/${c.id}`,
    videoUrl: publicUrl(keys.video(c.id)),
  }));
  return NextResponse.json({ clips });
}
