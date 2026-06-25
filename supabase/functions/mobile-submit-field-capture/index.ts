import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function str(v: unknown): string {
  return (v ?? "").toString().trim();
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "");
    if (!jwt) return json({ error: "Missing Authorization" }, 401);

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(SUPABASE_URL, anon, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });
    const { data: userRes, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userRes?.user?.id) return json({ error: "Unauthorized" }, 401);

    const body = await req.json() as Record<string, unknown>;
    const plantArea = str(body.plant_area);
    const assetId = str(body.asset_id);
    const assetTag = str(body.asset_tag);
    const severity = str(body.severity) || "Medium";
    const notes = str(body.notes);
    const voiceTranscript = str(body.voice_transcript);
    const photoUrls = Array.isArray(body.photo_urls)
      ? body.photo_urls.map((u) => str(u)).filter(Boolean)
      : [];

    const admin = createClient(SUPABASE_URL, serviceRole);

    const { data: profile } = await admin
      .from("profiles")
      .select("organization_id, full_name, email")
      .eq("id", userRes.user.id)
      .maybeSingle();

    let mineSiteId: string | null = str(body.mine_site_id) || null;
    let organizationId = profile?.organization_id ?? null;

    if (!mineSiteId && organizationId) {
      const { data: site } = await admin
        .from("mine_sites")
        .select("id")
        .eq("organization_id", organizationId)
        .eq("is_active", true)
        .order("created_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      mineSiteId = site?.id ?? null;
    }

    const workTitle = notes.length > 80 ? `${notes.slice(0, 77)}...` : (notes || "Field capture");
    const problemDescription = [notes, voiceTranscript].filter(Boolean).join("\n\n");

    const { data: wrNumber } = await admin.rpc("next_wr_number");
    const wrNum = typeof wrNumber === "string" ? wrNumber : `WR-${Date.now()}`;

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
        requested_by: profile?.full_name ?? userRes.user.email ?? "",
        photo_urls: photoUrls,
        created_by: userRes.user.id,
        mine_site_id: mineSiteId,
      })
      .select("id, wr_number")
      .single();

    if (wrErr) return json({ error: wrErr.message }, 500);

    const { data: captureRow, error: capErr } = await admin
      .from("field_captures")
      .insert({
        organization_id: organizationId,
        mine_site_id: mineSiteId,
        created_by: userRes.user.id,
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

    return json({
      ok: true,
      capture_id: captureRow?.id ?? null,
      work_request_id: wrRow?.id ?? null,
      wr_number: wrRow?.wr_number ?? wrNum,
      created_at: captureRow?.created_at ?? null,
    });
  } catch (e) {
    console.error("mobile-submit-field-capture:", e);
    return json({ error: "Internal server error" }, 500);
  }
});
