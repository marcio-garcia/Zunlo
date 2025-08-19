// Single responsibility: Forward a Responses API request to OpenAI with streaming.

export async function postResponsesStream(body: unknown): Promise<Response> {
  const key = Deno.env.get("OPENAI_API_KEY");
  if (!key) throw new Error("OPENAI_API_KEY missing");
  const model = Deno.env.get("OPENAI_MODEL") || "gpt-4o-mini";

  // If caller didn’t pass a model, use default
  const finalBody = { model, ...((body as any) ?? {}) };

  console.log(JSON.stringify({
  event: "openai.request.summary",
  model: finalBody.model,
  }, null, 2));

  const makeReq = async (b: any) => {
    const resp = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Authorization": `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify(b),
    });
    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(`OpenAI error ${resp.status}: ${text}`);
    }
    return resp;
  };

  try {
    return await makeReq(finalBody);
  } catch (e: any) {
    // Auto-retry if the server rejects temperature (defensive)
    const msg = String(e?.message ?? "");
    if (msg.includes("'temperature'") && msg.includes("Unsupported parameter")) {
      const retryBody = { ...finalBody };
      delete retryBody.temperature;
      delete retryBody.top_p;
      return await makeReq(retryBody);
    }
    throw e;
  }
}
