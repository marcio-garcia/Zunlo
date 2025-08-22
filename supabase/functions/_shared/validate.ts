// Single responsibility: Validate JSON payloads against the Phase 0 schemas.

import Ajv from "https://esm.sh/ajv@8.12.0";
import addFormats from "https://esm.sh/ajv-formats@3.0.1";
import {
  schemaRegistry,
  // pull in any schemas you will validate in Phase 1
  createTaskSchema, updateTaskSchema, deleteTaskSchema,
  createEventSchema, updateEventSchema, deleteEventSchema,
  getAgendaSchema, planWeekInputSchema
} from "./schemas.ts";

// Create and prime a single Ajv instance for this function bundle.
const ajv = new Ajv({ allErrors: true, strict: true });
addFormats(ajv);

// Register all referenced schemas so $ref works.
for (const [name, schema] of Object.entries(schemaRegistry)) {
  try {
    // Optional: pre-check to log more readable errors
    const ok = ajv.validateSchema(schema);
    if (!ok) {
      console.error(`[AJV] Invalid schema '${name}' ($id=${(schema as any).$id ?? "n/a"})`, ajv.errors);
      throw new Error("Invalid schema");
    }
    ajv.addSchema(schema);
  } catch (e) {
    console.error(`[AJV] addSchema failed for '${name}' ($id=${(schema as any).$id ?? "n/a"})`, e);
    throw e;
  }
}

/** Validate and either return the typed value or a Response with 400 + errors. */
export function validate<T>(schema: object, value: unknown): T | Response {
  const validate = ajv.compile(schema);
  const ok = validate(value);
  if (ok) return value as T;

  // Return a small, readable error payload.
  return new Response(
    JSON.stringify({ error: "Invalid payload", details: validate.errors }),
    { status: 400, headers: { "Content-Type": "application/json" } }
  );
}