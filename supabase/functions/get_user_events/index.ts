import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";
Deno.serve(async (req)=>{
  const supabase = createClient(Deno.env.get("SUPABASE_URL"), Deno.env.get("SUPABASE_ANON_KEY"), {
    global: {
      headers: {
        Authorization: req.headers.get("Authorization")
      }
    }
  });
  // 🔐 Ensure the caller is authenticated (auth.uid() in SQL needs this)
  const { data: authData, error: authError } = await supabase.auth.getUser();
  if (authError || !authData?.user) {
    return new Response(JSON.stringify({
      error: "Unauthorized"
    }), {
      status: 401,
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
  // 🚀 Call RPC without parameters; SQL uses auth.uid()
  const { data, error } = await supabase.rpc("get_user_events");
  if (error) {
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        "Content-Type": "application/json"
      }
    });
  }
  return new Response(JSON.stringify(data), {
    headers: {
      "Content-Type": "application/json"
    }
  });
});
