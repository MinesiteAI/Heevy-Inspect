import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS_HEADERS,
  json,
  resolveWorkspace,
  serviceClient,
  verifyJwt,
} from "../_shared/inspect-auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);

    if (!workspace.organizationId) {
      return json({
        ok: true,
        field_capture_count: 0,
        work_request_count: 0,
        draft_work_request_count: 0,
      });
    }

    let capQuery = admin
      .from("field_captures")
      .select("id", { count: "exact", head: true })
      .eq("organization_id", workspace.organizationId);

    let wrCount = 0;
    let draftCount = 0;
    if (workspace.mineSiteId) {
      const [{ count: w }, { count: d }] = await Promise.all([
        admin
          .from("work_requests")
          .select("id", { count: "exact", head: true })
          .eq("mine_site_id", workspace.mineSiteId),
        admin
          .from("work_requests")
          .select("id", { count: "exact", head: true })
          .eq("mine_site_id", workspace.mineSiteId)
          .ilike("status", "draft"),
      ]);
      wrCount = w ?? 0;
      draftCount = d ?? 0;
    }

    const { count: capCount } = await capQuery;

    return json({
      ok: true,
      field_capture_count: capCount ?? 0,
      work_request_count: wrCount ?? 0,
      draft_work_request_count: draftCount,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
