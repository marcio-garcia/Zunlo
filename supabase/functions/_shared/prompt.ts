// supabase/functions/_shared/prompt.ts
// Single responsibility: define the system prompt + model-facing tool specs,
// and provide a helper to enrich a Responses API body (attach system + tools).
//
// NOTE: We intentionally import ONLY safe primitives from schemas.ts.
// We do NOT expose BaseMutation / version / idempotency to the model.

import {
  // Safe primitives (reused to avoid duplication)
  reminderTriggerSchema as ReminderTrigger,
  recurrenceRuleSchema as RecurrenceRuleBody,
  eventColorSchema as EventColor,
} from "./schemas.ts";

/** Guardrails & style guide (short, enforceable) */
export const SYSTEM_PROMPT = `
You are Zunlo’s assistant for tasks and events.

Guardrail policy:
- Model talks, tools act.
- Never mutate data via free-form text. Only call the provided tools.
- Ask for confirmation before any destructive or sweeping change (delete, series-wide edits),
  unless the user clearly asked for it (e.g., "delete it now").

Conventions:
- If unsure, ask one clarifying question.
- Prefer getting context (“getAgenda”) before proposing changes.
- For recurring edits: single vs this_and_future vs entire_series — choose carefully and explain.
- Apple weekdays: 1=Sun … 7=Sat for recurrence.
- Use editScope=override to change/cancel a single occurrence of a recurring event; use single only for non-recurring events.
`.trim();

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
  required: ["title"],
  properties: {
    title: { type: "string", minLength: 1, maxLength: 200 },
    notes: { type: "string", maxLength: 2000 },
    dueDate: isoDateTime,
    isCompleted: { type: "boolean" },
    tags: { type: "array", items: { type: "string", minLength: 1 }, maxItems: 50 },
    reminderTriggers: { type: "array", items: ReminderTrigger, maxItems: 5 },
    parentEventId: { type: "string" },
    priority: { enum: ["low", "medium", "high"] }
  }
} as const;

const taskPatchArgs = {
  ...taskBodyArgs,
  required: [], // all optional for patch
} as const;

const eventBodyArgs = {
  type: "object",
  additionalProperties: false,
  required: ["title", "startDatetime"],
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
  required: [], // all optional for patch
} as const;

/* -----------------
 * Tool definitions
 * ----------------- */

type Tool = {
  type: "function",
  function: {
    name: string,
    description?: string,
    parameters: any
  }
};

export const TOOLS: Tool[] = [
  {
    type: "function",
    name: "getAgenda",
    description: "Get upcoming events and tasks for a time range.",
    input_schema: {
      type: "object",
      additionalProperties: false,
      required: ["dateRange"],
      properties: {
        dateRange: { type: "string", enum: ["today", "tomorrow", "week", "custom"] },
        start: isoDateTime,
        end: isoDateTime,
      },
      allOf: [
        { if: { properties: { dateRange: { const: "custom" } } }, then: { required: ["start", "end"] } }
      ]
    }
  },
  {
    type: "function",
    name: "planWeek",
    description: "Suggest a plan; does not write. Returns a ProposedPlan.",
    input_schema: {
      type: "object",
      additionalProperties: false,
      required: ["startDate"],
      properties: {
        startDate: isoDate,
        objectives: { type: "array", items: { type: "string" }, maxItems: 20 },
        constraints: { type: "object", additionalProperties: true },
        horizon: { type: "string", enum: ["day", "week"], default: "week" }
      }
    }
  },
  { type: "function", name: "createTask", description: "Create a user task (open-ended todo).", input_schema: taskBodyArgs },
  {
    type: "function",
    name: "updateTask",
    description: "Update a task by id; send only the fields you want to change in 'patch'.",
    input_schema: {
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
    input_schema: {
      type: "object",
      additionalProperties: false,
      required: ["taskId"],
      properties: { taskId: { type: "string" } }
    }
  },
  { type: "function", name: "createEvent", description: "Create a calendar event (may be recurring if recurrenceRule provided).", input_schema: eventBodyArgs },
  {
    type: "function",
    name: "updateEvent",
    description: "Update an event; 'single' uses occurrenceDate to create an override.",
    input_schema: {
      type: "object",
      additionalProperties: false,
      required: ["eventId", "editScope", "patch"],
      properties: {
        eventId: { type: "string" },
        editScope: { type: "string", enum: ["single", "override", "this_and_future", "entire_series"] },
        occurrenceDate: isoDateTime, // required for override & this_and_future
        patch: eventPatchArgs
      },
      allOf: [
        { if: { properties: { editScope: { const: "override" } } }, then: { required: ["occurrenceDate"] } },
        { if: { properties: { editScope: { const: "this_and_future" } } }, then: { required: ["occurrenceDate"] } }
      ]
    }
  },
  {
    type: "function",
    name: "deleteEvent",
    description: "Delete/cancel an event; 'single' cancels one occurrence via override.",
    input_schema: {
      type: "object",
      additionalProperties: false,
      required: ["eventId", "editScope"],
      properties: {
        eventId: { type: "string" },
        editScope: { type: "string", enum: ["single", "override", "this_and_future", "entire_series"] },
        occurrenceDate: isoDateTime
      },
      allOf: [
        { if: { properties: { editScope: { const: "override" } } }, then: { required: ["occurrenceDate"] } },
        { if: { properties: { editScope: { const: "this_and_future" } } }, then: { required: ["occurrenceDate"] } }
      ]
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
  const cloned = JSON.parse(JSON.stringify(body ?? {}));

  // Ensure messages array exists
  const input = Array.isArray(cloned.input) ? cloned.input : [];
  const hasSystem = input.some((m: any) => m?.role === "system");
  if (!hasSystem) {
    input.unshift({ role: "system", content: SYSTEM_PROMPT });
  }
  cloned.input = input;

  // Default reasonable model if not set
  if (!cloned.model) cloned.model = Deno.env.get("OPENAI_MODEL") || "gpt-5-mini";

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