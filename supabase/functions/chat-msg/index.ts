// Purpose: validate auth, then proxy the Responses API stream as-is.
// Phase 1 does NOT implement quotas or tool execution; it's just the pipe.
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { teeLogResponsesSSE } from "../_shared/sse_tee.ts";
import { withAuth } from "../_shared/guard.ts";
import { postResponsesStream } from "../_shared/openai.ts";
import { enrichResponsesBody } from "../_shared/prompt.ts";
import {
  assertChatAllowance,
  estimateTokensFromText,
  recordChatUsage,
  jsonErr,
} from "../_shared/entitlements.ts";

const ENFORCE = (Deno.env.get("ENFORCE_QUOTAS") ?? "0") === "1";

Deno.serve(async (req) => {
  // (optional) CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*",
      },
    });
  }

  const auth = await withAuth(req);
  if (auth instanceof Response) return auth;

  // ✅ Support either shape: { userId } or { user: { id } }
  const supabase = (auth as any).supabase;
  const userId: string =
    (auth as any).userId ?? (auth as any).user?.id ?? "";

  if (!userId) return jsonErr("Unauthorized (no user id)", 401);

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return jsonErr("Bad JSON", 400);
  }

  const enriched = payload?.__no_enrich ? payload : enrichResponsesBody(payload);

  // --- Preflight: input token allowance (only if ENFORCE is on) ---
  if (ENFORCE) {
    try {
      const inputMsgs: Array<{ role: string; content: unknown }> = Array.isArray(enriched.input) ? enriched.input : [];
      const combined = inputMsgs
        .map((m) => (typeof m.content === "string" ? m.content : JSON.stringify(m.content)))
        .join("\n");
      const estIn = estimateTokensFromText(combined);
      await assertChatAllowance(supabase, userId, estIn);
    } catch (e) {
      if (e instanceof Response) return e;
      return jsonErr((e as Error).message || "Quota check failed", 400);
    }
  }

if (Array.isArray(enriched.tools) && enriched.tools.length) {
  console.log(
    "tool[0] before OpenAI:",
    JSON.stringify(enriched.tools[0], null, 2)
  );
  // Assert it's Responses-style and not empty:
  const t = enriched.tools[0] as any;
  if (!(t.type === "function" && typeof t.name === "string" && t.parameters)) {
    console.error("❌ Tool not in Responses format");
  } else if (
    t.parameters?.type !== "object" ||
    !t.parameters?.properties ||
    Object.keys(t.parameters.properties).length === 0
  ) {
    console.error("❌ parameters.properties is empty");
  }
}
  console.log(
    "Payload: ",
    JSON.stringify(enriched, null, 2)
  );
  // --- Proxy OpenAI Responses stream ---
  const oai = await postResponsesStream(enriched);

  const { readable, writable } = new TransformStream();
  const body = oai.body;
  if (!body) return jsonErr("Upstream did not return a stream", 502);

  const reader = body.getReader();
  const writer = writable.getWriter();

  let outputChars = 0;

  (async () => {
    const decoder = new TextDecoder();
    const encoder = new TextEncoder();
    try {
      let teeState = {};
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        const chunkStr = decoder.decode(value);
        // crude count for output token estimate
        for (const line of chunkStr.split("\n")) {
          if (line.startsWith("data:")) {
            outputChars += line.slice(5).trim().length;
          }
        }
        
        // Tee-log (no side effects on stream)
        teeState = teeLogResponsesSSE(chunkStr, teeState);

        await writer.write(encoder.encode(chunkStr));
      }
    } finally {
      await writer.close();
    }

    // Only record usage when quotas are enforced
    if (ENFORCE) {
      const estOut = Math.ceil(outputChars / 4);
      await recordChatUsage(supabase, userId, 0 /* input preflighted */, estOut);
    }
  })();

  return new Response(readable, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive",
      "Access-Control-Allow-Origin": "*", // optional for testing
    },
  });
});