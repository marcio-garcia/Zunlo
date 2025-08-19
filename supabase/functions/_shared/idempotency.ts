// Single responsibility: Save & fetch idempotency results.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export async function getIdempotentResult(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  key: string
): Promise<any | null> {
  const { data, error } = await supabase
    .from("idempotency")
    .select("result")
    .eq("user_id", userId)
    .eq("key", key)
    .maybeSingle();

  if (error) return null;
  return data?.result ?? null;
}

/** Upsert result for (user_id, key). Safe to call multiple times. */
export async function saveIdempotentResult(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  key: string,
  result: unknown
): Promise<void> {
  const row = {
    user_id: userId,
    key,
    result,
    // created_at has a default; setting explicitly is harmless but optional
    created_at: new Date().toISOString(),
  };

  const { error } = await supabase
    .from("idempotency")
    .upsert(row, { onConflict: "user_id,key" }); // PG composite PK

  if (error) throw error;
}