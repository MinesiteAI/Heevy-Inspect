import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { str } from "./inspect-auth.ts";

export type MobileNotifyParams = {
  userId: string;
  type: string;
  title: string;
  body: string;
  payloadJson?: Record<string, unknown>;
  workOrderId?: string | null;
  workOrderNumber?: string | null;
  dedupeKey?: string | null;
};

async function dispatchPushViaWebhook(
  webhookUrl: string,
  payload: Record<string, unknown>,
) {
  const res = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const bodyText = await res.text();
  return { ok: res.ok, status: res.status, bodyText };
}

export async function insertMobileNotification(
  admin: SupabaseClient,
  params: MobileNotifyParams,
): Promise<{ id: string | null; deduped?: boolean }> {
  const { data, error } = await admin
    .from("mobile_notifications")
    .insert({
      user_id: params.userId,
      type: params.type,
      title: params.title,
      body: params.body,
      payload_json: params.payloadJson ?? {},
      work_order_id: params.workOrderId ?? null,
      work_order_number: params.workOrderNumber ?? null,
      dedupe_key: params.dedupeKey ?? null,
    })
    .select("id")
    .single();

  if (error) {
    if (error.code === "23505") return { id: null, deduped: true };
    console.warn("insertMobileNotification:", error.message);
    return { id: null };
  }

  const notificationId = data?.id as string | null;
  const pushWebhookUrl = Deno.env.get("MOBILE_PUSH_WEBHOOK_URL") ?? "";
  if (pushWebhookUrl && notificationId) {
    const { data: devices } = await admin
      .from("mobile_push_devices")
      .select("device_token, platform")
      .eq("user_id", params.userId);

    if ((devices?.length ?? 0) > 0) {
      const payload = {
        notification_id: notificationId,
        user_id: params.userId,
        title: params.title,
        body: params.body,
        payload_json: params.payloadJson ?? {},
        work_order_id: params.workOrderId ?? null,
        work_order_number: params.workOrderNumber ?? null,
        devices,
      };
      const pushRes = await dispatchPushViaWebhook(pushWebhookUrl, payload);
      await admin.from("mobile_push_dispatch_log").insert({
        notification_id: notificationId,
        user_id: params.userId,
        request_payload: payload,
        response_payload: { status: pushRes.status, body: pushRes.bodyText },
        success: pushRes.ok,
        error: pushRes.ok ? null : "push webhook non-2xx",
      });
    }
  }

  return { id: notificationId };
}

export async function notifyOrgManagers(
  admin: SupabaseClient,
  organizationId: string | null,
  params: Omit<MobileNotifyParams, "userId"> & { excludeUserId?: string },
): Promise<number> {
  if (!organizationId) return 0;

  const { data: managers } = await admin
    .from("profiles")
    .select("id")
    .eq("organization_id", organizationId)
    .eq("is_org_manager", true);

  let sent = 0;
  for (const mgr of managers ?? []) {
    const mgrId = str(mgr.id);
    if (!mgrId || mgrId === params.excludeUserId) continue;
    await insertMobileNotification(admin, {
      userId: mgrId,
      type: params.type,
      title: params.title,
      body: params.body,
      payloadJson: params.payloadJson,
      workOrderId: params.workOrderId,
      workOrderNumber: params.workOrderNumber,
      dedupeKey: params.dedupeKey
        ? `${params.dedupeKey}:${mgrId}`
        : null,
    });
    sent++;
  }
  return sent;
}
