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
    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "PM inspections not enabled" }, 403);
    }

    const pmForm = asRecord(body.pm_form);
    const pmFormTemplateId = str(pmForm.template_id);
    const pmFormValues = pmForm.form_values;

    if (!pmFormTemplateId || !pmFormValues || typeof pmFormValues !== "object") {
      return json({ error: "pm_form.template_id and pm_form.form_values required" }, 400);
    }

    const insertPm = {
      template_id: pmFormTemplateId,
      scheduled_instance_id: str(pmForm.scheduled_instance_id) || null,
      submitter_name: str(pmForm.submitter_name) || workspace.fullName,
      submitter_email: str(pmForm.submitter_email) || auth.email,
      form_values: pmFormValues,
      notes: str(pmForm.notes) || null,
      status: "submitted",
      submitted_at: new Date().toISOString(),
      week_start: pmForm.week_start ?? null,
      created_by: auth.userId,
      mine_site_id: workspace.mineSiteId,
    };

    const { data: pmData, error: pmErr } = await admin
      .from("pm_form_submissions")
      .insert(insertPm)
      .select("id, submitted_at")
      .single();

    if (pmErr) return json({ error: pmErr.message }, 500);

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "submit",
      entityType: "pm_form_submission",
      entityId: pmData?.id ?? "",
      newValue: { template_id: pmFormTemplateId },
    });

    const submitter = str(pmForm.submitter_name) || workspace.fullName || auth.email || "Inspector";
    await notifyOrgManagers(admin, workspace.organizationId, {
      excludeUserId: auth.userId,
      type: "pm_inspection_submitted",
      title: "PM inspection submitted",
      body: `${submitter} submitted ${pmFormTemplateId}`,
      payloadJson: {
        pm_submission_id: pmData?.id ?? null,
        template_id: pmFormTemplateId,
      },
      dedupeKey: `pm_submit_${str(pmData?.id)}`,
    });

    return json({
      ok: true,
      pm_submission_id: pmData?.id ?? null,
      submitted_at: pmData?.submitted_at ?? null,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
