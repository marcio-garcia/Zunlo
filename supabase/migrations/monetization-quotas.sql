-- ===========================
-- Zunlo Monetization & Quotas
-- user_plans, usage_counters
-- RLS + RPCs + Trigger
-- ===========================
begin;

-- 1) Tables
-- ----------

create table if not exists public.user_plans (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  plan       text not null check (plan in ('free','pro')),
  renews_at  timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.usage_counters (
  user_id        uuid not null references auth.users(id) on delete cascade,
  period_start   date not null,
  period_end     date not null,
  input_tokens   bigint not null default 0,
  output_tokens  bigint not null default 0,
  mutation_count bigint not null default 0,
  updated_at     timestamptz not null default now(),
  primary key (user_id, period_start)
);

-- Helpful indexes
create index if not exists usage_counters_user_idx on public.usage_counters(user_id);
create index if not exists usage_counters_period_idx on public.usage_counters(period_start);

-- 2) Enable Row Level Security
-- ----------------------------

alter table public.user_plans     enable row level security;
alter table public.usage_counters enable row level security;

-- 3) RLS Policies (read self; no client writes)
-- ---------------------------------------------

-- Users can read their own plan
drop policy if exists "read own plan" on public.user_plans;
create policy "read own plan"
on public.user_plans
for select
to authenticated
using (user_id = auth.uid());

-- Users can read their own usage counters
drop policy if exists "read own usage counters" on public.usage_counters;
create policy "read own usage counters"
on public.usage_counters
for select
to authenticated
using (user_id = auth.uid());

-- No insert/update/delete policies for authenticated:
--   → clients cannot modify plan or usage directly.
--   → Edge Functions using service_role bypass RLS automatically.

-- 4) RPCs (SECURITY DEFINER)
-- --------------------------

-- 4a) Auto-create a FREE plan row on signup
create or replace function public.ensure_user_plan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_plans (user_id, plan, updated_at)
  values (new.id, 'free', now())
  on conflict (user_id) do nothing;
  return new;
end;
$$;

-- Recreate trigger on auth.users
drop trigger if exists trg_ensure_user_plan on auth.users;
create trigger trg_ensure_user_plan
after insert on auth.users
for each row
execute function public.ensure_user_plan();

-- (Not typically called directly, but lock it down anyway)
revoke all on function public.ensure_user_plan() from public, anon, authenticated;
grant execute on function public.ensure_user_plan() to service_role;

-- 4b) Admin/service: set a user's plan
create or replace function public.admin_set_plan(p_user_id uuid, p_plan text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_plan not in ('free','pro') then
    raise exception 'invalid plan %', p_plan;
  end if;

  insert into public.user_plans(user_id, plan, updated_at)
  values (p_user_id, p_plan, now())
  on conflict (user_id)
  do update set plan = excluded.plan, updated_at = now();
end;
$$;

revoke all on function public.admin_set_plan(uuid, text) from public, anon, authenticated;
grant execute on function public.admin_set_plan(uuid, text) to service_role;

-- 4c) Usage increment (atomic upsert)
create or replace function public.usage_increment(
  p_user_id uuid,
  p_period_start date,
  p_period_end date,
  p_input_tokens bigint,
  p_output_tokens bigint,
  p_mutation_count bigint
) returns void
language plpgsql
security definer
set search_path = public
as $$
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
$$;

revoke all on function public.usage_increment(uuid, date, date, bigint, bigint, bigint)
  from public, anon, authenticated;
grant execute on function public.usage_increment(uuid, date, date, bigint, bigint, bigint)
  to service_role;

-- 4d) Client-friendly: get my plan (optional convenience)
create or replace function public.get_my_plan()
returns table(plan text, renews_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select coalesce(up.plan, 'free')::text as plan, up.renews_at
  from auth.users u
  left join public.user_plans up on up.user_id = u.id
  where u.id = auth.uid();
$$;

revoke all on function public.get_my_plan() from public, anon;
grant execute on function public.get_my_plan() to authenticated;

commit;
