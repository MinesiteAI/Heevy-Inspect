import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS_HEADERS,
  fetchOrgPack,
  json,
  packAllows,
  resolveWorkspace,
  serviceClient,
  verifyJwt,
} from "../_shared/inspect-auth.ts";
import { listAccessibleWorkOrders } from "../_shared/mobile-work-order-scope.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST" && req.method !== "GET") {
    return json({ error: "Use GET or POST" }, 405);
  }

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);
    const pack = await fetchOrgPack(admin, workspace.organizationId);

    if (!packAllows(pack, "field_capture")) {
      return json({ error: "Work orders not enabled" }, 403);
    }

    const items = await listAccessibleWorkOrders(admin, workspace, auth.userId);

    return json({ ok: true, items });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
