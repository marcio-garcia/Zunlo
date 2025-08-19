
  create table "public"."idempotency" (
    "user_id" uuid not null,
    "key" text not null,
    "result" jsonb not null,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."idempotency" enable row level security;


  create table "public"."usage_counters" (
    "user_id" uuid not null,
    "period_start" date not null,
    "period_end" date not null,
    "input_tokens" bigint not null default 0,
    "output_tokens" bigint not null default 0,
    "mutation_count" bigint not null default 0,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."usage_counters" enable row level security;


  create table "public"."user_plans" (
    "user_id" uuid not null,
    "plan" text not null,
    "renews_at" timestamp with time zone,
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."user_plans" enable row level security;

CREATE UNIQUE INDEX idempotency_pkey ON public.idempotency USING btree (user_id, key);

CREATE INDEX usage_counters_period_idx ON public.usage_counters USING btree (period_start);

CREATE UNIQUE INDEX usage_counters_pkey ON public.usage_counters USING btree (user_id, period_start);

CREATE INDEX usage_counters_user_idx ON public.usage_counters USING btree (user_id);

CREATE UNIQUE INDEX user_plans_pkey ON public.user_plans USING btree (user_id);

alter table "public"."idempotency" add constraint "idempotency_pkey" PRIMARY KEY using index "idempotency_pkey";

alter table "public"."usage_counters" add constraint "usage_counters_pkey" PRIMARY KEY using index "usage_counters_pkey";

alter table "public"."user_plans" add constraint "user_plans_pkey" PRIMARY KEY using index "user_plans_pkey";

alter table "public"."idempotency" add constraint "idempotency_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."idempotency" validate constraint "idempotency_user_id_fkey";

alter table "public"."usage_counters" add constraint "usage_counters_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."usage_counters" validate constraint "usage_counters_user_id_fkey";

alter table "public"."user_plans" add constraint "user_plans_plan_check" CHECK ((plan = ANY (ARRAY['free'::text, 'pro'::text]))) not valid;

alter table "public"."user_plans" validate constraint "user_plans_plan_check";

alter table "public"."user_plans" add constraint "user_plans_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."user_plans" validate constraint "user_plans_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.admin_set_plan(p_user_id uuid, p_plan text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_plan not in ('free','pro') then
    raise exception 'invalid plan %', p_plan;
  end if;

  insert into public.user_plans(user_id, plan, updated_at)
  values (p_user_id, p_plan, now())
  on conflict (user_id)
  do update set plan = excluded.plan, updated_at = now();
end;
$function$
;

CREATE OR REPLACE FUNCTION public.ensure_user_plan()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.user_plans (user_id, plan, updated_at)
  values (new.id, 'free', now())
  on conflict (user_id) do nothing;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.event_split_this_and_future(p_user_id uuid, p_event_id uuid, p_base_version integer, p_split_at timestamp with time zone, p_patch jsonb DEFAULT '{}'::jsonb)
 RETURNS TABLE(event jsonb, recurrence_rule jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev               events%rowtype;
  rl               recurrence_rules%rowtype;

  new_event_id     uuid;
  new_rule_id      uuid;

  new_title        text;
  new_notes        text;
  new_start        timestamptz;
  new_end          timestamptz;
  new_loc          text;
  new_color        text;
  new_reminders    jsonb;

  rr               jsonb;
  rr_freq          text;
  rr_interval      int;
  rr_by_weekday    int[];
  rr_by_monthday   int[];
  rr_by_month      int[];
  rr_until         timestamptz;
  rr_count         int;

  moved_count      int;
begin
  -- Caller must be the owner
  if auth.uid() is distinct from p_user_id then
    raise exception 'not authorized' using errcode = '28000';
  end if;

  -- Load & lock base rows
  select * into ev
    from public.events
   where id = p_event_id and user_id = p_user_id and deleted_at is null
   for update;
  if not found then raise exception 'Event not found'; end if;
  if not ev.is_recurring then raise exception 'this_and_future requires recurring event'; end if;
  if ev.version <> p_base_version then raise exception 'Version mismatch'; end if;

  select * into rl
    from public.recurrence_rules
   where event_id = ev.id and deleted_at is null
   order by created_at asc
   limit 1
   for update;
  if not found then raise exception 'Recurrence rule not found'; end if;

  -- Cap original rule to just before the split point
  update public.recurrence_rules
     set until = (p_split_at - interval '1 millisecond'),
         updated_at = now(),
         version = version + 1
   where id = rl.id;

  -- Bump event version (OCC)
  update public.events
     set updated_at = now(),
         version = ev.version + 1
   where id = ev.id;

  -- Derive new event fields (PATCH semantics):
  new_title     := coalesce(p_patch->>'title', ev.title);
  new_notes     := case when p_patch ? 'notes' then (p_patch->>'notes') else ev.notes end;
  new_start     := coalesce((p_patch->>'start_datetime')::timestamptz, p_split_at);
  new_end       := case when p_patch ? 'end_datetime' then (p_patch->>'end_datetime')::timestamptz else ev.end_datetime end;
  new_loc       := case when p_patch ? 'location' then (p_patch->>'location') else ev.location end;
  new_color     := case when p_patch ? 'color' then (p_patch->>'color') else ev.color end;
  new_reminders := case when p_patch ? 'reminder_triggers' then (p_patch->'reminder_triggers') else ev.reminder_triggers end;

  rr := case when p_patch ? 'recurrence_rule' then (p_patch->'recurrence_rule') else null end;

  -- Extract rule overrides (if provided)
  rr_freq     := coalesce(rr->>'freq', rl.freq);
  rr_interval := coalesce((rr->>'interval')::int, rl.interval);

  if rr ? 'byWeekday' then
    select coalesce(array_agg((v)::int), '{}') into rr_by_weekday
      from jsonb_array_elements_text(rr->'byWeekday') as v;
  else
    rr_by_weekday := rl.by_weekday;
  end if;

  if rr ? 'byMonthday' then
    select coalesce(array_agg((v)::int), '{}') into rr_by_monthday
      from jsonb_array_elements_text(rr->'byMonthday') as v;
  else
    rr_by_monthday := rl.by_monthday;
  end if;

  if rr ? 'byMonth' then
    select coalesce(array_agg((v)::int), '{}') into rr_by_month
      from jsonb_array_elements_text(rr->'byMonth') as v;
  else
    rr_by_month := rl.by_month;
  end if;

  rr_until := (rr->>'until')::timestamptz;  -- may be null
  rr_count := coalesce((rr->>'count')::int, rl.count);

  -- Create new event (future series)
  new_event_id := gen_random_uuid();
  insert into public.events(
    id, user_id, title, notes, start_datetime, end_datetime, is_recurring, location,
    color, reminder_triggers, created_at, updated_at, version, deleted_at
  ) values (
    new_event_id, p_user_id, new_title, new_notes, new_start, new_end, true, new_loc,
    new_color, new_reminders, now(), now(), 1, null
  );

  -- Create its rule
  new_rule_id := gen_random_uuid();
  insert into public.recurrence_rules(
    id, event_id, freq, interval, by_weekday, by_monthday, by_month, until, count,
    created_at, updated_at, version, deleted_at
  ) values (
    new_rule_id, new_event_id, rr_freq, rr_interval, rr_by_weekday, rr_by_monthday, rr_by_month,
    rr_until, rr_count, now(), now(), 1, null
  );

  -- Move overrides at/after split point to the new event
  update public.event_overrides
     set event_id = new_event_id, updated_at = now(), version = version + 1
   where event_id = ev.id
     and occurrence_date >= p_split_at
     and (deleted_at is null);
  get diagnostics moved_count = row_count;

  -- Return new rows (as jsonb)
  return query
    select to_jsonb(e.*) as event, to_jsonb(r.*) as recurrence_rule
      from public.events e
      join public.recurrence_rules r on r.event_id = e.id
     where e.id = new_event_id and r.id = new_rule_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.event_truncate_series_from(p_user_id uuid, p_event_id uuid, p_base_version integer, p_split_at timestamp with time zone)
 RETURNS TABLE(event jsonb, recurrence_rule jsonb)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  ev   events%rowtype;
  rl   recurrence_rules%rowtype;
begin
  if auth.uid() is distinct from p_user_id then
    raise exception 'not authorized' using errcode = '28000';
  end if;

  select * into ev
    from public.events
   where id = p_event_id and user_id = p_user_id and deleted_at is null
   for update;
  if not found then raise exception 'Event not found'; end if;
  if not ev.is_recurring then raise exception 'this_and_future requires recurring event'; end if;
  if ev.version <> p_base_version then raise exception 'Version mismatch'; end if;

  select * into rl
    from public.recurrence_rules
   where event_id = ev.id and deleted_at is null
   order by created_at asc
   limit 1
   for update;
  if not found then raise exception 'Recurrence rule not found'; end if;

  -- Cap original rule
  update public.recurrence_rules
     set until = (p_split_at - interval '1 millisecond'),
         updated_at = now(),
         version = version + 1
   where id = rl.id;

  -- Bump base event version
  update public.events
     set updated_at = now(),
         version = ev.version + 1
   where id = ev.id;

  -- Soft-delete future overrides (not strictly required, but keeps data tidy)
  update public.event_overrides
     set deleted_at = now(), updated_at = now(), version = version + 1
   where event_id = ev.id
     and occurrence_date >= p_split_at
     and deleted_at is null;

  return query
    select to_jsonb(e.*) as event, to_jsonb(r.*) as recurrence_rule
      from public.events e
      join public.recurrence_rules r on r.event_id = e.id
     where e.id = ev.id
     order by r.updated_at desc
     limit 1;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_plan()
 RETURNS TABLE(plan text, renews_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(up.plan, 'free')::text as plan, up.renews_at
  from auth.users u
  left join public.user_plans up on up.user_id = u.id
  where u.id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.purge_old_idempotency(p_older_than interval DEFAULT '30 days'::interval)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  delete from public.idempotency
  where created_at < now() - p_older_than;
$function$
;

CREATE OR REPLACE FUNCTION public.usage_increment(p_user_id uuid, p_period_start date, p_period_end date, p_input_tokens bigint, p_output_tokens bigint, p_mutation_count bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.usage_counters(
    user_id, period_start, period_end,
    input_tokens, output_tokens, mutation_count, updated_at
  )
  values (p_user_id, p_period_start, p_period_end,
          p_input_tokens, p_output_tokens, p_mutation_count, now())
  on conflict (user_id, period_start)
  do update set
    input_tokens   = public.usage_counters.input_tokens   + excluded.input_tokens,
    output_tokens  = public.usage_counters.output_tokens  + excluded.output_tokens,
    mutation_count = public.usage_counters.mutation_count + excluded.mutation_count,
    updated_at     = now();
end;
$function$
;

grant delete on table "public"."idempotency" to "anon";

grant insert on table "public"."idempotency" to "anon";

grant references on table "public"."idempotency" to "anon";

grant select on table "public"."idempotency" to "anon";

grant trigger on table "public"."idempotency" to "anon";

grant truncate on table "public"."idempotency" to "anon";

grant update on table "public"."idempotency" to "anon";

grant delete on table "public"."idempotency" to "authenticated";

grant insert on table "public"."idempotency" to "authenticated";

grant references on table "public"."idempotency" to "authenticated";

grant select on table "public"."idempotency" to "authenticated";

grant trigger on table "public"."idempotency" to "authenticated";

grant truncate on table "public"."idempotency" to "authenticated";

grant update on table "public"."idempotency" to "authenticated";

grant delete on table "public"."idempotency" to "service_role";

grant insert on table "public"."idempotency" to "service_role";

grant references on table "public"."idempotency" to "service_role";

grant select on table "public"."idempotency" to "service_role";

grant trigger on table "public"."idempotency" to "service_role";

grant truncate on table "public"."idempotency" to "service_role";

grant update on table "public"."idempotency" to "service_role";

grant delete on table "public"."usage_counters" to "anon";

grant insert on table "public"."usage_counters" to "anon";

grant references on table "public"."usage_counters" to "anon";

grant select on table "public"."usage_counters" to "anon";

grant trigger on table "public"."usage_counters" to "anon";

grant truncate on table "public"."usage_counters" to "anon";

grant update on table "public"."usage_counters" to "anon";

grant delete on table "public"."usage_counters" to "authenticated";

grant insert on table "public"."usage_counters" to "authenticated";

grant references on table "public"."usage_counters" to "authenticated";

grant select on table "public"."usage_counters" to "authenticated";

grant trigger on table "public"."usage_counters" to "authenticated";

grant truncate on table "public"."usage_counters" to "authenticated";

grant update on table "public"."usage_counters" to "authenticated";

grant delete on table "public"."usage_counters" to "service_role";

grant insert on table "public"."usage_counters" to "service_role";

grant references on table "public"."usage_counters" to "service_role";

grant select on table "public"."usage_counters" to "service_role";

grant trigger on table "public"."usage_counters" to "service_role";

grant truncate on table "public"."usage_counters" to "service_role";

grant update on table "public"."usage_counters" to "service_role";

grant delete on table "public"."user_plans" to "anon";

grant insert on table "public"."user_plans" to "anon";

grant references on table "public"."user_plans" to "anon";

grant select on table "public"."user_plans" to "anon";

grant trigger on table "public"."user_plans" to "anon";

grant truncate on table "public"."user_plans" to "anon";

grant update on table "public"."user_plans" to "anon";

grant delete on table "public"."user_plans" to "authenticated";

grant insert on table "public"."user_plans" to "authenticated";

grant references on table "public"."user_plans" to "authenticated";

grant select on table "public"."user_plans" to "authenticated";

grant trigger on table "public"."user_plans" to "authenticated";

grant truncate on table "public"."user_plans" to "authenticated";

grant update on table "public"."user_plans" to "authenticated";

grant delete on table "public"."user_plans" to "service_role";

grant insert on table "public"."user_plans" to "service_role";

grant references on table "public"."user_plans" to "service_role";

grant select on table "public"."user_plans" to "service_role";

grant trigger on table "public"."user_plans" to "service_role";

grant truncate on table "public"."user_plans" to "service_role";

grant update on table "public"."user_plans" to "service_role";


  create policy "idempotency_insert_own"
  on "public"."idempotency"
  as permissive
  for insert
  to authenticated
with check ((auth.uid() = user_id));



  create policy "idempotency_select_own"
  on "public"."idempotency"
  as permissive
  for select
  to authenticated
using ((auth.uid() = user_id));



  create policy "read own usage counters"
  on "public"."usage_counters"
  as permissive
  for select
  to authenticated
using ((user_id = auth.uid()));



  create policy "read own plan"
  on "public"."user_plans"
  as permissive
  for select
  to authenticated
using ((user_id = auth.uid()));


CREATE TRIGGER trg_ensure_user_plan AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION ensure_user_plan();


