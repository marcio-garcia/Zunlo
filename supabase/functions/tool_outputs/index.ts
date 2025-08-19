// supabase/functions/chat_tool_outputs/index.ts
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { withAuth } from "../_shared/guard.ts";

const KEY = Deno.env.get("OPENAI_API_KEY")!;
Deno.serve(async (req) => {
  const auth = await withAuth(req);
  if (auth instanceof Response) return auth;

  let body: any; try { body = await req.json(); } catch { 
    return new Response(JSON.stringify({ error: "Bad JSON" }), { status: 400 });
  }

  const responseId = body?.response_id;
  const toolOutputs = body?.tool_outputs;
  if (!responseId || !Array.isArray(toolOutputs)) {
    return new Response(JSON.stringify({ error: "Missing response_id/tool_outputs" }), { status: 400 });
  }

  const res = await fetch(`https://api.openai.com/v1/responses/${responseId}/tool_outputs`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ tool_outputs: toolOutputs }),
  });

  if (!res.ok) {
    return new Response(await res.text(), { status: res.status });
  }
  return new Response(await res.text(), { status: 200, headers: { "Content-Type": "application/json" } });
});