import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { CORS_HEADERS, json, str, verifyJwt } from "../_shared/inspect-auth.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);
  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: `Bearer ${auth.jwt}` } },
    });

    const body = asRecord(await req.json());
    const id = str(body.notification_id);
    if (!id) return json({ error: "notification_id required" }, 400);
    const action = str(body.action || "mark_read");

    const patch: Record<string, unknown> = {};
    if (action === "mark_read") {
      patch.read_at = new Date().toISOString();
    } else if (action === "mark_unread") {
      patch.read_at = null;
    } else if (action === "dismiss") {
      patch.dismissed_at = new Date().toISOString();
      if (body.mark_read !== false) patch.read_at = new Date().toISOString();
    } else if (action === "restore") {
      patch.dismissed_at = null;
    } else {
      return json({ error: "Unsupported action" }, 400);
    }

    const { data, error } = await userClient
      .from("mobile_notifications")
      .update(patch)
      .eq("id", id)
      .eq("user_id", auth.userId)
      .select("id, read_at, dismissed_at")
      .maybeSingle();
    if (error) return json({ error: error.message }, 500);
    if (!data) return json({ error: "Notification not found" }, 404);
    return json({ ok: true, notification: data });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
