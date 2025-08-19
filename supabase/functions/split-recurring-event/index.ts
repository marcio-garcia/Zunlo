import { createClient } from 'jsr:@supabase/supabase-js@^2';
Deno.serve(async (req)=>{
  const startTime = Date.now();
  console.log('🟢 Function START', new Date().toISOString());
  try {
    const body = await req.json();
    // Early validation
    if (!body.original_event_id || !body.split_from_date || !body.new_event_data) {
      throw new Error('Invalid input parameters');
    }
    const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
    const splitDate = new Date(body.split_from_date);
    // Batch operations in a single transaction
    const { data, error } = await supabase.rpc('split_recurring_event', {
      p_original_event_id: body.original_event_id,
      p_split_date: splitDate.toISOString(),
      p_new_event_data: body.new_event_data
    });
    if (error) throw error;
    console.log('🟢 Transaction Complete', new Date().toISOString());
    return new Response(JSON.stringify({
      success: true,
      new_event_id: data,
      totalDuration: Date.now() - startTime
    }), {
      status: 200
    });
  } catch (err) {
    console.error('❌ FULL ERROR DETAILS', {
      message: err.message,
      stack: err.stack,
      name: err.name
    });
    return new Response(JSON.stringify({
      error: 'Transaction failed',
      detail: err.message ?? String(err),
      totalDuration: Date.now() - startTime
    }), {
      status: 500
    });
  }
});
