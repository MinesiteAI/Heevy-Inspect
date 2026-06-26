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
  writeAuditLog,
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
    if (!workspace.isOrgManager) {
      return json({ error: "Supervisor role required" }, 403);
    }

    let query = admin.from("work_requests").select("*").eq("id", id);
    if (workspace.mineSiteId) {
      query = query.eq("mine_site_id", workspace.mineSiteId);
    }

    const { data: wr, error } = await query.maybeSingle();
    if (error) return json({ error: error.message }, 500);
    if (!wr) return json({ error: "Not found" }, 404);

    const createdBy = str(wr.created_by);
    if (createdBy === auth.userId) {
      return json({ error: "Cannot acknowledge your own request" }, 400);
    }

    const status = str(wr.status).toLowerCase();
    if (status === "draft") {
      return json({ error: "Cannot acknowledge a draft — crew must submit first" }, 400);
    }

    const ackName = workspace.fullName ?? auth.email ?? "Supervisor";
    const ackAt = new Date().toISOString();

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "supervisor_acknowledge",
      entityType: "work_request",
      entityId: id,
      metadata: {
        acknowledged_by_name: ackName,
        source: "heevy_inspect_mobile",
      },
    });

    return json({
      ok: true,
      supervisor_ack: {
        acknowledged_at: ackAt,
        acknowledged_by: auth.userId,
        acknowledged_by_name: ackName,
      },
      message: "Acknowledged — crew can see you have seen this request.",
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
