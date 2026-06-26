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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = await req.json() as Record<string, unknown>;
    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);

    const pack = await fetchOrgPack(admin, workspace.organizationId);
    if (!packAllows(pack, "field_capture")) {
      return json({ error: "Field capture not enabled for your organization" }, 403);
    }

    const plantArea = str(body.plant_area);
    const assetId = str(body.asset_id);
    const assetTag = str(body.asset_tag);
    const severity = str(body.severity) || "Medium";
    const notes = str(body.notes);
    const voiceTranscript = str(body.voice_transcript);
    const createWorkOrder = body.create_work_order === true;

    let photoUrls: string[];
    try {
      photoUrls = await uploadPhotosFromPayloads(
        admin,
        auth.userId,
        body,
        "field-capture",
      );
    } catch (uploadErr) {
      const msg = uploadErr instanceof Error ? uploadErr.message : "Photo upload failed";
      return json({ error: msg }, 500);
    }

    const mineSiteId = str(body.mine_site_id) || workspace.mineSiteId;
    const organizationId = workspace.organizationId;
    const workTitle = notes.length > 80 ? `${notes.slice(0, 77)}...` : (notes || "Field capture");
    const problemDescription = [notes, voiceTranscript].filter(Boolean).join("\n\n");

    const { data: wrNumber } = await admin.rpc("next_wr_number");
    let wrNum = typeof wrNumber === "string" ? wrNumber : `WR-${Date.now()}`;

    const { data: wrRow, error: wrErr } = await admin
      .from("work_requests")
      .insert({
        wr_number: wrNum,
        status: "draft",
        priority: severity,
        work_type: "Inspect",
        asset_id: assetId || assetTag,
        functional_location: plantArea,
        work_title: workTitle,
        problem_description: problemDescription,
        requested_by: workspace.fullName ?? auth.email ?? "",
        photo_urls: photoUrls,
        created_by: auth.userId,
        mine_site_id: mineSiteId,
      })
      .select("id, wr_number")
      .single();

    if (wrErr) return json({ error: wrErr.message }, 500);

    const nextWrStatus = packAllows(pack, "plant") ? "Pending Approval" : "Open";
    const { data: submittedWr, error: submitErr } = await admin
      .from("work_requests")
      .update({
        status: nextWrStatus,
        updated_at: new Date().toISOString(),
      })
      .eq("id", wrRow.id)
      .select("id, wr_number, status")
      .single();

    if (submitErr) return json({ error: submitErr.message }, 500);

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "submit",
      entityType: "work_request",
      entityId: wrRow.id,
      newValue: submittedWr as Record<string, unknown>,
      metadata: {
        source: "heevy_inspect_quick_capture",
        next_status: nextWrStatus,
      },
    });

    wrNum = str(submittedWr?.wr_number) || wrNum;
    const submitter = workspace.fullName ?? auth.email ?? "A crew member";
    const notifiedCount = await notifyOrgManagers(admin, workspace.organizationId, {
      excludeUserId: auth.userId,
      type: "work_request_submitted",
      title: "New work request submitted",
      body: `${submitter} submitted ${wrNum}: ${workTitle}`,
      payloadJson: {
        work_request_id: wrRow.id,
        wr_number: wrNum,
        status: nextWrStatus,
      },
      dedupeKey: `wr_submit_${wrRow.id}`,
    });

    const submitMessage = nextWrStatus === "Open"
      ? notifiedCount > 0
        ? `${wrNum} submitted to your site queue. Supervisor notified.`
        : `${wrNum} submitted to your site queue.`
      : notifiedCount > 0
      ? `${wrNum} submitted for approval. Supervisor notified.`
      : `${wrNum} submitted for approval on web.`;

    const { data: captureRow, error: capErr } = await admin
      .from("field_captures")
      .insert({
        organization_id: organizationId,
        mine_site_id: mineSiteId,
        created_by: auth.userId,
        plant_area: plantArea,
        asset_id: assetId,
        asset_tag: assetTag,
        severity,
        notes,
        voice_transcript: voiceTranscript,
        photo_urls: photoUrls,
        work_request_id: wrRow?.id ?? null,
        status: "submitted",
        capture_source: "heevy_inspect",
      })
      .select("id, created_at")
      .single();

    if (capErr) return json({ error: capErr.message }, 500);

    let workOrderId: string | null = null;
    let workOrderNumber: string | null = null;

    if (createWorkOrder && packAllows(pack, "field_capture")) {
      const priority = severity.toLowerCase().includes("p1") || severity.toLowerCase().includes("critical")
        ? "critical"
        : severity.toLowerCase().includes("p2") || severity.toLowerCase().includes("high")
        ? "high"
        : severity.toLowerCase().includes("p4") || severity.toLowerCase().includes("low")
        ? "low"
        : "medium";

      const { data: woRow, error: woErr } = await admin
        .from("work_orders")
        .insert({
          title: workTitle,
          description: problemDescription,
          source_type: "field_capture",
          source_id: captureRow?.id ?? null,
          asset_id: assetId || assetTag || null,
          asset_name: assetTag || null,
          location: plantArea,
          priority,
          status: "open",
          photo_urls: photoUrls,
          notes,
          created_by: auth.userId,
          mine_site_id: mineSiteId,
          functional_location: plantArea,
        })
        .select("id, work_order_number")
        .single();

      if (woErr) return json({ error: woErr.message }, 500);
      workOrderId = woRow?.id ?? null;
      workOrderNumber = woRow?.work_order_number ?? null;

      await writeAuditLog(admin, {
        userId: auth.userId,
        actionType: "create",
        entityType: "work_order",
        entityId: workOrderId ?? "",
        newValue: woRow as Record<string, unknown>,
        metadata: { source: "field_capture", capture_id: captureRow?.id },
      });
    }

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "create",
      entityType: "field_capture",
      entityId: captureRow?.id ?? "",
      newValue: { capture_id: captureRow?.id, wr_number: wrNum },
    });

    return json({
      ok: true,
      capture_id: captureRow?.id ?? null,
      work_request_id: wrRow?.id ?? null,
      wr_number: wrNum,
      wr_status: nextWrStatus,
      submitted: true,
      message: submitMessage,
      work_order_id: workOrderId,
      work_order_number: workOrderNumber,
      created_at: captureRow?.created_at ?? null,
    });
  } catch (e) {
    console.error("mobile-submit-field-capture:", e);
    const msg = e instanceof Error ? e.message : "Internal server error";
    return json({ error: msg }, 500);
  }
});
