import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { CORS_HEADERS, json, serviceClient, str, verifyJwt } from "../_shared/inspect-auth.ts";

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
    const deviceToken = str(body.device_token);
    if (!deviceToken) return json({ error: "device_token required" }, 400);

    const admin = serviceClient();
    const patch = {
      user_id: auth.userId,
      device_token: deviceToken,
      platform: str(body.platform || "ios"),
      app_build: str(body.app_build) || null,
      environment: str(body.environment) || null,
      last_seen_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { error } = await admin
      .from("mobile_push_devices")
      .upsert(patch, { onConflict: "device_token" });
    if (error) return json({ error: error.message }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
