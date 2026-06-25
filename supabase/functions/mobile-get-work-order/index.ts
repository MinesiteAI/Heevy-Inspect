import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS_HEADERS,
  fetchOrgPack,
  json,
  packAllows,
  resolveWorkspace,
  serviceClient,
  str,
  verifyJwt,
} from "../_shared/inspect-auth.ts";

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = asRecord(await req.json());
    const id = str(body.id);
    if (!id) return json({ error: "id required" }, 400);

    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "Work orders not enabled" }, 403);
    }

    let query = admin
      .from("work_orders")
      .select("*")
      .eq("id", id);

    if (workspace.mineSiteId) {
      query = query.eq("mine_site_id", workspace.mineSiteId);
    } else {
      query = query.eq("created_by", auth.userId);
    }

    const { data, error } = await query.maybeSingle();
    if (error) return json({ error: error.message }, 500);
    if (!data) return json({ error: "Not found" }, 404);

    return json({ ok: true, work_order: data });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
