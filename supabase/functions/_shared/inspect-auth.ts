import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export function str(v: unknown): string {
  return (v ?? "").toString().trim();
}

export type WorkspaceContext = {
  userId: string;
  email: string | null;
  organizationId: string | null;
  mineSiteId: string | null;
  fullName: string | null;
};

export async function verifyJwt(req: Request): Promise<
  | { ok: true; jwt: string; userId: string; email: string | null }
  | { ok: false; status: number; error: string }
> {
  const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
  if (!jwt) return { ok: false, status: 401, error: "Missing Authorization" };

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data?.user?.id) {
    return { ok: false, status: 401, error: "Unauthorized" };
  }
  return {
    ok: true,
    jwt,
    userId: data.user.id,
    email: data.user.email ?? null,
  };
}

export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

export async function resolveWorkspace(
  admin: SupabaseClient,
  userId: string,
): Promise<WorkspaceContext> {
  const { data: profile } = await admin
    .from("profiles")
    .select("organization_id, full_name, email")
    .eq("id", userId)
    .maybeSingle();

  const organizationId = profile?.organization_id ?? null;
  let mineSiteId: string | null = null;

  if (organizationId) {
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

  return {
    userId,
    email: profile?.email ?? null,
    organizationId,
    mineSiteId,
    fullName: profile?.full_name ?? null,
  };
}

export async function fetchOrgPack(
  admin: SupabaseClient,
  organizationId: string | null,
): Promise<string[] | null> {
  if (!organizationId) return ["field_capture", "personal", "ask"];
  const { data: org } = await admin
    .from("organizations")
    .select("industry_key, modules_of_interest")
    .eq("id", organizationId)
    .maybeSingle();
  const { data: pack } = await admin.rpc("org_resolved_pack_keys", {
    _industry_key: (org?.industry_key as string) ?? "general",
    _modules: org?.modules_of_interest ?? [],
  });
  if (pack === null) return null;
  return Array.isArray(pack) ? (pack as string[]) : [];
}

export function packAllows(
  pack: string[] | null,
  flag: "field_capture" | "plant",
): boolean {
  if (pack === null) return true;
  if (flag === "field_capture") {
    return pack.includes("field_capture") || pack.includes("plant");
  }
  return pack.includes("plant");
}

export async function writeAuditLog(
  admin: SupabaseClient,
  payload: {
    userId: string;
    actionType: string;
    entityType: string;
    entityId: string;
    newValue?: Record<string, unknown> | null;
    metadata?: Record<string, unknown> | null;
  },
) {
  const { error } = await admin.from("audit_logs").insert({
    user_id: payload.userId,
    action_type: payload.actionType,
    entity_type: payload.entityType,
    entity_id: payload.entityId,
    new_value: payload.newValue ?? null,
    metadata: payload.metadata ?? null,
  });
  if (error) console.error("audit_logs:", error.message);
}

export function decodeBase64(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

export async function uploadPhotosFromPayloads(
  admin: SupabaseClient,
  userId: string,
  body: Record<string, unknown>,
  prefix: string,
): Promise<string[]> {
  const urls = Array.isArray(body.photo_urls)
    ? body.photo_urls.map((u) => str(u)).filter(Boolean)
    : [];
  const payloads = Array.isArray(body.photo_payloads) ? body.photo_payloads : [];

  for (let i = 0; i < payloads.length; i++) {
    const item = payloads[i];
    if (!item || typeof item !== "object") continue;
    const row = item as Record<string, unknown>;
    const b64 = str(row.data_base64);
    if (!b64) continue;
    const mime = str(row.mime) || "image/jpeg";
    const ext = str(row.ext) || "jpg";
    const path = `${prefix}/${userId}/${Date.now()}_${i}.${ext.replace(/^\./, "")}`;
    const { error: upErr } = await admin.storage
      .from("inspection-uploads")
      .upload(path, decodeBase64(b64), { contentType: mime, upsert: false });
    if (upErr) throw new Error(`Photo upload failed: ${upErr.message}`);
    const { data: signed } = await admin.storage
      .from("inspection-uploads")
      .createSignedUrl(path, 60 * 60 * 24 * 365);
    urls.push(signed?.signedUrl ?? `inspection-uploads/${path}`);
  }
  return urls;
}
