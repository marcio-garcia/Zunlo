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
for (const [_k, schema] of Object.entries(schemaRegistry)) {
  ajv.addSchema(schema);
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

