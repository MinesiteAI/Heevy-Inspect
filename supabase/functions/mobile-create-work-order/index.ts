import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS_HEADERS,
  fetchOrgPack,
  json,
  packAllows,
  resolveWorkspace,
  serviceClient,
  str,
  uploadPhotosFromPayloads,
  verifyJwt,
  writeAuditLog,
} from "../_shared/inspect-auth.ts";
import { notifyOrgManagers } from "../_shared/mobile-notify.ts";

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

function mapPriority(raw: string): string {
  const s = raw.toLowerCase();
  if (s.includes("p1") || s.includes("critical")) return "critical";
  if (s.includes("p2") || s.includes("high")) return "high";
  if (s.includes("p4") || s.includes("low")) return "low";
  return "medium";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = asRecord(await req.json());
    const wo = asRecord(body.work_order);
    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "Work orders not enabled" }, 403);
    }

    const title = str(wo.title) || str(body.title) || "Field work order";
    const description = str(wo.description) || str(body.description);
    const location = str(wo.location) || str(body.location);
    const assetId = str(wo.asset_id) || str(body.asset_id);
    const assetName = str(wo.asset_name) || str(body.asset_tag);
    const priority = mapPriority(str(wo.priority) || str(body.priority) || "medium");
    const sourceType = str(wo.source_type) || str(body.source_type) || "manual";
    const sourceId = str(wo.source_id) || str(body.source_id);

    let photoUrls: string[] = [];
    if (body.photo_payloads || body.photo_urls) {
      photoUrls = await uploadPhotosFromPayloads(admin, auth.userId, body, "work-orders");
    }

    const { data: created, error } = await admin
      .from("work_orders")
      .insert({
        title,
        description: description || null,
        source_type: sourceType,
        source_id: sourceId || null,
        asset_id: assetId || null,
        asset_name: assetName || null,
        location: location || null,
        functional_location: location || null,
        priority,
        status: "open",
        photo_urls: photoUrls,
        notes: str(wo.notes) || null,
        created_by: auth.userId,
        mine_site_id: workspace.mineSiteId,
      })
      .select("id, work_order_number, title, status, priority, created_at")
      .single();

    if (error) return json({ error: error.message }, 500);

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "create",
      entityType: "work_order",
      entityId: created?.id ?? "",
      newValue: created as Record<string, unknown>,
      metadata: { source: "heevy_inspect" },
    });

    const woNum = str(created?.work_order_number);
    const submitter = workspace.fullName ?? auth.email ?? "A crew member";
    await notifyOrgManagers(admin, workspace.organizationId, {
      excludeUserId: auth.userId,
      type: "work_order_created",
      title: "New work order",
      body: `${submitter} created ${woNum}: ${title}`,
      payloadJson: {
        work_order_id: created?.id ?? null,
        work_order_number: woNum,
      },
      workOrderId: str(created?.id) || null,
      workOrderNumber: woNum || null,
      dedupeKey: `wo_create_${str(created?.id)}`,
    });

    return json({ ok: true, work_order: created });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
