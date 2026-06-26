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
    const scope = str(body.scope).toLowerCase() === "team" ? "team" : "mine";

    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "Field captures not enabled" }, 403);
    }

    if (scope === "team" && !workspace.isOrgManager) {
      return json({ error: "Team view requires supervisor role" }, 403);
    }

    let query = admin
      .from("field_captures")
      .select(
        "id, created_at, plant_area, severity, notes, photo_urls, status, work_request_id, voice_transcript, created_by",
      )
      .order("created_at", { ascending: false })
      .limit(100);

    if (scope === "team") {
      if (!workspace.organizationId) {
        return json({ error: "Organization not provisioned" }, 400);
      }
      query = query.eq("organization_id", workspace.organizationId);
    } else {
      query = query.eq("created_by", auth.userId);
    }

    const { data, error } = await query;
    if (error) return json({ error: error.message }, 500);

    const captures = data ?? [];
    const wrIds = [
      ...new Set(
        captures
          .map((c) => str((c as Record<string, unknown>).work_request_id))
          .filter(Boolean),
      ),
    ];
    const creatorIds = [
      ...new Set(
        captures
          .map((c) => str((c as Record<string, unknown>).created_by))
          .filter(Boolean),
      ),
    ];

    const wrMap: Record<string, string> = {};
    if (wrIds.length > 0) {
      const { data: wrRows } = await admin
        .from("work_requests")
        .select("id, wr_number")
        .in("id", wrIds);
      for (const w of wrRows ?? []) {
        const wid = str(w.id);
        if (wid) wrMap[wid] = str(w.wr_number);
      }
    }

    const creatorNames: Record<string, string> = {};
    if (creatorIds.length > 0) {
      const { data: profiles } = await admin
        .from("profiles")
        .select("id, full_name, email")
        .in("id", creatorIds);
      for (const p of profiles ?? []) {
        const id = str(p.id);
        const label = str(p.full_name) || str(p.email) || "Crew member";
        if (id) creatorNames[id] = label;
      }
    }

    const items = captures.map((row) => {
      const c = row as Record<string, unknown>;
      const wrId = str(c.work_request_id);
      const createdBy = str(c.created_by);
      return {
        ...c,
        wr_number: wrId ? (wrMap[wrId] ?? null) : null,
        created_by_name: createdBy ? (creatorNames[createdBy] ?? null) : null,
      };
    });

    return json({
      ok: true,
      scope,
      is_org_manager: workspace.isOrgManager,
      items,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
