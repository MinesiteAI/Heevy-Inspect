import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { str, type WorkspaceContext } from "./inspect-auth.ts";

/** True when the user may open this WO on mobile (site match or WR-linked on site). */
export async function isWorkOrderAccessible(
  admin: SupabaseClient,
  workOrderId: string,
  workspace: WorkspaceContext,
  userId: string,
): Promise<boolean> {
  const { data: wo } = await admin
    .from("work_orders")
    .select("id, mine_site_id, created_by")
    .eq("id", workOrderId)
    .maybeSingle();

  if (!wo) return false;

  if (workspace.mineSiteId) {
    if (str(wo.mine_site_id) === workspace.mineSiteId) return true;

    let wrQuery = admin
      .from("work_requests")
      .select("id, created_by")
      .eq("linked_wo_id", workOrderId)
      .eq("mine_site_id", workspace.mineSiteId);

    const { data: wrLink } = await wrQuery.maybeSingle();
    if (!wrLink) return false;

    const wrCreatedBy = str(wrLink.created_by);
    return wrCreatedBy === userId || workspace.isOrgManager;
  }

  return str(wo.created_by) === userId;
}

export async function fetchAccessibleWorkOrder(
  admin: SupabaseClient,
  workOrderId: string,
  workspace: WorkspaceContext,
  userId: string,
): Promise<Record<string, unknown> | null> {
  let query = admin.from("work_orders").select("*").eq("id", workOrderId);

  if (workspace.mineSiteId) {
    query = query.eq("mine_site_id", workspace.mineSiteId);
  } else {
    query = query.eq("created_by", userId);
  }

  const { data: scoped } = await query.maybeSingle();
  if (scoped) return scoped as Record<string, unknown>;

  const allowed = await isWorkOrderAccessible(
    admin,
    workOrderId,
    workspace,
    userId,
  );
  if (!allowed) return null;

  const { data: wo } = await admin
    .from("work_orders")
    .select("*")
    .eq("id", workOrderId)
    .maybeSingle();

  return wo as Record<string, unknown> | null;
}

const WO_LIST_COLUMNS =
  "id, work_order_number, title, description, status, priority, location, asset_name, source_type, source_id, photo_urls, created_at, updated_at";

/** Site WOs plus WOs linked from WRs on the same site (web-converted). */
export async function listAccessibleWorkOrders(
  admin: SupabaseClient,
  workspace: WorkspaceContext,
  userId: string,
): Promise<Record<string, unknown>[]> {
  if (!workspace.mineSiteId) {
    const { data } = await admin
      .from("work_orders")
      .select(WO_LIST_COLUMNS)
      .eq("created_by", userId)
      .order("created_at", { ascending: false })
      .limit(100);
    return (data ?? []) as Record<string, unknown>[];
  }

  const { data: siteItems, error: siteErr } = await admin
    .from("work_orders")
    .select(WO_LIST_COLUMNS)
    .eq("mine_site_id", workspace.mineSiteId)
    .order("created_at", { ascending: false })
    .limit(100);

  if (siteErr) throw siteErr;

  const { data: linkedWrs } = await admin
    .from("work_requests")
    .select("linked_wo_id, created_by")
    .eq("mine_site_id", workspace.mineSiteId)
    .not("linked_wo_id", "is", null);

  const linkedIds = new Set<string>();
  for (const row of linkedWrs ?? []) {
    const woId = str((row as Record<string, unknown>).linked_wo_id);
    if (!woId) continue;
    const wrCreatedBy = str((row as Record<string, unknown>).created_by);
    if (wrCreatedBy === userId || workspace.isOrgManager) {
      linkedIds.add(woId);
    }
  }

  const byId = new Map<string, Record<string, unknown>>();
  for (const row of siteItems ?? []) {
    const r = row as Record<string, unknown>;
    const id = str(r.id);
    if (id) byId.set(id, r);
  }

  const missingIds = [...linkedIds].filter((id) => !byId.has(id));
  if (missingIds.length > 0) {
    const { data: linkedItems } = await admin
      .from("work_orders")
      .select(WO_LIST_COLUMNS)
      .in("id", missingIds);
    for (const row of linkedItems ?? []) {
      const r = row as Record<string, unknown>;
      const id = str(r.id);
      if (id) byId.set(id, r);
    }
  }

  return [...byId.values()].sort((a, b) => {
    const aT = str(a.created_at);
    const bT = str(b.created_at);
    return bT.localeCompare(aT);
  });
}
