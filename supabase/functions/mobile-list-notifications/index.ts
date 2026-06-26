import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { CORS_HEADERS, json, verifyJwt } from "../_shared/inspect-auth.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

function toInt(raw: unknown, fallback: number) {
  const n = Number.parseInt((raw ?? "").toString(), 10);
  return Number.isFinite(n) ? n : fallback;
}

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

    const body = asRecord(await req.json().catch(() => ({})));
    const limit = Math.max(1, Math.min(100, toInt(body.limit, 50)));
    const offset = Math.max(0, toInt(body.offset, 0));
    const includeDismissed = body.include_dismissed === true;

    let q = userClient
      .from("mobile_notifications")
      .select(
        "id, type, title, body, payload_json, assignment_id, work_order_id, work_order_number, created_at, read_at, dismissed_at",
        { count: "exact" },
      )
      .eq("user_id", auth.userId)
      .order("created_at", { ascending: false })
      .range(offset, offset + limit - 1);

    if (!includeDismissed) q = q.is("dismissed_at", null);

    const { data, error, count } = await q;
    if (error) return json({ error: error.message }, 500);

    const { count: unreadCount } = await userClient
      .from("mobile_notifications")
      .select("id", { count: "exact", head: true })
      .eq("user_id", auth.userId)
      .is("read_at", null)
      .is("dismissed_at", null);

    return json({
      notifications: data ?? [],
      unread_count: unreadCount ?? 0,
      total_count: count ?? 0,
      next_offset: offset + (data?.length ?? 0),
      has_more: (offset + (data?.length ?? 0)) < (count ?? 0),
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
