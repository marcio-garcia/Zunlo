// supabase/functions/_shared/sse_tee.ts
export const LOG_PROMPT_EVENTS =
  (Deno.env.get("LOG_PROMPT_EVENTS") ?? "0") === "1";

type AnyObj = Record<string, unknown>;

function safeJSON(s: string): AnyObj | null {
  try { return JSON.parse(s); } catch { return null; }
}

export type SSETeeState = {
  currentEvent?: string;
  dataBuf?: string[]; // accumulate multiple data: lines per SSE event
};

/**
 * Call this with every decoded SSE chunk string.
 * It buffers data lines until a blank line, then logs one complete event.
 */
export function teeLogResponsesSSE(chunkStr: string, state: SSETeeState = {}): SSETeeState {
  if (!LOG_PROMPT_EVENTS) return state;

  let current = state.currentEvent ?? "";
  let buf = state.dataBuf ?? [];

  const flush = (dataRaw: string) => {
    if (!dataRaw) return;
    const obj = safeJSON(dataRaw);

    // response.created
    if (current === "response.created") {
      const rid = obj?.response?.id ?? obj?.id;
      const model = obj?.response?.model ?? obj?.model;
      const temperature = obj?.response?.temperature ?? obj?.temperature;
      console.log(JSON.stringify({ event: current, at: new Date().toISOString(), response_id: rid, model, temperature }));
      return;
    }

    // response.required_action
    if (current === "response.required_action") {
      const ra = (obj?.required_action ?? {}) as AnyObj;
      if (ra["type"] === "submit_tool_outputs") {
        const tools = (ra["tools"] as any[] | undefined)?.map(t => ({
          id: t?.id, name: t?.name,
          hasArgs: !!t?.arguments,
          argKeys: t?.arguments && typeof t.arguments === "object" ? Object.keys(t.arguments) : [],
        }));
        console.log(JSON.stringify({
          event: current, at: new Date().toISOString(),
          response_id: obj?.response?.id ?? obj?.id, tools
        }, null, 2));
      }
      return;
    }

    // error (generic) or response.error
    if (current === "error" || current === "response.error") {
      const err = (obj?.error ?? obj) as AnyObj;
      console.error(JSON.stringify({
        event: current, at: new Date().toISOString(),
        message: err?.message ?? err,
        type: err?.type, code: err?.code, param: err?.param, raw: obj ?? dataRaw,
      }, null, 2));
      return;
    }

    // response.failed
    if (current === "response.failed") {
      console.error(JSON.stringify({
        event: current, at: new Date().toISOString(),
        response_id: obj?.response?.id ?? obj?.id,
        status: obj?.response?.status ?? obj?.status,
        last_error: obj?.response?.error ?? obj?.error ?? null,
        raw: obj ?? dataRaw
      }, null, 2));
      return;
    }

    // response.completed (nice to see once)
    if (current === "response.completed") {
      console.log(JSON.stringify({
        event: current, at: new Date().toISOString(),
        response_id: obj?.response?.id ?? obj?.id
      }));
      return;
    }
  };

  for (const line of chunkStr.split(/\r?\n/)) {
    if (line.startsWith("event:")) {
      current = line.slice(6).trim();
      continue;
    }
    if (line.startsWith("data:")) {
      buf.push(line.slice(5));
      continue;
    }
    if (line === "") {
      const dataRaw = buf.join("\n").trim();
      buf = [];
      flush(dataRaw);
    }
  }

  return { currentEvent: current, dataBuf: buf };
}
