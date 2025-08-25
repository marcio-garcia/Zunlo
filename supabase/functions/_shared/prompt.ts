// supabase/functions/_shared/prompt.ts
// Single responsibility: define the system prompt + model-facing tool specs,
// and provide a helper to enrich a Responses API body (attach system + tools).
//
// NOTE: We intentionally import ONLY safe primitives from schemas.ts.
// We do NOT expose BaseMutation / version / idempotency to the model.

// prompt.ts
import {
  // Safe primitives (reused to avoid duplication)
  reminderTriggerSchema as ReminderTrigger,
  recurrenceRuleSchema as RecurrenceRuleBody,
  eventColorSchema as EventColor,
} from "./schemas.ts";

/** Guardrails & style guide (short, enforceable) */
export const PROMPT_INSTRUCTIONS = `
Zunlo is an app to help people with ADHD manage their tasks and events.
You are Zunlo's assistant for tasks and events.
Never mention ADHD unless the user specifically asks about it.
Always be kind and encouraging, without overdoing it.

Guardrail policy:
- Model talks, tools act.
- Never mutate data via free-form text. Only call the provided tools.
- Ask for confirmation before any destructive or sweeping change (delete, series-wide edits),
  unless the user clearly asked for it (e.g., "delete it now").
- Before retrying a tool call, ask the user to confirm whether the action was successful.

Conventions:
- Current date time: ${Date()}
- If unsure, ask one clarifying question.
- Prefer getting context (“getAgenda”) before proposing changes.
- For recurring edits: single vs this_and_future vs entire_series — choose carefully and explain.
- Apple weekdays: 1=Sun … 7=Sat for recurrence.
- Use editScope=override to change/cancel a single occurrence of a recurring event; use single only for non-recurring events.
`.trim().replace("\n", "");

/* -----------------------------
 * Small local schema primitives
 * ----------------------------- */

const isoDate = { type: "string", format: "date" } as const;
const isoDateTime = { type: "string", format: "date-time" } as const;

/* -----------------------------------
 * Build model-facing argument schemas
 * -----------------------------------
 * We reuse:
 *  - ReminderTrigger      -> as items of reminderTriggers
 *  - RecurrenceRuleBody   -> as recurrenceRule
 *  - EventColor           -> as color enum
 *
 * We keep camelCase property names here (model-facing),
 * while the server wire contracts in schemas.ts use snake_case.
 */

const taskBodyArgs = {
  type: "object",
  additionalProperties: false,
  // strict tool schemas require a "required" array; include all declared keys
  required: [
    "title",
    "notes",
    "dueDate",
    "isCompleted",
    "tags",
    "reminderTriggers",
    "parentEventId",
    "priority"
  ],
  properties: {
    title: { type: "string", minLength: 1, maxLength: 200 },
    // allow null so callers can satisfy strict presence without content
    notes: { anyOf: [{ type: "string", maxLength: 2000 }, { type: "null" }] },
    dueDate: { anyOf: [isoDateTime, { type: "null" }] },
    isCompleted: { type: "boolean" },
    tags: { type: "array", items: { type: "string", minLength: 1 }, maxItems: 50 },
    // ReminderTrigger itself is strict (both keys required; message nullable)
    reminderTriggers: { type: "array", items: ReminderTrigger, maxItems: 5 },
    parentEventId: { anyOf: [{ type: "string" }, { type: "null" }] },
    priority: { type: "string", enum: ["low", "medium", "high"] }
  }
} as const;

const taskPatchArgs = {
  // NOTE: for strict tool schemas, any object needs a "required" array.
  // If you want a truly sparse patch, consider switching patch to an array of field ops.
  // For now, mirror create shape so the validator is happy.
  ...taskBodyArgs,
} as const;

const eventBodyArgs = {
  type: "object",
  additionalProperties: false,
  required: [
    "title",
    "startDatetime",
    "endDatetime",
    "notes",
    "location",
    "color",
    "reminderTriggers",
    "recurrenceRule"
  ],
  properties: {
    title: { type: "string", minLength: 1, maxLength: 200 },
    startDatetime: isoDateTime,
    endDatetime: { anyOf: [isoDateTime, { type: "null" }] },
    notes: { anyOf: [{ type: "string", maxLength: 2000 }, { type: "null" }] },
    location: { anyOf: [{ type: "string", maxLength: 200 }, { type: "null" }] },
    color: { anyOf: [EventColor, { type: "null" }] },
    reminderTriggers: { type: "array", items: ReminderTrigger, maxItems: 5 },
    recurrenceRule: { anyOf: [RecurrenceRuleBody, { type: "null" }] }
  }
} as const;

const eventPatchArgs = {
  ...eventBodyArgs,
} as const;

/* -----------------
 * Tool definitions
 * ----------------- */

type Tool = {
  type: "function",
  function: {
    name: string,
    description?: string,
    strict?: boolean,
    parameters: any
  }
};

export const TOOLS: Tool[] = [
  {
    type: "function",
    name: "getAgenda",
    description: "Get upcoming events and tasks for a time range.",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      required: ["dateRange", "start", "end"], // strict wants all keys required
      properties: {
        dateRange: {
          type: "string",
          enum: ["today", "tomorrow", "week", "custom"],
          description: "Define the period to get events and tasks."
        },
        start: isoDateTime,
        end: isoDateTime,
      }
    }
  },
  {
    type: "function",
    name: "planWeek",
    description: "Suggest a plan; does not write. Returns a ProposedPlan.",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      required: ["startDate", "objectives", "horizon"],
      properties: {
        startDate: isoDate,
        objectives: { type: "array", items: { type: "string" }, maxItems: 20 },
        horizon: { type: "string", enum: ["day", "week"], default: "week" }
      }
    }
  },
  {
    type: "function",
    name: "createTask",
    description: "Create a user task (open-ended todo).",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      required: ["task"],
      properties: {
        task: taskBodyArgs
      }
    }
  },
  {
    type: "function",
    name: "updateTask",
    description: "Update a task by id; send only the fields you want to change in 'patch'.",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      required: ["taskId", "patch"],
      properties: {
        taskId: { type: "string" },
        patch: taskPatchArgs
      }
    }
  },
  {
    type: "function",
    name: "deleteTask",
    description: "Delete/soft-delete a task by id.",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      required: ["taskId"],
      properties: { taskId: { type: "string" } }
    }
  },
  {
    type: "function",
    name: "createEvent",
    description: "Create a calendar event (may be recurring if recurrenceRule provided).",
    strict: true,
    parameters: eventBodyArgs
  },
  {
    type: "function",
    name: "updateEvent",
    description: "Update an event; 'single' uses occurrenceDate to create an override.",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      required: ["eventId", "editScope", "occurrenceDate", "patch"],
      properties: {
        eventId: { type: "string" },
        editScope: { type: "string", enum: ["single", "override", "this_and_future", "entire_series"] },
        occurrenceDate: isoDateTime,
        patch: eventPatchArgs
      }
    }
  },
  {
    type: "function",
    name: "deleteEvent",
    description: "Delete/cancel an event; 'single' cancels one occurrence via override.",
    strict: true,
    parameters: {
      type: "object",
      additionalProperties: false,
      required: ["eventId", "editScope", "occurrenceDate"],
      properties: {
        eventId: { type: "string" },
        editScope: { type: "string", enum: ["single", "override", "this_and_future", "entire_series"] },
        occurrenceDate: isoDateTime
      }
    }
  }
];

/* -------------------------------
 * Enricher for Responses API body
 * -------------------------------
 * - Adds a concise system message if one isn’t present.
 * - Attaches the tool specs unless the client already provided them
 *   (or force=true).
 */

const DEFAULT_TEMPERATURE = Number(Deno.env.get("OPENAI_TEMPERATURE") ?? 0.3);

function clampTemp(n: number) {
  if (!Number.isFinite(n)) return DEFAULT_TEMPERATURE;
  return Math.max(0, Math.min(2, n));
}

export function supportsTemperature(model?: string): boolean {
  if (!model) return true; // default to allow unless we know it's disallowed
  const m = model.toLowerCase();
  // Known families that don't accept temperature/top_p, etc.
  if (m.startsWith("gpt-5")) return false;
  if (m.startsWith("o1")) return false;
  if (m.startsWith("o3")) return false;
  if (m.includes("deep-research")) return false;
  if (m.includes("realtime")) return false;
  return true;
}

export function enrichResponsesBody(body: any, force = false) {
  // const cloned = JSON.parse(JSON.stringify(body ?? {}));
  const cloned: any =
    (typeof structuredClone === "function" ? structuredClone(body ?? {}) : JSON.parse(JSON.stringify(body ?? {})));

  // Payload "input". Ensure messages array exists
  const input = Array.isArray(cloned.input) ? cloned.input : [];
  // const hasSystem = input.some((m: any) => m?.role === "system");
  // if (!hasSystem) {
  //   input.unshift({ role: "system", content: SYSTEM_PROMPT });
  // }
  cloned.input = input;

  // Payload "model". Default reasonable model if not set
  if (!cloned.model) cloned.model = Deno.env.get("OPENAI_MODEL") || "gpt-5-mini";

  const tzId: string | undefined = cloned.localTimezone;
  const nowLocalISO: string | undefined = cloned.localNowISO;

  // Remove helper fields from the payload we send to the model
  delete cloned.localTimezone;
  delete cloned.localNowISO;

  // Build your base/system instructions (your buildPromptInstructions should already flatten newlines)
  const base = buildPromptInstructions(tzId ?? "UTC", nowLocalISO ?? new Date().toISOString());

  // Append/merge logic:
  // - If force=true: always prepend base.
  // - If force=false and no instructions, set base.
  // - If force=false and instructions exist, prepend base unless it already seems present.
  const hasTimePolicy = typeof cloned.instructions === "string" &&
                        /Time handling policy/i.test(cloned.instructions);

  if (force || !cloned.instructions) {
    cloned.instructions = base + (cloned.instructions ? ` ${cloned.instructions}` : "");
  } else if (!hasTimePolicy) {
    cloned.instructions = `${base} ${cloned.instructions}`;
  }

  // Temperature: set only if missing or force=true; clamp to [0,2]
  // Temperature: only if model supports it (or force)
  if (supportsTemperature(cloned.model)) {
    if (force || cloned.temperature == null) {
      cloned.temperature = DEFAULT_TEMPERATURE;
    } else {
      cloned.temperature = clampTemp(Number(cloned.temperature));
    }
  } else {
    // Remove unsupported sampling params
    delete cloned.temperature;
    delete cloned.top_p;
    delete cloned.frequency_penalty;
    delete cloned.presence_penalty;
  }

  // Attach tools if none given or force=true
  if (force || !Array.isArray(cloned.tools) || cloned.tools.length === 0) {
    cloned.tools = TOOLS;
    cloned.tool_choice = "auto";
  }

  // If callers might pass Chat Completions–style tools, normalize:
  // if (Array.isArray(cloned.tools)) cloned.tools = normalizeToolsForResponses(cloned.tools);

  // Always stream
  cloned.stream = true;

  return cloned;
}

export function buildPromptInstructions(tzId: string, nowLocalISO: string) {
  const s = `
Zunlo is an app to help people with ADHD manage their tasks and events.
You are Zunlo's assistant for tasks and events.
Never mention ADHD unless the user specifically asks about it.
Always be kind and encouraging, without overdoing it.

Guardrail policy:
- Model talks, tools act.
- Never mutate data via free-form text. Only call the provided tools.
- Ask for confirmation before any destructive or sweeping change (delete, series-wide edits),
  unless the user clearly asked for it (e.g., "delete it now").
- Before retrying a tool call, ask the user to confirm whether the action was successful.

Time handling policy (UTC-first):
- User time zone: ${tzId}
- Current local time: ${nowLocalISO}
- Interpret all user-relative times in ${tzId}.
- Convert all times to UTC before calling any tool. Use RFC3339 with 'Z' (e.g., 2025-08-25T18:00:00Z).
- When speaking to the user, present times in ${tzId} and mention the zone if helpful.
- For recurrences, treat the wall-clock time in ${tzId} as authoritative (e.g., “every Monday 9:00 in ${tzId}”),
  but pass individual occurrences to tools in UTC.
- For all-day items, treat the local day in ${tzId} as authoritative (00:00–24:00 local),
  but persist UTC boundaries.

### Examples (for reference only — do not execute)
User (${tzId}): create "Call mom" tomorrow at 3pm
Assistant → tools.createTask args: {"title":"Call mom","dueDate":"2025-08-25T18:00:00Z"}
Assistant → Okay! I’ll schedule it for Mon, Aug 25 at 3:00 PM (${tzId}).

Conventions:
- Prefer getting context (“getAgenda”) before proposing changes.
- For recurring edits: single vs this_and_future vs entire_series — choose carefully and explain.
- Apple weekdays: 1=Sun … 7=Sat for recurrence.
- Use editScope=override to change/cancel a single occurrence of a recurring event; use single only for non-recurring events.
`.trim().replace(/\s*\n\s*/g, ' ').replace(/\s{2,}/g, ' ');
  return s;
}