import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS_HEADERS,
  json,
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
    const paths = Array.isArray(body.paths)
      ? body.paths.map((p) => str(p)).filter(Boolean)
      : [];
    if (!paths.length) return json({ error: "paths required" }, 400);

    const admin = serviceClient();
    const bucket = str(body.bucket) || "inspection-uploads";
    const signed: Record<string, string> = {};

    for (const path of paths) {
      const clean = path.replace(/^inspection-uploads\//, "");
      const { data, error } = await admin.storage
        .from(bucket)
        .createSignedUrl(clean, 60 * 60 * 24);
      if (!error && data?.signedUrl) signed[path] = data.signedUrl;
    }

    return json({ ok: true, signed_urls: signed });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
