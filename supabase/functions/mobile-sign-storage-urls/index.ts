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

function extractStoragePath(urlOrPath: string): string | null {
  const s = urlOrPath.trim();
  if (!s) return null;

  if (!s.startsWith("http")) {
    return s.replace(/^inspection-uploads\//, "");
  }

  try {
    const uri = new URL(s);
    const segments = uri.pathname.split("/").filter(Boolean);
    for (let i = 0; i < segments.length; i++) {
      if (segments[i] === "inspection-uploads" && i + 1 < segments.length) {
        return segments.slice(i + 1).join("/");
      }
    }
    const marker = "/inspection-uploads/";
    const idx = uri.pathname.indexOf(marker);
    if (idx >= 0) {
      return uri.pathname.substring(idx + marker.length);
    }
  } catch {
    return null;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = asRecord(await req.json());
    const rawPaths = Array.isArray(body.paths)
      ? body.paths.map((p) => str(p)).filter(Boolean)
      : [];
    if (!rawPaths.length) return json({ error: "paths required" }, 400);

    const admin = serviceClient();
    const bucket = str(body.bucket) || "inspection-uploads";
    const signed: Record<string, string> = {};

    for (const raw of rawPaths) {
      const clean = extractStoragePath(raw);
      if (!clean) continue;
      const { data, error } = await admin.storage
        .from(bucket)
        .createSignedUrl(clean, 60 * 60 * 24);
      if (!error && data?.signedUrl) {
        signed[clean] = data.signedUrl;
        signed[`inspection-uploads/${clean}`] = data.signedUrl;
        signed[raw] = data.signedUrl;
      }
    }

    return json({ ok: true, signed_urls: signed });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
