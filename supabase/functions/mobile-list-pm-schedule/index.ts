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
import { notifyOrgManagers } from "../_shared/mobile-notify.ts";

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = asRecord(await req.json());
    const windowDays = Math.min(30, Math.max(1, Number(body.days_ahead) || 7));

    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "PM schedule not enabled" }, 403);
    }

    if (!workspace.mineSiteId) {
      return json({ error: "Site not provisioned yet" }, 400);
    }

    const today = todayIsoDate();
    const endDate = new Date();
    endDate.setUTCDate(endDate.getUTCDate() + windowDays);
    const endIso = endDate.toISOString().slice(0, 10);

    const { data, error } = await admin
      .from("scheduled_pm_instances")
      .select(
        "id, pm_template_id, pm_template_name, frequency, area, scheduled_date, status, estimated_hours, assigned_to, work_order_id",
      )
      .eq("mine_site_id", workspace.mineSiteId)
      .in("status", ["scheduled", "in_progress"])
      .lte("scheduled_date", endIso)
      .order("scheduled_date", { ascending: true })
      .limit(200);

    if (error) return json({ error: error.message }, 500);

    const overdue: Record<string, unknown>[] = [];
    const dueToday: Record<string, unknown>[] = [];
    const upcoming: Record<string, unknown>[] = [];

    for (const row of data ?? []) {
      const r = row as Record<string, unknown>;
      const scheduled = str(r.scheduled_date);
      if (!scheduled) continue;
      if (scheduled < today) {
        overdue.push(r);
      } else if (scheduled === today) {
        dueToday.push(r);
      } else {
        upcoming.push(r);
      }
    }

    if (workspace.isOrgManager && overdue.length > 0 && workspace.mineSiteId) {
      await notifyOrgManagers(admin, workspace.organizationId, {
        type: "pm_overdue",
        title: "Overdue PM inspections",
        body: `${overdue.length} PM${overdue.length === 1 ? "" : "s"} overdue on your site`,
        payloadJson: {
          mine_site_id: workspace.mineSiteId,
          overdue_count: overdue.length,
        },
        dedupeKey: `pm_overdue_${workspace.mineSiteId}_${today}`,
      });
    }

    return json({
      ok: true,
      today,
      overdue,
      due_today: dueToday,
      upcoming,
      total_open: (data ?? []).length,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
