// Single responsibility: Resolve the authenticated user and return a Supabase client
// bound to their JWT. We’ll add plan/quota checks in later phases.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export type AuthContext = {
  supabase: ReturnType<typeof createClient>;
  userId: string; // UUID string
};

export async function withAuth(req: Request): Promise<AuthContext | Response> {
  // Pull the user's bearer token from the incoming request.
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth) return new Response("Unauthorized", { status: 401 });

  // Create a Supabase client that forwards the caller's JWT to PostgREST.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: auth } } }
  );

  // Ask Supabase Auth who this is.
  const { data, error } = await supabase.auth.getUser();
  if (error || !data?.user?.id) return new Response("Unauthorized", { status: 401 });

  return { supabase, userId: data.user.id };
}

