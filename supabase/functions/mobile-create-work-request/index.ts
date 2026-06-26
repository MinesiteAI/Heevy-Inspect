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

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

function mapPriorityLabel(raw: string): string {
  const s = raw.toLowerCase();
  if (s.includes("p1") || s.includes("critical")) return "P1 – Critical";
  if (s.includes("p2") || s.includes("high")) return "P2 – High";
  if (s.includes("p4") || s.includes("low")) return "P4 – Low";
  if (s.includes("p3") || s.includes("medium")) return "P3 – Medium";
  return raw.trim() || "P3 – Medium";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = asRecord(await req.json());
    const wr = asRecord(body.work_request);
    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "Work requests not enabled" }, 403);
    }

    if (!workspace.mineSiteId) {
      return json({ error: "Site not provisioned yet" }, 400);
    }

    const workTitle = str(wr.work_title) || str(wr.title) || str(body.work_title) || "";
    if (!workTitle) {
      return json({ error: "work_title is required" }, 400);
    }

    const problemDescription = str(wr.problem_description) ||
      str(wr.description) ||
      str(body.problem_description) ||
      str(body.description);
    const plantArea = str(wr.functional_location) ||
      str(wr.plant_area) ||
      str(body.functional_location) ||
      str(body.plant_area);
    const assetId = str(wr.asset_id) || str(body.asset_id);
    const assetTag = str(wr.asset_tag) || str(body.asset_tag);
    const priority = mapPriorityLabel(
      str(wr.priority) || str(body.priority) || "P3 – Medium",
    );

    let photoUrls: string[] = [];
    if (body.photo_payloads || body.photo_urls) {
      photoUrls = await uploadPhotosFromPayloads(admin, auth.userId, body, "work-requests");
    }

    const { data: wrNumber } = await admin.rpc("next_wr_number");
    const wrNum = typeof wrNumber === "string" ? wrNumber : `WR-${Date.now()}`;

    const { data: created, error } = await admin
      .from("work_requests")
      .insert({
        wr_number: wrNum,
        status: "draft",
        priority,
        work_type: "Inspect",
        asset_id: assetId || assetTag || null,
        functional_location: plantArea || null,
        work_title: workTitle,
        problem_description: problemDescription || null,
        requested_by: workspace.fullName ?? auth.email ?? "",
        photo_urls: photoUrls,
        created_by: auth.userId,
        mine_site_id: workspace.mineSiteId,
      })
      .select(
        "id, wr_number, work_title, problem_description, status, priority, functional_location, created_at",
      )
      .single();

    if (error) return json({ error: error.message }, 500);

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "create",
      entityType: "work_request",
      entityId: created?.id ?? "",
      newValue: created as Record<string, unknown>,
      metadata: { source: "heevy_inspect_mobile" },
    });

    return json({ ok: true, work_request: created });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
