// Single responsibility: Resolve the authenticated user and return a Supabase client
// bound to their JWT. We’ll add plan/quota checks in later phases.

// supabase/functions/_shared/guard.ts
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type AuthContext = {
  supabase: SupabaseClient; // user-scoped client (RLS)
  userId: string;           // UUID string
  token: string;            // raw bearer, in case you need it elsewhere
};

// Accept Request or HonoRequest (or anything with header()/headers/raw)
type RequestLike = Request & { header?: (k: string) => string | null | undefined; raw?: Request } | any;

function getAuthHeader(req: RequestLike): string | null {
  // HonoRequest.header('authorization')
  if (typeof req?.header === "function") {
    const v = req.header("authorization") ?? req.header("Authorization");
    if (v) return v;
  }
  // HonoRequest.raw (native Request)
  const raw: Request | undefined = req?.raw;
  if (raw?.headers) {
    const v = raw.headers.get("authorization") ?? raw.headers.get("Authorization");
    if (v) return v;
  }
  // Native Request
  const headers: Headers | undefined = req?.headers;
  if (headers) {
    const v = headers.get("authorization") ?? headers.get("Authorization");
    if (v) return v;
  }
  return null;
}

export async function withAuth(req: Request): Promise<AuthContext | Response> {
  const hdr = getAuthHeader(req);

  // Expect "Bearer <jwt>"
  const m = hdr.match(/^Bearer\s+(.+)$/i);
  const token = m?.[1];

  console.log("[auth] headerPresent=", !!hdr, "tokenDots=", token?.split(".").length ?? 0);

  if (!hdr) return new Response("Unauthorized", { status: 401 });
  
  if (!token || token.split(".").length !== 3) {
    return new Response("Unauthorized", { status: 401 });
  }

  const url  = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anon) {
    console.error("[guard] Missing SUPABASE_URL or SUPABASE_ANON_KEY");
    return new Response("Server misconfiguration", { status: 500 });
  }

  // User-scoped client that forwards the caller's JWT (for RLS)
  const supabase = createClient(url, anon, {
    global: {
      headers: {
        apikey: anon,                    // explicit is fine
        Authorization: `Bearer ${token}`,// <- valid compact JWS
      },
    },
  });

  const t0 = performance.now();
  // Verify user and get their id
  const { data, error } = await supabase.auth.getUser();

  console.log("[auth] getUser ms=", (performance.now() - t0).toFixed(1), "uid=", data?.user?.id ?? "<none>", "err=", !!error);

  if (error || !data?.user?.id) {
    return new Response("Unauthorized", { status: 401 });
  }

  return { supabase, userId: data.user.id, token };
}

// import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// export type AuthContext = {
//   supabase: ReturnType<typeof createClient>;
//   userId: string; // UUID string
// };

// export async function withAuth(req: Request): Promise<AuthContext | Response> {
//   // Pull the user's bearer token from the incoming request.
//   const auth = req.headers.get("Authorization") ?? "";
//   if (!auth) return new Response("Unauthorized", { status: 401 });

//   // Create a Supabase client that forwards the caller's JWT to PostgREST.
//   const supabase = createClient(
//     Deno.env.get("SUPABASE_URL")!,
//     Deno.env.get("SUPABASE_ANON_KEY")!,
//     { global: { headers: { Authorization: auth } } }
//   );

//   // Ask Supabase Auth who this is.
//   const { data, error } = await supabase.auth.getUser();
//   if (error || !data?.user?.id) return new Response("Unauthorized", { status: 401 });

//   return { supabase, userId: data.user.id };
// }

