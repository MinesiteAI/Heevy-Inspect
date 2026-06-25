import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  CORS_HEADERS,
  json,
  resolveWorkspace,
  serviceClient,
  str,
  verifyJwt,
} from "../_shared/inspect-auth.ts";

function asRecord(v: unknown): Record<string, unknown> {
  return v && typeof v === "object" ? (v as Record<string, unknown>) : {};
}

const GLOSSARY: Record<string, string> = {
  idler:
    "A conveyor idler is a roller that supports the belt and helps it track. Worn or seized idlers cause belt damage, spillage, and increased power draw.",
  "belt drift":
    "Belt drift is when the conveyor belt moves sideways off the rollers. Common causes include misaligned idlers, uneven loading, or structural movement.",
  "hot work":
    "Hot work involves welding, grinding, or cutting that can produce sparks or heat. It typically requires a permit, fire watch, and area isolation.",
  "lockout":
    "Lockout/tagout (LOTO) isolates energy sources before maintenance. Always follow your site isolation procedure — do not rely on general advice alone.",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Use POST" }, 405);

  try {
    const auth = await verifyJwt(req);
    if (!auth.ok) return json({ error: auth.error }, auth.status);

    const body = asRecord(await req.json());
    const message = str(body.message);
    const conversationId = str(body.conversation_id) || null;
    const sourceType = str(body.source_type) || null;
    const sourceId = str(body.source_id) || null;

    if (!message) return json({ error: "message required" }, 400);

    const admin = serviceClient();
    const workspace = await resolveWorkspace(admin, auth.userId);

    let convId = conversationId;
    if (!convId) {
      const { data: conv } = await admin
        .from("mobile_ask_conversations")
        .insert({
          user_id: auth.userId,
          title: message.slice(0, 60),
        })
        .select("id")
        .single();
      convId = conv?.id ?? null;
    }

    await admin.from("mobile_ask_messages").insert({
      conversation_id: convId,
      user_id: auth.userId,
      role: "user",
      content: message,
    });

    const contextParts: string[] = [];
    if (sourceType && sourceId) {
      contextParts.push(`User is asking about ${sourceType} ${sourceId}.`);
    }

    const captures = await admin
      .from("field_captures")
      .select("id, plant_area, severity, notes, created_at")
      .eq("created_by", auth.userId)
      .order("created_at", { ascending: false })
      .limit(5);
    if (captures.data?.length) {
      contextParts.push(
        `Recent captures: ${JSON.stringify(captures.data)}`,
      );
    }

    const pms = await admin
      .from("pm_form_submissions")
      .select("id, template_id, status, submitted_at, notes")
      .eq("created_by", auth.userId)
      .order("submitted_at", { ascending: false })
      .limit(5);
    if (pms.data?.length) {
      contextParts.push(`Recent PM submissions: ${JSON.stringify(pms.data)}`);
    }

    let woQuery = admin
      .from("work_orders")
      .select("id, work_order_number, title, status, priority")
      .order("created_at", { ascending: false })
      .limit(5);
    if (workspace.mineSiteId) {
      woQuery = woQuery.eq("mine_site_id", workspace.mineSiteId);
    } else {
      woQuery = woQuery.eq("created_by", auth.userId);
    }
    const wos = await woQuery;
    if (wos.data?.length) {
      contextParts.push(`Recent work orders: ${JSON.stringify(wos.data)}`);
    }

    const lower = message.toLowerCase();
    for (const [term, definition] of Object.entries(GLOSSARY)) {
      if (lower.includes(term)) {
        contextParts.push(`Glossary — ${term}: ${definition}`);
      }
    }

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    let reply: string;

    if (apiKey) {
      const system = [
        "You are Heevy Field Guide, a maintenance assistant for mining and industrial field teams.",
        "Answer using only the user's own records provided in context when relevant.",
        "For safety-critical work (isolation, hot work, confined space), remind users to follow site procedures.",
        "Be concise and practical.",
        contextParts.join("\n"),
      ].join("\n\n");

      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [
              { role: "user", parts: [{ text: `${system}\n\nUser: ${message}` }] },
            ],
          }),
        },
      );
      const data = await res.json();
      reply = data?.candidates?.[0]?.content?.parts?.[0]?.text ??
        "I could not generate a response. Please try again.";
    } else {
      reply =
        "Field Guide is in limited mode. I can help with glossary terms and your recent captures once AI is configured on the server.";
      if (contextParts.length) {
        reply += `\n\nContext loaded: ${contextParts.length} record group(s).`;
      }
    }

    await admin.from("mobile_ask_messages").insert({
      conversation_id: convId,
      user_id: auth.userId,
      role: "assistant",
      content: reply,
    });

    return json({
      ok: true,
      conversation_id: convId,
      reply,
    });
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
