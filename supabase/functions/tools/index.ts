// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

// Purpose: route tool calls by path, validate payloads, and (later phases) perform DB writes.
// Phase 1 returns "Not Implemented" after validating the payload shape.

import { Hono } from "jsr:@hono/hono";
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { withAuth, type AuthContext } from "../_shared/guard.ts";
import { validate } from "../_shared/validate.ts";
import {
  // Schemas & types
  createTaskSchema, updateTaskSchema, deleteTaskSchema,
  createEventSchema, updateEventSchema, deleteEventSchema,
  getAgendaSchema, planWeekInputSchema,
  type CreateTaskPayload, type UpdateTaskPayload, type DeleteTaskPayload,
  type CreateEventPayload, type UpdateEventPayload, type DeleteEventPayload,
  type GetAgendaInput, type PlanWeekInput, type EventBody, type TaskBody
} from "../_shared/schemas.ts";
import { getIdempotentResult, saveIdempotentResult } from "../_shared/idempotency.ts";
import {
  assertMutationAllowed,
  recordMutation,
  jsonErr,
  jsonOk,
} from "../_shared/entitlements.ts";

const app = new Hono({ strict: false }).basePath("/tools");

// --- service-role client (for idempotency + usage accounting only) ---
const SERVICE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const service = createClient(SERVICE_URL, SERVICE_KEY);

// --- helpers ---
const nowISO = () => new Date().toISOString();
const priorityToInt = (p?: string) => (p === "high" ? 2 : p === "medium" ? 1 : 0);
async function readJson<T = unknown>(c: any): Promise<T | Response> {
  try {
    return (await c.req.json()) as T;
  } catch {
    return c.json({ error: "Bad JSON" }, 400);
  }
};
// Auth middleware: attaches { supabase, userId, token } to the context
const authMiddleware = async (c: any, next: Function) => {
  const auth = await withAuth(c.req);
  if (auth instanceof Response) return auth;  // early return on 401/500
  c.set("auth", auth);
  await next();
};

console.log("[boot] ENV", {
  hasURL: !!Deno.env.get("SUPABASE_URL"),
  hasAnon: !!Deno.env.get("SUPABASE_ANON_KEY"),
  // don’t log keys themselves
});

console.log("[boot] basePath=/tools");

// Simple request logger with timing
app.use("*", async (c, next) => {
  const rid = crypto.randomUUID();
  (c as any).rid = rid; // stash if you want it later
  const t0 = performance.now();
  const url = new URL(c.req.url);
  try {
    await next();
  } finally {
    const ms = (performance.now() - t0).toFixed(1);
    console.log(`[${c.req.method} ${new URL(c.req.url).pathname}][${rid}] status=${c.res.status} ms=${ms}`);
    console.log(`[POST ${url.pathname}] status=${c.res.status}`);
  }
});

app.onError((err, c) => {
  console.error("[onError]", err);
  return c.json({ error: "Internal Error", message: err?.message ?? String(err) }, 500);
});

app.notFound((c) => {
  const path = new URL(c.req.url).pathname;
  console.warn("[notFound]", path);
  return c.json({ error: "Not Found", path }, 404);
});

/* -------------------
 * Read-only endpoints
 * ------------------- */

app.post("/getAgenda", authMiddleware, async (c) => {
  const rid = c.get("rid");
  const body = await readJson(c);
  if (body instanceof Response) return body;

  const valid = validate(getAgendaSchema, body);
  if (valid instanceof Response) {
    console.warn(`[tools/getAgenda][${rid}] validation failed`);
    return valid;
  }
  return jsonOk({ ok: true, preview: true });
});

app.post("/planWeek", authMiddleware, async (c) => {
  const rid = c.get("rid");
  const body = await readJson(c);
  if (body instanceof Response) return body;

  const valid = validate(planWeekInputSchema, body);
  if (valid instanceof Response) {
    console.warn(`[tools/planWeek][${rid}] validation failed`);
    return valid;
  }
  return jsonOk({ ok: true, preview: true });
});

/* ---------------
 * Task mutations
 * --------------- */

app.post("/createTask", authMiddleware, async (c) => {
  const rid = c.get("rid");
  const { supabase, userId } = c.get("auth") as AuthContext;

  const path = "tools/createTask";
  const body = await readJson(c);
  if (body instanceof Response) return body;

  console.log(`[${path}][${rid}] start userId=${userId} bodyKeys=${Object.keys(body ?? {})}`);

  try {
    const payload = validate<CreateTaskPayload>(createTaskSchema, body);
    if (payload instanceof Response) {
      console.warn(`[${path}][${rid}] validation failed`);
      return payload;
    }

    console.log(
      `[${path}][${rid}] idempotencyKey=${payload.idempotencyKey} title="${payload.task?.title ?? "<nil>"}" priority=${payload.task?.priority}`
    );

    // Paywall / usage gate
    try {
      await assertMutationAllowed(service, userId);
    } catch (e) {
      console.warn(`[${path}][${rid}] assertMutationAllowed denied:`, e?.message ?? e);
      return e instanceof Response ? e : jsonErr("Forbidden", 403);
    }

    // Idempotency cache
    const cached = await getIdempotentResult(service, userId, payload.idempotencyKey);
    if (cached) {
      console.log(`[${path}][${rid}] idempotency cache hit`);
      return jsonOk(cached);
    }

    // Map request → DB row (user client w/ RLS)
    const task = payload.task as TaskBody;
    const insertBody: any = {
      user_id: userId,
      title: task.title,
      notes: task.notes ?? null,
      is_completed: task.isCompleted ?? false,
      due_date: task.dueDate ?? null,
      priority: priorityToInt(task.priority),
      parent_event_id: task.parentEventId ?? null,
      tags: task.tags ?? [],
      reminder_triggers: task.reminderTriggers ?? [],
      created_at: nowISO(),
      updated_at: nowISO(),
      version: 1,
    };

    // Log just a summary of what we’ll write
    console.log(`[${path}][${rid}] supabase.hasFrom=${typeof (supabase as any)?.from === "function"}`);
    console.log(`[${path}][${rid}] inserting`, {
        title: insertBody.title,
        due_date: insertBody.due_date,
        priority: insertBody.priority,
        tags_len: Array.isArray(insertBody.tags) ? insertBody.tags.length : null,
        reminders_len: Array.isArray(insertBody.reminder_triggers) ? insertBody.reminder_triggers.length : null,
      },
    );

    const tIns = performance.now();
    const { data, error } = await supabase.from("tasks").insert(insertBody).select("*").single();
    console.log(`[${path}][${rid}] supabase.insert ms=${(performance.now() - tIns).toFixed(1)}`);

    if (error) {
      console.error(`[${path}][${rid}] db error`, {
        code: error.code, message: error.message, details: error.details, hint: error.hint,
      });
      return jsonErr(error.message, 400);
    }

    const result = { ok: true, task: data };

    const tMeta = performance.now();
    await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
    await recordMutation(service, userId);
    console.log(`[${path}][${rid}] success ms=${(performance.now() - tMeta).toFixed(1)}`);

    return jsonOk(result);
  } catch (e) {
    // Anything that throws will land here (e.g., coding errors, unexpected shapes)
    console.error(`[${path}][${rid}] unhandled error`, e);
    return jsonErr("Internal error", 500);
  }
});

app.post("/updateTask", authMiddleware, async (c) => {
  const rid = c.get("rid");
  const { supabase, userId } = c.get("auth") as AuthContext;

  const path = "tools/updateTask";
  const body = await readJson(c);
  if (body instanceof Response) return body;

  const payload = validate<UpdateTaskPayload>(updateTaskSchema, body);
  if (payload instanceof Response) return payload;

  try { await assertMutationAllowed(service, userId); }
  catch (e) { return e instanceof Response ? e : jsonErr("Forbidden", 403); }

  const cached = await getIdempotentResult(service, userId, payload.idempotencyKey);
  if (cached) return jsonOk(cached);

  const p = payload.patch as Partial<TaskBody>;
  const patch: any = {
    updated_at: nowISO(),
    version: payload.version + 1
  };
  if (p.title !== undefined) patch.title = p.title;
  if (p.notes !== undefined) patch.notes = p.notes;
  if (p.isCompleted !== undefined) patch.is_completed = p.isCompleted;
  if (p.dueDate !== undefined) patch.due_date = p.dueDate;
  if (p.priority !== undefined) patch.priority = priorityToInt(p.priority);
  if (p.parentEventId !== undefined) patch.parent_event_id = p.parentEventId;
  if (p.tags !== undefined) patch.tags = p.tags;
  if (p.reminderTriggers !== undefined) patch.reminder_triggers = p.reminderTriggers;

  const { data, error } = await supabase
    .from("tasks")
    .update(patch)
    .eq("id", payload.taskId)
    .eq("user_id", userId)
    .eq("version", payload.version) // OCC gate
    .select("*")
    .maybeSingle();

  if (error) return jsonErr(error.message, 400);
  if (!data) return jsonErr("Version mismatch", 409, "CONFLICT" as any);

  const result = { ok: true, task: data };
  await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
  await recordMutation(service, userId);
  return jsonOk(result);
});

app.post("/deleteTask", authMiddleware, async (c) => {
  const rid = c.get("rid");
  const { supabase, userId } = c.get("auth") as AuthContext;

  const path = "tools/deleteTask";
  const body = await readJson(c);
  if (body instanceof Response) return body;

  const payload = validate<DeleteTaskPayload>(deleteTaskSchema, body);
  if (payload instanceof Response) return payload;

  try { await assertMutationAllowed(service, userId); }
  catch (e) { return e instanceof Response ? e : jsonErr("Forbidden", 403); }

  const cached = await getIdempotentResult(service, userId, payload.idempotencyKey);
  if (cached) return jsonOk(cached);

  const patch = {
    deleted_at: nowISO(),
    updated_at: nowISO(),
    version: payload.version + 1
  };

  const { data, error } = await supabase
    .from("tasks")
    .update(patch)
    .eq("id", payload.taskId)
    .eq("user_id", userId)
    .eq("version", payload.version)
    .select("*")
    .maybeSingle();

  if (error) return jsonErr(error.message, 400);
  if (!data) return jsonErr("Version mismatch", 409, "CONFLICT" as any);

  const result = { ok: true, task: data };
  await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
  await recordMutation(service, userId);
  return jsonOk(result);
});

/* ----------------
 * Event mutations
 * ---------------- */

app.post("/createEvent", authMiddleware, async (c) => {
  const rid = c.get("rid");
  const { supabase, userId } = c.get("auth") as AuthContext;

  const path = "tools/createEvent";
  const body = await readJson(c);
  if (body instanceof Response) return body;

  console.log(
    "Body: ",
    JSON.stringify(body, null, 2)
  );

  const payload = validate<CreateEventPayload>(createEventSchema, body);
  if (payload instanceof Response) return payload;

  console.log(
    "Payload: ",
    JSON.stringify(payload, null, 2)
  );

  try { await assertMutationAllowed(service, userId); }
  catch (e) { return e instanceof Response ? e : jsonErr("Forbidden", 403); }

  const cached = await getIdempotentResult(service, userId, payload.idempotencyKey);
  if (cached) return jsonOk(cached);

  const e = payload.event as EventBody;

  // Insert base event
  const base = {
    id: crypto.randomUUID(),
    user_id: userId,
    title: e.title,
    notes: e.notes ?? null,
    start_datetime: e.startDatetime,
    end_datetime: e.endDatetime ?? null,
    is_recurring: !!e.recurrenceRule,
    location: e.location ?? null,
    color: e.color ?? null,
    reminder_triggers: e.reminderTriggers ?? [],
    created_at: nowISO(),
    updated_at: nowISO(),
    version: 1,
    deleted_at: null
  };

  const { data: eventRow, error: eventErr } = await supabase
    .from("events")
    .insert(base)
    .select("*")
    .single();

  if (eventErr) return jsonErr(eventErr.message, 400);

  let ruleRow: any = null;

  // Optional recurrence rule
  if (e.recurrenceRule) {
    const r = e.recurrenceRule;
    const insertRule = {
      id: crypto.randomUUID(),
      event_id: eventRow.id,
      freq: r.freq,
      interval: r.interval ?? 1,
      by_weekday: r.byWeekday ?? null,
      by_monthday: r.byMonthday ?? null,
      by_month: r.byMonth ?? null,
      until: r.until ?? null,
      count: r.count ?? null,
      created_at: nowISO(),
      updated_at: nowISO(),
      version: 1,
      deleted_at: null
    };

    const { data, error } = await supabase
      .from("recurrence_rules")
      .insert(insertRule)
      .select("*")
      .single();
    if (error) return jsonErr(error.message, 400);
    ruleRow = data;
  }

  const result = { ok: true, event: eventRow, recurrence_rule: ruleRow };
  await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
  await recordMutation(service, userId);
  return jsonOk(result);
});

app.post("/updateEvent", authMiddleware, async (c) => {
    const rid = c.get("rid");
  const { supabase, userId } = c.get("auth") as AuthContext;

  const path = "tools/updateEvent";
  const body = await readJson(c);
  if (body instanceof Response) return body;

  const payload = validate<UpdateEventPayload>(updateEventSchema, body);
  if (payload instanceof Response) return payload;

  try { await assertMutationAllowed(service, userId); }
  catch (e) { return e instanceof Response ? e : jsonErr("Forbidden", 403); }

  const cached = await getIdempotentResult(service, userId, payload.idempotencyKey);
  if (cached) return jsonOk(cached);

  // Load event to enforce scope
  const { data: ev, error: evErr } = await supabase
    .from("events")
    .select("id, user_id, is_recurring, version")
    .eq("id", payload.eventId)
    .eq("user_id", userId)
    .maybeSingle();
  if (evErr) return jsonErr(evErr.message, 400);
  if (!ev) return jsonErr("Event not found", 404);

  const p = payload.patch as Partial<EventBody>;

  switch (payload.editScope) {
    case "single": {
      if (ev.is_recurring) return jsonErr("Use editScope=override for a single occurrence of a recurring event.", 400);
      const patch: any = { updated_at: nowISO(), version: payload.version + 1 };
      if (p.title !== undefined) patch.title = p.title;
      if (p.notes !== undefined) patch.notes = p.notes;
      if (p.start_datetime !== undefined) patch.start_datetime = p.start_datetime;
      if (p.end_datetime !== undefined) patch.end_datetime = p.end_datetime;
      if (p.location !== undefined) patch.location = p.location;
      if (p.color !== undefined) patch.color = p.color;
      if (p.reminder_triggers !== undefined) patch.reminder_triggers = p.reminder_triggers;

      const { data, error } = await supabase
        .from("events")
        .update(patch)
        .eq("id", payload.eventId)
        .eq("user_id", userId)
        .eq("version", payload.version)
        .select("*")
        .maybeSingle();
      if (error) return jsonErr(error.message, 400);
      if (!data) return jsonErr("Version mismatch", 409, "CONFLICT" as any);

      const result = { ok: true, event: data };
      await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
      await recordMutation(service, userId);
      return jsonOk(result);
    }

    case "override": {
      if (!payload.occurrenceDate) return jsonErr("occurrenceDate required", 400);
      if (!ev.is_recurring) return jsonErr("Cannot override a non-recurring event. Use editScope=single.", 400);

      // Upsert override
      const { data: existing } = await supabase
        .from("event_overrides")
        .select("id, version")
        .eq("event_id", payload.eventId)
        .eq("occurrence_date", payload.occurrenceDate)
        .maybeSingle();

      const overridePatch: any = { updated_at: nowISO() };
      if (p.title !== undefined) overridePatch.overridden_title = p.title;
      if (p.start_datetime !== undefined) overridePatch.overridden_start_date = p.start_datetime;
      if (p.end_datetime !== undefined) overridePatch.overridden_end_date = p.end_datetime;
      if (p.location !== undefined) overridePatch.overridden_location = p.location;
      if (p.notes !== undefined) overridePatch.notes = p.notes;

      let overrideRow: any;
      if (existing) {
        const { data, error } = await supabase
          .from("event_overrides")
          .update({ ...overridePatch, version: existing.version + 1 })
          .eq("id", existing.id)
          .select("*")
          .single();
        if (error) return jsonErr(error.message, 400);
        overrideRow = data;
      } else {
        const { data, error } = await supabase
          .from("event_overrides")
          .insert({
            id: crypto.randomUUID(),
            event_id: payload.eventId,
            occurrence_date: payload.occurrenceDate,
            overridden_title: overridePatch.overridden_title ?? null,
            overridden_start_date: overridePatch.overridden_start_date ?? null,
            overridden_end_date: overridePatch.overridden_end_date ?? null,
            overridden_location: overridePatch.overridden_location ?? null,
            is_cancelled: false,
            notes: overridePatch.notes ?? null,
            color: null,
            created_at: nowISO(),
            updated_at: nowISO(),
            version: 1,
            deleted_at: null
          })
          .select("*")
          .single();
        if (error) return jsonErr(error.message, 400);
        overrideRow = data;
      }

      const result = { ok: true, override: overrideRow };
      await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
      await recordMutation(service, userId);
      return jsonOk(result);
    }

    case "this_and_future": {
      if (!payload.occurrenceDate) return jsonErr("occurrenceDate required", 400);

      try {
        const { data, error } = await supabase
          .rpc("event_split_this_and_future", {
            p_user_id: userId,
            p_event_id: payload.eventId,
            p_base_version: payload.version,
            p_split_at: payload.occurrenceDate,
            p_patch: payload.patch as any, // already snake_case EventBody PATCH
          });

        if (error) return jsonErr(error.message, 400);
        if (!data) return jsonErr("Split failed", 400);

        // data is { event: jsonb, recurrence_rule: jsonb }
        const res = { ok: true, event: data.event, recurrence_rule: data.recurrence_rule };

        await saveIdempotentResult(service, userId, payload.idempotencyKey, res);
        await recordMutation(service, userId);
        return jsonOk(res);
      } catch (e: any) {
        return jsonErr(e?.message ?? "Split failed", 400);
      }
    }

    case "entire_series": {
      const patch: any = { updated_at: nowISO(), version: payload.version + 1 };
      if (p.title !== undefined) patch.title = p.title;
      if (p.notes !== undefined) patch.notes = p.notes;
      if (p.start_datetime !== undefined) patch.start_datetime = p.start_datetime;
      if (p.end_datetime !== undefined) patch.end_datetime = p.end_datetime;
      if (p.location !== undefined) patch.location = p.location;
      if (p.color !== undefined) patch.color = p.color;
      if (p.reminder_triggers !== undefined) patch.reminder_triggers = p.reminder_triggers;

      const { data: updatedEvent, error: updErr } = await supabase
        .from("events")
        .update(patch)
        .eq("id", payload.eventId)
        .eq("user_id", userId)
        .eq("version", payload.version)
        .select("*")
        .maybeSingle();
      if (updErr) return jsonErr(updErr.message, 400);
      if (!updatedEvent) return jsonErr("Version mismatch", 409, "CONFLICT" as any);

      const result = { ok: true, event: updatedEvent };
      await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
      await recordMutation(service, userId);
      return jsonOk(result);
    }
  }
});

app.post("/deleteEvent", authMiddleware, async (c) => {
    const rid = c.get("rid");
  const { supabase, userId } = c.get("auth") as AuthContext;

  const path = "tools/deleteEvent";
  const body = await readJson(c);
  if (body instanceof Response) return body;

  const payload = validate<DeleteEventPayload>(deleteEventSchema, body);
  if (payload instanceof Response) return payload;

  try { await assertMutationAllowed(service, userId); }
  catch (e) { return e instanceof Response ? e : jsonErr("Forbidden", 403); }

  const cached = await getIdempotentResult(service, userId, payload.idempotencyKey);
  if (cached) return jsonOk(cached);

  if (payload.editScope === "this_and_future") {
    if (!payload.occurrenceDate) return jsonErr("occurrenceDate required", 400);

    try {
      const { data, error } = await supabase
        .rpc("event_truncate_series_from", {
          p_user_id: userId,
          p_event_id: payload.eventId,
          p_base_version: payload.version,
          p_split_at: payload.occurrenceDate,
        });

      if (error) return jsonErr(error.message, 400);
      if (!data) return jsonErr("Truncate failed", 400);

      const res = { ok: true, event: data.event, recurrence_rule: data.recurrence_rule };
      await saveIdempotentResult(service, userId, payload.idempotencyKey, res);
      await recordMutation(service, userId);
      return jsonOk(res);
    } catch (e: any) {
      return jsonErr(e?.message ?? "Truncate failed", 400);
    }
  }

  if (payload.editScope === "override") {
    if (!payload.occurrenceDate) return jsonErr("occurrenceDate required", 400);

    // Upsert override with is_cancelled = true
    const { data: existing } = await supabase
      .from("event_overrides")
      .select("id, version")
      .eq("event_id", payload.eventId)
      .eq("occurrence_date", payload.occurrenceDate)
      .maybeSingle();

    let overrideRow: any;
    if (existing) {
      const { data, error } = await supabase
        .from("event_overrides")
        .update({ is_cancelled: true, updated_at: nowISO(), version: existing.version + 1 })
        .eq("id", existing.id)
        .select("*")
        .single();
      if (error) return jsonErr(error.message, 400);
      overrideRow = data;
    } else {
      const { data, error } = await supabase
        .from("event_overrides")
        .insert({
          id: crypto.randomUUID(),
          event_id: payload.eventId,
          occurrence_date: payload.occurrenceDate,
          overridden_title: null,
          overridden_start_date: null,
          overridden_end_date: null,
          overridden_location: null,
          is_cancelled: true,
          notes: null,
          color: null,
          created_at: nowISO(),
          updated_at: nowISO(),
          version: 1,
          deleted_at: null
        })
        .select("*")
        .single();
      if (error) return jsonErr(error.message, 400);
      overrideRow = data;
    }

    const result = { ok: true, override: overrideRow };
    await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
    await recordMutation(service, userId);
    return jsonOk(result);
  }

  // entire_series or single (non-recurring) -> soft delete base row
  const { data: eventRow, error } = await supabase
    .from("events")
    .update({ deleted_at: nowISO(), updated_at: nowISO(), version: payload.version + 1 })
    .eq("id", payload.eventId)
    .eq("user_id", userId)
    .eq("version", payload.version)
    .select("*")
    .maybeSingle();

  if (error) return jsonErr(error.message, 400);
  if (!eventRow) return jsonErr("Version mismatch", 409, "CONFLICT" as any);

  const result = { ok: true, event: eventRow };
  await saveIdempotentResult(service, userId, payload.idempotencyKey, result);
  await recordMutation(service, userId);
  return jsonOk(result);
});

/* ---- server ---- */
Deno.serve(app.fetch);
