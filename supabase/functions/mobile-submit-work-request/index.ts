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
import { notifyOrgManagers } from "../_shared/mobile-notify.ts";

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

    const { data: wr, error: fetchErr } = await query.maybeSingle();
    if (fetchErr) return json({ error: fetchErr.message }, 500);
    if (!wr) return json({ error: "Work request not found" }, 404);

    const status = str(wr.status).toLowerCase();
    if (status !== "draft") {
      return json({ error: "Only draft work requests can be submitted" }, 400);
    }

    const nextStatus = packAllows(pack, "plant") ? "Pending Approval" : "Open";

    const { data: updated, error: updErr } = await admin
      .from("work_requests")
      .update({
        status: nextStatus,
        updated_at: new Date().toISOString(),
      })
      .eq("id", id)
      .select(
        "id, wr_number, work_title, status, priority, functional_location, created_at",
      )
      .single();

    if (updErr) return json({ error: updErr.message }, 500);

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "submit",
      entityType: "work_request",
      entityId: id,
      newValue: updated as Record<string, unknown>,
      metadata: { source: "heevy_inspect_mobile", next_status: nextStatus },
    });

    const wrNum = str(updated?.wr_number);
    const title = str(updated?.work_title) || "Work request";
    const submitter = workspace.fullName ?? auth.email ?? "A crew member";

    const notifiedCount = await notifyOrgManagers(admin, workspace.organizationId, {
      excludeUserId: auth.userId,
      type: "work_request_submitted",
      title: "New work request submitted",
      body: `${submitter} submitted ${wrNum}: ${title}`,
      payloadJson: {
        work_request_id: id,
        wr_number: wrNum,
        status: nextStatus,
      },
      dedupeKey: `wr_submit_${id}`,
    });

    const managerNames: string[] = [];
    if (workspace.organizationId) {
      const { data: managers } = await admin
        .from("profiles")
        .select("full_name, email")
        .eq("organization_id", workspace.organizationId)
        .eq("is_org_manager", true)
        .neq("id", auth.userId);
      for (const mgr of managers ?? []) {
        const label = str(mgr.full_name) || str(mgr.email);
        if (label) managerNames.push(label);
      }
    }

    const notifyDetail = managerNames.length > 0
      ? `Notified: ${managerNames.slice(0, 3).join(", ")}${managerNames.length > 3 ? ` +${managerNames.length - 3} more` : ""}.`
      : notifiedCount > 0
      ? "Your supervisor has been notified."
      : "Submitted to your site queue.";

    return json({
      ok: true,
      work_request: updated,
      web_queue: true,
      managers_notified: notifiedCount,
      manager_names: managerNames,
      message: nextStatus === "Open"
        ? `Submitted to your site queue. ${notifyDetail}`
        : `Submitted for approval. ${notifyDetail}`,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
