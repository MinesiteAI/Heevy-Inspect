import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS_HEADERS,
  fetchOrgPack,
  json,
  packAllows,
  resolveWorkspace,
  serviceClient,
  verifyJwt,
} from "../_shared/inspect-auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST" && req.method !== "GET") {
    return json({ error: "Use GET or POST" }, 405);
  }

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "Work orders not enabled" }, 403);
    }

    let query = admin
      .from("work_orders")
      .select(
        "id, work_order_number, title, description, status, priority, location, asset_name, source_type, source_id, photo_urls, created_at, updated_at",
      )
      .order("created_at", { ascending: false })
      .limit(100);

    if (workspace.mineSiteId) {
      query = query.eq("mine_site_id", workspace.mineSiteId);
    } else {
      query = query.eq("created_by", auth.userId);
    }

    const { data, error } = await query;
    if (error) return json({ error: error.message }, 500);

    return json({ ok: true, items: data ?? [] });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
