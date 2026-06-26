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

const PM_TEMPLATE_LIMIT = 3;

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

function buildFormStructure(taskLines: string[]): Record<string, unknown> {
  const fields = taskLines
    .map((label, i) => ({
      id: `pm_task_1_${i + 1}`,
      type: "checkbox",
      label: label.trim(),
    }))
    .filter((f) => f.label.length > 0);
  return {
    sections: [{ id: "sec_1", title: "INSPECTIONS", fields }],
  };
}

async function countByDiscipline(
  admin: ReturnType<typeof serviceClient>,
  organizationId: string,
): Promise<Record<string, number>> {
  const { data: sites } = await admin
    .from("mine_sites")
    .select("id")
    .eq("organization_id", organizationId)
    .eq("is_active", true);
  const siteIds = (sites ?? []).map((s) => s.id as string).filter(Boolean);
  if (!siteIds.length) return {};

  const { data: rows } = await admin
    .from("pm_master_list")
    .select("discipline")
    .eq("plan_type", "pm")
    .neq("status", "Archived")
    .in("mine_site_id", siteIds);

  const usage: Record<string, number> = {};
  for (const row of rows ?? []) {
    const d = ((row.discipline as string) ?? "Unassigned").trim() || "Unassigned";
    usage[d] = (usage[d] ?? 0) + 1;
  }
  return usage;
}

async function isFieldCaptureOnly(
  admin: ReturnType<typeof serviceClient>,
  organizationId: string | null,
): Promise<boolean> {
  if (!organizationId) return false;
  const { data: org } = await admin
    .from("organizations")
    .select("modules_of_interest")
    .eq("id", organizationId)
    .maybeSingle();
  const { data } = await admin.rpc("org_is_field_capture_only", {
    _modules: org?.modules_of_interest ?? [],
  });
  return data === true;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = asRecord(await req.json());
    const tpl = asRecord(body.template);
    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "PM templates not enabled" }, 403);
    }

    const pmName = str(tpl.pm_name) || str(body.pm_name) || "Field inspection";
    const discipline = str(tpl.discipline) || str(body.discipline) || "Mechanical";
    const plantArea = str(tpl.plant_area) || str(body.plant_area) || "";
    const frequency = str(tpl.frequency) || str(body.frequency) || "Monthly";
    const taskLines = Array.isArray(body.task_lines)
      ? body.task_lines.map((t) => str(t)).filter(Boolean)
      : Array.isArray(tpl.task_lines)
      ? (tpl.task_lines as unknown[]).map((t) => str(t)).filter(Boolean)
      : [];

    if (taskLines.length === 0) {
      return json({ error: "At least one checklist task is required" }, 400);
    }

    const hasPlant = pack === null || pack.includes("plant");
    if (!hasPlant && workspace.organizationId) {
      const fieldOnly = await isFieldCaptureOnly(admin, workspace.organizationId);
      if (fieldOnly) {
        const usage = await countByDiscipline(admin, workspace.organizationId);
        const used = usage[discipline] ?? 0;
        if (used >= PM_TEMPLATE_LIMIT) {
          return json({
            error: `Template limit reached for ${discipline} (${used}/${PM_TEMPLATE_LIMIT}). Upgrade to Plant CMMS for unlimited templates.`,
            limit: PM_TEMPLATE_LIMIT,
            used,
            discipline,
            upgrade_url: "https://openminerals.ai/capture/upgrade",
          }, 403);
        }
      }
    }

    if (!workspace.mineSiteId) {
      return json({ error: "Site not provisioned yet" }, 400);
    }

    const tasksPayload = taskLines.map((t) => ({ task: t }));
    const { data: master, error: masterErr } = await admin
      .from("pm_master_list")
      .insert({
        pm_name: pmName,
        plant_area: plantArea,
        discipline,
        frequency,
        plan_type: "pm",
        plan_category: "Preventive",
        status: "Active",
        tasks: tasksPayload,
        mine_site_id: workspace.mineSiteId,
        created_by: auth.userId,
      })
      .select("id")
      .single();

    if (masterErr) return json({ error: masterErr.message }, 500);

    const formStructure = buildFormStructure(taskLines);
    const { data: schedule, error: schedErr } = await admin
      .from("pm_schedule_templates")
      .insert({
        name: pmName,
        area: plantArea,
        frequency_type: frequency,
        form_structure: formStructure,
        is_active: true,
        pm_master_list_id: master?.id,
        mine_site_id: workspace.mineSiteId,
      })
      .select("id, name, area, frequency_type, form_structure, pm_master_list_id")
      .single();

    if (schedErr) return json({ error: schedErr.message }, 500);

    await writeAuditLog(admin, {
      userId: auth.userId,
      actionType: "create",
      entityType: "pm_schedule_template",
      entityId: schedule?.id ?? "",
      newValue: { pm_name: pmName, discipline },
      metadata: { source: "heevy_inspect_mobile" },
    });

    return json({
      ok: true,
      pm_master_list_id: master?.id,
      schedule_template: schedule,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
