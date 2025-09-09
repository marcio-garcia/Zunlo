/**
 * Phase 0 — Contracts for tool payloads (TypeScript + JSON Schemas)
 * Single responsibility: define wire-level types and JSON Schemas shared by Edge Functions
 * (server) and optionally by the iOS client for compile-time checking.
 *
 * Concurrency:
 * - We use version-based optimistic concurrency everywhere (version: number).
 * - Clients must send the last-seen version on update/delete; server increments on success.
 *
 * Recurrence:
 * - Apple weekday numbering for byWeekday: 1=Sun, 2=Mon, …, 7=Sat.
 *
 * Reminders:
 * - Your format: [{ timeBeforeDue: seconds, message?: string }]
 */

// schemas.ts

const isoDate = { type: 'string', format: 'date' } as const;
export const isoDateTime = { 
  type: 'string',
  pattern: '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:Z|[+-]\\d{2}:\\d{2})?$'
};

/* --------------------------------
 * Shared tiny TypeScript interfaces
 * -------------------------------- */

export interface ReminderTrigger {
  /** seconds before start/due (>= 0). Example: 900 (15m), 1800 (30m) */
  timeBeforeDue: number;
  /** optional message to display with the reminder */
  message: string | null;
}

/** Keep your exact color raw values (hex as strings) */
export type EventColor =
  | "#FFD966" | "#AEEAF9" | "#F6B9C1" | "#D1F7C4" | "#D6C3FF"
  | "#A8F6FF" | "#B8FFC9" | "#A9DFE6" | "#FFF3B0" | "#FFB3B3"
  | "#C3C8FF" | "#D5E3FF" | "#FFD1DC" | "#FFDAC1" | "#F6E2B3";

export type RecurrenceFrequency = 'daily' | 'weekly' | 'monthly' | 'yearly';

export interface RecurrenceRuleBody {
  /** FREQ from your model */
  freq: 'daily' | 'weekly' | 'monthly' | 'yearly';
  /** default 1 (tool may send null, we’ll coerce to 1) */
  interval: number | null;                  // >= 1
  /** Apple weekday numbering: 1=Sun..7=Sat (tool may send null) */
  byWeekday: number[] | null;
  /** specific month days [1..31] (tool may send null) */
  byMonthday: number[] | null;
  /** months [1..12] (tool may send null) */
  byMonth: number[] | null;
  /** end by date or by count (tool sends null for the unused one) */
  until: string | null;    // ISO 8601 (prefer with timezone)
  count: number | null;    // >= 1
}

/** Envelope for all mutating payloads */
export interface BaseMutation {
  /** 'create' | 'update' | 'delete' (semantic intent) */
  intent: 'create' | 'update' | 'delete';
  /** client-generated UUID to guarantee idempotency server-side */
  idempotencyKey: string;
  /** natural language rationale (helps auditing & UX) */
  reason: string;
  /** preview-only: server returns a diff; no writes performed */
  dryRun: boolean;
}

/* -------------
 * TASK (UserTask)
 * ------------- */

export type UserTaskPriority = 'low' | 'medium' | 'high';

export interface TaskBody {
  /** required */
  title: string;
  /** optional */
  notes: string | null;
  /** open-ended by default (no due date required) */
  dueDate: isoDateTime | null;
  /** default false server-side on create */
  isCompleted: boolean;
  /** mapped to your tags model by server; keep payload simple */
  tags: string[];
  /** reminders in your format */
  reminderTriggers: ReminderTrigger[];
  /** optional parent relation */
  parentEventId: string | null; // UUID-string
  /** priority enum; maps to your UserTaskPriority(int) server-side */
  priority: UserTaskPriority;
}

export interface CreateTaskPayload extends BaseMutation {
  task: TaskBody;
}

export interface UpdateTaskPayload extends BaseMutation {
  taskId: string;            // UUID-string
  version: number;           // optimistic concurrency gate (server compares)
  patch: Partial<TaskBody>;  // any subset of fields
}

export interface DeleteTaskPayload extends BaseMutation {
  taskId: string;            // UUID-string
  version: number;           // optimistic concurrency gate
}

/* -----
 * EVENT
 * ----- */

export interface EventBody {
  /** required */
  title: string;
  /** required in your model */
  startDatetime: isoDateTime;
  /** optional in model but UI typically sets an end */
  endDatetime?: isoDateTime | null;
  notes?: string | null;
  location?: string | null;
  color?: EventColor | null;
  reminderTriggers?: ReminderTrigger[];
  /**
   * Recurrence:
   * - Omit entirely => non-recurring
   * - Provide => recurring; server sets is_recurring = true
   */
  recurrenceRule?: RecurrenceRuleBody | null;
}

/** How to apply an edit in a recurring series */
export type EditScope = 'single' | 'override' | 'this_and_future' | 'entire_series';

/** Create an event (single or recurring). */
export interface CreateEventPayload extends BaseMutation {
  event: EventBody;
}

/**
 * Update an event.
 * - version: base event version the client last saw (OCC gate)
 * - editScope: controls how recurrence is edited
 * - occurrenceDate: required when editScope === 'single' (ISO date-time of the instance)
 *   (server will create/update an EventOverride for that occurrence)
 */
export interface UpdateEventPayload extends BaseMutation {
  eventId: string; // UUID-string
  version: number; // optimistic concurrency for the base event
  editScope: EditScope;
  occurrenceDat?: isoDateTime; // required for 'single'
  patch: Partial<EventBody>;
}

/**
 * Delete/cancel an event (or an occurrence / future series).
 * - For 'single': server should create an override { isCancelled: true } at occurrenceDate.
 * - For 'this_and_future': server truncates the rule and (optionally) moves future overrides.
 * - For 'entire_series': server soft-deletes the base event (+ rules + overrides).
 */
export interface DeleteEventPayload extends BaseMutation {
  eventId: string; // UUID-string
  version: number; // optimistic concurrency gate on base event
  editScope: EditScope;
  occurrenceDate: isoDateTime; // required for 'single'
}

/* ----------------
 * Read-only helpers
 * ---------------- */

export interface GetAgendaInput {
  dateRange: 'today' | 'tomorrow' | 'week' | 'custom';
  start: isoDateTime; // when custom
  end: isoDateTime;   // when custom
}

/** Planning (read-only proposal, no writes) */
export interface PlanWeekInput {
  startDate: isoDate;                // e.g., "2025-08-18"
  objectives: string[];
  constraints: Record<string, unknown>;
  /** free users may use 'day'; pro can use 'week' */
  horizon: 'day' | 'week';
}

/** Proposed changes for preview/confirmation */
export type EntityKind = 'event' | 'task';

export interface ProposedChange {
  entity: EntityKind;                 // 'event' | 'task'
  action: 'create' | 'update' | 'delete';
  summary: string;                    // human-readable bullet
  targetId: string;                  // UUID-string (for update/delete)
  /** For event recurrence-aware previews */
  editScope: EditScope;
  occurrenceDate: isoDateTime;
  /** Minimal shape used to render client-side diffs */
  patch: Partial<EventBody> | Partial<TaskBody>;
}

export interface ProposedPlan {
  startDate: isoDate;
  horizon: 'day' | 'week';
  items: ProposedChange[];            // capped server-side (e.g., <= 200)
}

/* -----------------------------
 * JSON Schemas (draft-07 style)
 * ----------------------------- */

export const reminderTriggerSchema = {
  $id: 'ReminderTrigger',
  type: 'object',
  additionalProperties: false,
  // STRICT: include *every* key in properties
  required: ['timeBeforeDue', 'message'],
  properties: {
    timeBeforeDue: { type: 'integer', minimum: 0 },
    // required + nullable => caller must include the key, value may be null
    message: { anyOf: [{ type: 'string', maxLength: 200 }, { type: 'null' }] }
  }
} as const;

export const recurrenceRuleSchema = {
  $id: 'RecurrenceRuleBody',
  type: 'object',
  additionalProperties: false,
  required: ['freq', 'interval', 'byWeekday', 'byMonthday', 'byMonth', 'until', 'count'],
  properties: {
    freq: { type: 'string', enum: ['daily', 'weekly', 'monthly', 'yearly'] },
    interval: { type: 'integer', minimum: 1, default: 1 },

    byWeekday: {
      anyOf: [
        {
          type: 'array',
          items: { type: 'integer', minimum: 1, maximum: 7 }, // 1=Sun..7=Sat
          maxItems: 7,
        },
        { type: 'null' },
      ],
    },

    byMonthday: {
      anyOf: [
        {
          type: 'array',
          items: { type: 'integer', minimum: 1, maximum: 31 },
          maxItems: 31,
        },
        { type: 'null' },
      ],
    },

    byMonth: {
      anyOf: [
        {
          type: 'array',
          items: { type: 'integer', minimum: 1, maximum: 12 },
          maxItems: 12,
        },
        { type: 'null' },
      ],
    },

    until: { anyOf: [{ type: 'string', format: 'date-time' }, { type: 'null' }] },
    count: { anyOf: [{ type: 'integer', minimum: 1 }, { type: 'null' }] },
  },
} as const;

export const eventColorSchema = {
  $id: 'EventColor',
  enum: [
    "#FFD966","#AEEAF9","#F6B9C1","#D1F7C4","#D6C3FF",
    "#A8F6FF","#B8FFC9","#A9DFE6","#FFF3B0","#FFB3B3",
    "#C3C8FF","#D5E3FF","#FFD1DC","#FFDAC1","#F6E2B3"
  ]
} as const;

export const eventBodySchema = {
  $id: 'EventBody',
  type: 'object',
  additionalProperties: false,
  required: ['title', 'startDatetime','endDatetime','notes','location','color','reminderTriggers','recurrenceRule'],
  properties: {
    title: { type: 'string', minLength: 1, maxLength: 200 },
    startDatetime: isoDateTime,
    endDatetime: { anyOf: [ isoDateTime, { type: 'null' } ] },
    notes: { anyOf: [{ type: 'string', maxLength: 2000 }, { type: 'null' }] },
    location: { anyOf: [{ type: 'string', maxLength: 200 }, { type: 'null' }] },
    color: { anyOf: [eventColorSchema, { type: 'null' }] },
    reminderTriggers: { type: 'array', items: reminderTriggerSchema, maxItems: 5 },
    recurrenceRule: { anyOf: [recurrenceRuleSchema, { type: 'null' }] }
  }
} as const;

/** Patch schema for EventBody: same fields, all optional */
export const eventPatchSchema = {
  $id: 'EventPatch',
  type: 'object',
  additionalProperties: false,
  required: ['title', 'startDatetime','endDatetime','notes','location','color','reminderTriggers','recurrenceRule'],
  properties: {
    title: { type: 'string', minLength: 1, maxLength: 200 },
    startDatetime: isoDateTime,
    endDatetime: { anyOf: [isoDateTime, { type: 'null' }] },
    notes: { anyOf: [{ type: 'string', maxLength: 2000 }, { type: 'null' }] },
    location: { anyOf: [{ type: 'string', maxLength: 200 }, { type: 'null' }] },
    color: { anyOf: [eventColorSchema, { type: 'null' }] },
    reminderTriggers: { type: 'array', items: reminderTriggerSchema, maxItems: 5 },
    recurrenceRule: { anyOf: [recurrenceRuleSchema, { type: 'null' }] }
  }
} as const;

export const taskBodySchema = {
  $id: 'TaskBody',
  type: 'object',
  additionalProperties: false,
  required: ['title', 'notes','dueDate','isCompleted','tags','reminderTriggers','parentEventId','priority'],
  properties: {
    title: { type: 'string', minLength: 1, maxLength: 200 },
    notes: { anyOf: [{ type: 'string', maxLength: 2000 }, { type: 'null' }] },
    dueDate: { anyOf: [isoDateTime, { type: 'null' }] },
    isCompleted: { type: 'boolean' },
    tags: { type: 'array', items: { type: 'string', minLength: 1 }, maxItems: 50 },
    reminderTriggers: { type: 'array', items: reminderTriggerSchema, maxItems: 5 },
    parentEventId: { anyOf: [{ type: 'string', minLength: 1 }, { type: 'null' }] },
    priority: { enum: ['low', 'medium', 'high'] }
  }
} as const;

/** Patch schema for TaskBody: same fields, all optional */
export const taskPatchSchema = {
  $id: 'TaskPatch',
  type: 'object',
  additionalProperties: false,
  required: ['title', 'notes','dueDate','isCompleted','tags','reminderTriggers','parentEventId','priority'],
  properties: {
    title: { type: 'string', minLength: 1, maxLength: 200 },
    notes: { anyOf: [{ type: 'string', maxLength: 2000 }, { type: 'null' }] },
    dueDate: { anyOf: [isoDateTime, { type: 'null' }] },
    isCompleted: { type: 'boolean' },
    tags: { type: 'array', items: { type: 'string', minLength: 1 }, maxItems: 50 },
    reminderTriggers: { type: 'array', items: reminderTriggerSchema, maxItems: 5 },
    parentEventId: { anyOf: [{ type: 'string', minLength: 1 }, { type: 'null' }] },
    priority: { enum: ['low', 'medium', 'high'] }
  }
} as const;

export const baseMutationSchema = {
  $id: 'BaseMutation',
  type: 'object',
  required: ['intent', 'idempotencyKey', 'reason', 'dryRun'],
  properties: {
    intent: { type: 'string', enum: ['create','update','delete'] },
    idempotencyKey: { type: 'string', minLength: 8, maxLength: 100 },
    reason: { type: 'string', minLength: 3, maxLength: 500 },
    dryRun: { type: 'boolean' }
  }
} as const;

export const createTaskSchema = {
  $id: 'CreateTaskPayload',
  type: 'object',
  additionalProperties: false,
  required: [...baseMutationSchema.required, 'task'],
  properties: {
    ...baseMutationSchema.properties,
    task: { $ref: 'TaskBody' },
  }
} as const;

export const updateTaskSchema = {
  $id: 'UpdateTaskPayload',
  allOf: [
    { $ref: 'BaseMutation' },
    {
      type: 'object',
      additionalProperties: false,
      required: ['taskId','version','patch'],
      properties: {
        taskId: { type: 'string', minLength: 1 },
        version: { type: 'integer', minimum: 0 },
        patch: { $ref: 'TaskPatch' }
      }
    }
  ]
} as const;

export const deleteTaskSchema = {
  $id: 'DeleteTaskPayload',
  allOf: [
    { $ref: 'BaseMutation' },
    {
      type: 'object',
      additionalProperties: false,
      required: ['taskId','version'],
      properties: {
        taskId: { type: 'string', minLength: 1 },
        version: { type: 'integer', minimum: 0 }
      }
    }
  ]
} as const;

export const createEventSchema = {
  $id: 'CreateEventPayload',
  type: 'object',
  additionalProperties: false,
  required: [...baseMutationSchema.required, 'event'],
  properties: {
    ...baseMutationSchema.properties,
    event: { $ref: 'EventBody' },
  }
} as const;

// export const createEventSchema = {
//   $id: 'CreateEventPayload',
//   allOf: [
//     { $ref: 'BaseMutation' },
//     {
//       type: 'object',
//       additionalProperties: false,
//       required: ['event'],
//       properties: { event: { $ref: 'EventBody' } }
//     }
//   ]
// } as const;

export const updateEventSchema = {
  $id: 'UpdateEventPayload',
  allOf: [
    { $ref: 'BaseMutation' },
    {
      type: 'object',
      additionalProperties: false,
      required: ['eventId', 'version', 'editScope', 'occurrenceDate', 'patch'],
      properties: {
        eventId: { type: 'string', minLength: 1 },        // consider: format: 'uuid'
        version: { type: 'integer', minimum: 0 },
        editScope: { enum: ['single','override','this_and_future','entire_series'] },
        occurrenceDate: { anyOf: [ isoDateTime, { type: 'null' } ] },                      // required only for some scopes below
        patch: { $ref: 'EventPatch' }
      },
      allOf: [
        // Require occurrenceDate for override
        {
          if: { properties: { editScope: { const: 'override' } } },
          then: { required: ['occurrenceDate'] }
        },
        // Require occurrenceDate for this_and_future
        {
          if: { properties: { editScope: { const: 'this_and_future' } } },
          then: { required: ['occurrenceDate'] }
        },
        // Forbid occurrenceDate for single
        {
          if: { properties: { editScope: { const: 'single' } } },
          then: { properties: { occurrenceDate: false } }
        },
        // Forbid occurrenceDate for entire_series
        {
          if: { properties: { editScope: { const: 'entire_series' } } },
          then: { properties: { occurrenceDate: false } }
        }
      ]
    }
  ]
} as const;


export const deleteEventSchema = {
  $id: 'DeleteEventPayload',
  allOf: [
    { $ref: 'BaseMutation' },
    {
      type: 'object',
      additionalProperties: false,
      required: ['eventId', 'version', 'editScope', 'occurrenceDate'],
      properties: {
        eventId: { type: 'string', minLength: 1 },       // consider: format: 'uuid'
        version: { type: 'integer', minimum: 0 },
        editScope: { enum: ['single','override','this_and_future','entire_series'] },
        occurrenceDate: { anyOf: [ isoDateTime, { type: 'null' } ] }                      // required only for some scopes below
      },
      allOf: [
        // Require occurrenceDate for override
        {
          if: { properties: { editScope: { const: 'override' } } },
          then: { required: ['occurrenceDate'] }
        },
        // Require occurrenceDate for this_and_future
        {
          if: { properties: { editScope: { const: 'this_and_future' } } },
          then: { required: ['occurrenceDate'] }
        },
        // Forbid occurrenceDate for single
        {
          if: { properties: { editScope: { const: 'single' } } },
          then: { properties: { occurrenceDate: false } }
        },
        // Forbid occurrenceDate for entire_series
        {
          if: { properties: { editScope: { const: 'entire_series' } } },
          then: { properties: { occurrenceDate: false } }
        }
      ]
    }
  ]
} as const;


export const getAgendaSchema = {
  $id: 'GetAgendaInput',
  type: 'object',
  additionalProperties: false,
  required: ['dateRange', 'start', 'end'],
  properties: {
    dateRange: { enum: ['today','tomorrow','week','custom'] },
    start: isoDateTime,
    end: isoDateTime
  },
  allOf: [
    {
      if: { properties: { dateRange: { const: 'custom' } } },
      then: { required: ['start','end'] }
    }
  ]
} as const;

export const planWeekInputSchema = {
  $id: 'PlanWeekInput',
  type: 'object',
  additionalProperties: false,
  required: ['startDate', 'objectives', 'constraints', 'horizon'],
  properties: {
    startDate: isoDate,
    objectives: { type: 'array', items: { type: 'string' }, maxItems: 20 },
    constraints: { type: 'object', additionalProperties: true },
    horizon: { enum: ['day','week'], default: 'week' }
  }
} as const;

export const proposedChangeSchema = {
  $id: 'ProposedChange',
  type: 'object',
  additionalProperties: false,
  required: ['entity','action','summary', 'targetId', 'editScope', 'occurrenceDate', 'patch'],
  properties: {
    entity: { enum: ['event','task'] },
    action: { enum: ['create','update','delete'] },
    summary: { type: 'string', minLength: 3, maxLength: 500 },
    targetId: { type: 'string' },
    editScope: { enum: ['single','override','this_and_future','entire_series'] },
    occurrenceDate: isoDateTime,
    patch: {
      anyOf: [{ $ref: 'EventPatch' }, { $ref: 'TaskPatch' }]
    }
  }
} as const;

export const proposedPlanSchema = {
  $id: 'ProposedPlan',
  type: 'object',
  additionalProperties: false,
  required: ['startDate','horizon','items'],
  properties: {
    startDate: isoDate,
    horizon: { enum: ['day','week'] },
    items: { type: 'array', items: { $ref: 'ProposedChange' }, maxItems: 200 }
  }
} as const;

/**
 * Registry for a JSON-schema validator (e.g., Ajv) to resolve $refs.
 * Import this in `validate.ts` and register all schemas before compiling.
 */
export const schemaRegistry = {
  ReminderTrigger: reminderTriggerSchema,
  RecurrenceRuleBody: recurrenceRuleSchema,
  EventColor: eventColorSchema,
  EventBody: eventBodySchema,
  EventPatch: eventPatchSchema,
  TaskBody: taskBodySchema,
  TaskPatch: taskPatchSchema,
  BaseMutation: baseMutationSchema,
  CreateTaskPayload: createTaskSchema,
  UpdateTaskPayload: updateTaskSchema,
  DeleteTaskPayload: deleteTaskSchema,
  CreateEventPayload: createEventSchema,
  UpdateEventPayload: updateEventSchema,
  DeleteEventPayload: deleteEventSchema,
  GetAgendaInput: getAgendaSchema,
  PlanWeekInput: planWeekInputSchema,
  ProposedChange: proposedChangeSchema,
  ProposedPlan: proposedPlanSchema
} as const;
