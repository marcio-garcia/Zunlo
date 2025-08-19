// Single responsibility: plan lookup, quota checks, and usage accounting.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { isoDateTime } from "./schemas.ts";

export type PlanTier = "free" | "pro";

export const PLAN_LIMITS: Record<PlanTier, {
  monthlyInputTokens: number | null;   // null = unlimited
  monthlyOutputTokens: number | null;  // null = unlimited
  allowMutation: boolean;
}> = {
  free: {
    monthlyInputTokens: 50_000,   // adjust
    monthlyOutputTokens: 50_000,  // adjust
    allowMutation: false,
  },
  pro: {
    monthlyInputTokens: null,
    monthlyOutputTokens: null,
    allowMutation: true,
  },
};

export type EntitlementErrorCode = "PAYWALL" | "QUOTA_EXCEEDED" | "NOT_IMPLEMENTED";

export function jsonErr(message: string, status = 400, code?: EntitlementErrorCode) {
  return new Response(JSON.stringify({ ok: false, code, message }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
export function jsonOk(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function monthWindowUTC(now = new Date()) {
  const y = now.getUTCFullYear();
  const m = now.getUTCMonth(); // 0-11
  const start = new Date(Date.UTC(y, m, 1, 0, 0, 0, 0));
  const end = new Date(Date.UTC(y, m + 1, 0, 23, 59, 59, 999)); // inclusive feel
  return {
    start,
    end,
    startDate: start.toISOString().slice(0, 10), // yyyy-mm-dd
    endDate: end.toISOString().slice(0, 10),
  };
}

export async function getPlanForUser(supabase: ReturnType<typeof createClient>, userId: string): Promise<PlanTier> {
  const { data, error } = await supabase
    .from("user_plans")
    .select("plan")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  return (data?.plan ?? "free") as PlanTier;
}

export async function getUsageForCurrentMonth(supabase: ReturnType<typeof createClient>, userId: string) {
  const win = monthWindowUTC();
  const { data, error } = await supabase
    .from("usage_counters")
    .select("*")
    .eq("user_id", userId)
    .eq("period_start", win.startDate)
    .maybeSingle();
  if (error) throw error;
  return { row: data, window: win };
}

async function upsertUsage(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  delta: { input?: number; output?: number; mutations?: number }
) {
  const { window } = await getUsageForCurrentMonth(supabase, userId);
  const incInput = delta.input ?? 0;
  const incOutput = delta.output ?? 0;
  const incMut = delta.mutations ?? 0;

  const { data, error } = await supabase.rpc("usage_increment", {
    p_user_id: userId,
    p_period_start: window.startDate,
    p_period_end: window.endDate,
    p_input_tokens: incInput,
    p_output_tokens: incOutput,
    p_mutation_count: incMut,
  });
  if (error) {
    // fallback if RPC not created yet:
    const { data: existing } = await supabase
      .from("usage_counters")
      .select("*")
      .eq("user_id", userId)
      .eq("period_start", window.startDate)
      .maybeSingle();

    if (!existing) {
      const { error: insErr } = await supabase.from("usage_counters").insert({
        user_id: userId,
        period_start: window.startDate,
        period_end: window.endDate,
        input_tokens: incInput,
        output_tokens: incOutput,
        mutation_count: incMut,
        updated_at: new Date().toISOString(),
      });
      if (insErr) throw insErr;
    } else {
      const { error: updErr } = await supabase.from("usage_counters").update({
        input_tokens: (existing.input_tokens ?? 0) + incInput,
        output_tokens: (existing.output_tokens ?? 0) + incOutput,
        mutation_count: (existing.mutation_count ?? 0) + incMut,
        updated_at: new Date().toISOString(),
      })
      .eq("user_id", userId)
      .eq("period_start", window.startDate);
      if (updErr) throw updErr;
    }
  }
}

export async function assertChatAllowance(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  estimateInputTokens: number
) {
  const plan = await getPlanForUser(supabase, userId);
  const limits = PLAN_LIMITS[plan];
  if (limits.monthlyInputTokens === null) return; // unlimited
  const { row } = await getUsageForCurrentMonth(supabase, userId);
  const used = row?.input_tokens ?? 0;
  if (used + estimateInputTokens > limits.monthlyInputTokens) {
    throw jsonErr("Monthly token quota exceeded.", 429, "QUOTA_EXCEEDED");
  }
}

export async function recordChatUsage(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  inputTokens: number,
  outputTokens: number
) {
  await upsertUsage(supabase, userId, { input: inputTokens, output: outputTokens });
}

export async function assertMutationAllowed(
  supabase: ReturnType<typeof createClient>,
  userId: string
) {
  const plan = await getPlanForUser(supabase, userId);
  const limits = PLAN_LIMITS[plan];
  if (!limits.allowMutation) {
    throw jsonErr("Upgrade required to perform write actions.", 402, "PAYWALL");
  }
}

export async function recordMutation(
  supabase: ReturnType<typeof createClient>,
  userId: string
) {
  await upsertUsage(supabase, userId, { mutations: 1 });
}

/** A very rough token estimator: ~ 1 token ≈ 4 chars */
export function estimateTokensFromText(text: string): number {
  // keep it simple and fast for preflight checks
  return Math.ceil((text || "").length / 4);
}
