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

import { isWorkOrderAccessible } from "../_shared/mobile-work-order-scope.ts";

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

async function loadSupervisorAck(
  admin: ReturnType<typeof serviceClient>,
  workRequestId: string,
): Promise<Record<string, unknown> | null> {
  const { data: ackLog } = await admin
    .from("audit_logs")
    .select("created_at, user_id, metadata")
    .eq("entity_type", "work_request")
    .eq("entity_id", workRequestId)
    .eq("action_type", "supervisor_acknowledge")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!ackLog) return null;

  let ackName = str((ackLog.metadata as Record<string, unknown> | null)?.acknowledged_by_name);
  if (!ackName && ackLog.user_id) {
    const { data: ackProfile } = await admin
      .from("profiles")
      .select("full_name, email")
      .eq("id", ackLog.user_id)
      .maybeSingle();
    ackName = str(ackProfile?.full_name) || str(ackProfile?.email) || "Supervisor";
  }

  return {
    acknowledged_at: ackLog.created_at,
    acknowledged_by: ackLog.user_id,
    acknowledged_by_name: ackName,
  };
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

    let query = admin.from("work_requests").select("*").eq("id", id);
    if (workspace.mineSiteId) {
      query = query.eq("mine_site_id", workspace.mineSiteId);
    }

    const { data: wr, error } = await query.maybeSingle();
    if (error) return json({ error: error.message }, 500);
    if (!wr) return json({ error: "Not found" }, 404);

    const createdBy = str(wr.created_by);
    if (createdBy !== auth.userId && !workspace.isOrgManager) {
      return json({ error: "Forbidden" }, 403);
    }

    const { data: capture } = await admin
      .from("field_captures")
      .select("id, plant_area, severity, notes, photo_urls, created_at, created_by")
      .eq("work_request_id", id)
      .maybeSingle();

    let linkedWo: Record<string, unknown> | null = null;
    let linkedWoAccessible = false;
    const woId = wr.linked_wo_id as string | null;
    const woSelect =
      "id, work_order_number, title, status, priority";

    if (woId) {
      const { data: wo } = await admin
        .from("work_orders")
        .select(woSelect)
        .eq("id", woId)
        .maybeSingle();
      linkedWo = wo as Record<string, unknown> | null;
    } else {
      const { data: sourceWo } = await admin
        .from("work_orders")
        .select(woSelect)
        .eq("source_type", "work_request")
        .eq("source_id", id)
        .order("created_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      linkedWo = sourceWo as Record<string, unknown> | null;
    }

    if (linkedWo) {
      const resolvedWoId = str(linkedWo.id);
      if (resolvedWoId) {
        linkedWoAccessible = await isWorkOrderAccessible(
          admin,
          resolvedWoId,
          workspace,
          auth.userId,
        );
      }
    }

    let createdByName: string | null = null;
    if (createdBy) {
      const { data: profile } = await admin
        .from("profiles")
        .select("full_name, email")
        .eq("id", createdBy)
        .maybeSingle();
      createdByName = str(profile?.full_name) || str(profile?.email) || null;
    }

    const supervisorAck = await loadSupervisorAck(admin, id);

    return json({
      ok: true,
      work_request: { ...wr, created_by_name: createdByName },
      field_capture: capture,
      linked_work_order: linkedWo,
      linked_work_order_accessible: linkedWoAccessible,
      read_only: workspace.isOrgManager && createdBy !== auth.userId,
      supervisor_ack: supervisorAck,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
