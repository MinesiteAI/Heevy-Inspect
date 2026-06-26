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
      return json({ error: "Work requests not enabled" }, 403);
    }

    let query = admin
      .from("work_requests")
      .select("*")
      .eq("id", id)
      .eq("created_by", auth.userId);

    if (workspace.mineSiteId) {
      query = query.eq("mine_site_id", workspace.mineSiteId);
    }

    const { data: wr, error } = await query.maybeSingle();
    if (error) return json({ error: error.message }, 500);
    if (!wr) return json({ error: "Not found" }, 404);

    const { data: capture } = await admin
      .from("field_captures")
      .select("id, plant_area, severity, notes, photo_urls, created_at")
      .eq("work_request_id", id)
      .maybeSingle();

    let linkedWo: Record<string, unknown> | null = null;
    const woId = wr.linked_wo_id as string | null;
    if (woId) {
      const { data: wo } = await admin
        .from("work_orders")
        .select("id, work_order_number, title, status, priority")
        .eq("id", woId)
        .maybeSingle();
      linkedWo = wo as Record<string, unknown> | null;
    }

    return json({
      ok: true,
      work_request: wr,
      field_capture: capture,
      linked_work_order: linkedWo,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
