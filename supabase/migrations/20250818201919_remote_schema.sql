

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."bump_version_and_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at := now();
  IF TG_OP = 'INSERT' THEN
    NEW.version := 1;                          -- first version
  ELSE
    NEW.version := COALESCE(OLD.version, 0) + 1;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."bump_version_and_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_events"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    AS $$
  with ev as (
    select
      e.*,
      coalesce(
        (
          select jsonb_agg(to_jsonb(eo) order by eo.id)
          from public.event_overrides eo
          where eo.event_id = e.id
        ),
        '[]'::jsonb
      ) as overrides,
      coalesce(
        (
          select jsonb_agg(to_jsonb(rr) order by rr.id)
          from public.recurrence_rules rr
          where rr.event_id = e.id
        ),
        '[]'::jsonb
      ) as recurrence_rules
    from public.events e
    where e.user_id = auth.uid()
  )
  select coalesce(
    jsonb_agg(to_jsonb(ev) order by ev.start_datetime),
    '[]'::jsonb
  )
  from ev;
$$;


ALTER FUNCTION "public"."get_user_events"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."split_recurring_event"("p_original_event_id" "uuid", "p_split_date" timestamp with time zone, "p_new_event_data" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$DECLARE
  v_new_event_id UUID;
  v_user_id UUID;
BEGIN
  -- Validate input
  IF p_original_event_id IS NULL OR p_split_date IS NULL OR p_new_event_data IS NULL THEN
    RAISE EXCEPTION 'Invalid input parameters';
  END IF;

  -- Extract user_id from new event data
  v_user_id := (p_new_event_data->>'user_id')::UUID;

  -- Verify the original event belongs to the user
  IF NOT EXISTS (
    SELECT 1 FROM events 
    WHERE id = p_original_event_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Event not found or unauthorized';
  END IF;

  -- Insert new event
  INSERT INTO events (
    user_id, title, description, start_datetime, end_datetime,
    is_recurring, location, color, reminder_triggers
  )
  VALUES (
    v_user_id,
    p_new_event_data->>'title',
    p_new_event_data->>'description',
    (p_new_event_data->>'start_datetime')::TIMESTAMPTZ,
    (p_new_event_data->>'end_datetime')::TIMESTAMPTZ,
    COALESCE((p_new_event_data->>'is_recurring')::BOOLEAN, false),
    p_new_event_data->>'location',
    p_new_event_data->>'color',
    (p_new_event_data->>'reminder_triggers')::JSONB
  ) RETURNING id INTO v_new_event_id;

  -- Clone recurrence rule for new event if the original was recurring
  IF EXISTS (SELECT 1 FROM recurrence_rules WHERE event_id = p_original_event_id) THEN
    INSERT INTO recurrence_rules (
      event_id, freq, interval, byweekday, bymonthday, bymonth, until, count
    )
    SELECT 
      v_new_event_id, 
      freq, 
      interval, 
      byweekday, 
      bymonthday, 
      bymonth,
      until,
      count
    FROM recurrence_rules
    WHERE event_id = p_original_event_id
    LIMIT 1;
  END IF;

  -- Update original event's recurrence rule
  UPDATE recurrence_rules
  SET until = p_split_date - INTERVAL '1 day'
  WHERE event_id = p_original_event_id 
    AND (until IS NULL OR until > p_split_date - INTERVAL '1 day');

  -- Update event overrides to point to the new event
  UPDATE event_overrides
  SET event_id = v_new_event_id
  WHERE event_id = p_original_event_id 
    AND occurrence_date >= p_split_date;

  RETURN v_new_event_id;
END;$$;


ALTER FUNCTION "public"."split_recurring_event"("p_original_event_id" "uuid", "p_split_date" timestamp with time zone, "p_new_event_data" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."entitlements" (
    "user_id" "uuid" NOT NULL,
    "plan" "text" NOT NULL,
    "expires_at" timestamp with time zone,
    "is_grace_period" boolean DEFAULT false NOT NULL,
    "apple_original_txn_id" "text",
    "app_account_token" "uuid",
    "last_checked_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."entitlements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."event_overrides" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "occurrence_date" timestamp with time zone NOT NULL,
    "overridden_title" "text",
    "overridden_start_datetime" timestamp with time zone,
    "overridden_end_datetime" timestamp with time zone,
    "overridden_location" "text",
    "is_cancelled" boolean DEFAULT false,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text") NOT NULL,
    "color" "text",
    "deleted_at" timestamp with time zone,
    "version" integer NOT NULL
);


ALTER TABLE "public"."event_overrides" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"() NOT NULL,
    "title" "text" NOT NULL,
    "notes" "text",
    "start_datetime" timestamp with time zone NOT NULL,
    "end_datetime" timestamp with time zone,
    "is_recurring" boolean DEFAULT false NOT NULL,
    "location" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text") NOT NULL,
    "color" "text",
    "reminder_triggers" "jsonb" DEFAULT '[]'::"jsonb",
    "deleted_at" timestamp with time zone,
    "version" integer NOT NULL
);


ALTER TABLE "public"."events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plans" (
    "plan" "text" NOT NULL,
    "monthly_token_limit" integer NOT NULL,
    "model_allow_mutations" boolean DEFAULT false NOT NULL,
    "planning_level" "text" NOT NULL,
    CONSTRAINT "plans_monthly_token_limit_check" CHECK (("monthly_token_limit" >= 0)),
    CONSTRAINT "plans_planning_level_check" CHECK (("planning_level" = ANY (ARRAY['none'::"text", 'simple'::"text", 'full'::"text"])))
);


ALTER TABLE "public"."plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."push_tokens" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid",
    "token" "text" NOT NULL,
    "platform" "text" NOT NULL,
    "app_version" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."push_tokens" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."recurrence_rules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "event_id" "uuid" NOT NULL,
    "freq" "text" NOT NULL,
    "interval" integer DEFAULT 1 NOT NULL,
    "byweekday" integer[],
    "bymonthday" integer[],
    "bymonth" integer[],
    "until" timestamp with time zone,
    "count" integer,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text") NOT NULL,
    "deleted_at" timestamp with time zone,
    "version" integer NOT NULL,
    CONSTRAINT "recurrence_rules_freq_check" CHECK (("freq" = ANY (ARRAY['daily'::"text", 'weekly'::"text", 'monthly'::"text", 'yearly'::"text"])))
);


ALTER TABLE "public"."recurrence_rules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tasks" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "auth"."uid"(),
    "title" "text" NOT NULL,
    "notes" "text",
    "is_completed" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT ("now"() AT TIME ZONE 'utc'::"text") NOT NULL,
    "scheduled_date" timestamp with time zone,
    "due_date" timestamp with time zone,
    "parent_event_id" "uuid",
    "tags" "text"[] DEFAULT '{}'::"text"[],
    "reminder_triggers" "jsonb" DEFAULT '[]'::"jsonb",
    "priority" integer,
    "deleted_at" timestamp with time zone,
    "version" integer NOT NULL
);


ALTER TABLE "public"."tasks" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usage_monthly" (
    "user_id" "uuid" NOT NULL,
    "month" "date" NOT NULL,
    "tokens_in" bigint DEFAULT 0 NOT NULL,
    "tokens_out" bigint DEFAULT 0 NOT NULL,
    "o3_tokens_out" bigint DEFAULT 0 NOT NULL,
    "tool_mutations_count" integer DEFAULT 0 NOT NULL,
    "planning_calls_count" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."usage_monthly" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_entitlements_effective" AS
 SELECT "e"."user_id",
    "e"."plan",
    "p"."monthly_token_limit",
    "p"."model_allow_mutations",
    "p"."planning_level",
    "e"."expires_at",
    "e"."is_grace_period",
    "e"."last_checked_at"
   FROM ("public"."entitlements" "e"
     JOIN "public"."plans" "p" ON (("p"."plan" = "e"."plan")));


ALTER VIEW "public"."v_entitlements_effective" OWNER TO "postgres";


ALTER TABLE ONLY "public"."entitlements"
    ADD CONSTRAINT "entitlements_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."event_overrides"
    ADD CONSTRAINT "event_overrides_event_id_occurrence_date_key" UNIQUE ("event_id", "occurrence_date");



ALTER TABLE ONLY "public"."event_overrides"
    ADD CONSTRAINT "event_overrides_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("plan");



ALTER TABLE ONLY "public"."push_tokens"
    ADD CONSTRAINT "push_tokens_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."recurrence_rules"
    ADD CONSTRAINT "recurrence_rules_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usage_monthly"
    ADD CONSTRAINT "usage_monthly_pkey" PRIMARY KEY ("user_id", "month");



CREATE INDEX "idx_event_overrides_event_id" ON "public"."event_overrides" USING "btree" ("event_id", "occurrence_date");



CREATE INDEX "idx_event_overrides_event_id_id" ON "public"."event_overrides" USING "btree" ("event_id", "id");



CREATE INDEX "idx_event_overrides_updated_at" ON "public"."event_overrides" USING "btree" ("updated_at");



CREATE INDEX "idx_events_updated_at" ON "public"."events" USING "btree" ("updated_at");



CREATE INDEX "idx_events_user_id" ON "public"."events" USING "btree" ("user_id");



CREATE INDEX "idx_events_user_start" ON "public"."events" USING "btree" ("user_id", "start_datetime");



CREATE INDEX "idx_recurrence_rules_event_id" ON "public"."recurrence_rules" USING "btree" ("event_id");



CREATE INDEX "idx_recurrence_rules_event_id_id" ON "public"."recurrence_rules" USING "btree" ("event_id", "id");



CREATE INDEX "idx_recurrence_rules_updated_at" ON "public"."recurrence_rules" USING "btree" ("updated_at");



CREATE INDEX "idx_rr_event_id" ON "public"."recurrence_rules" USING "btree" ("event_id");



CREATE INDEX "idx_rr_updated_at" ON "public"."recurrence_rules" USING "btree" ("updated_at");



CREATE INDEX "idx_tasks_updated_at" ON "public"."tasks" USING "btree" ("updated_at");



CREATE INDEX "idx_tasks_user_id" ON "public"."tasks" USING "btree" ("user_id");



CREATE UNIQUE INDEX "push_tokens_user_id_token_idx" ON "public"."push_tokens" USING "btree" ("user_id", "token");



CREATE UNIQUE INDEX "push_tokens_user_id_token_idx1" ON "public"."push_tokens" USING "btree" ("user_id", "token");



CREATE UNIQUE INDEX "uniq_event_overrides_event_occ" ON "public"."event_overrides" USING "btree" ("event_id", "occurrence_date");



CREATE UNIQUE INDEX "uniq_rr_event" ON "public"."recurrence_rules" USING "btree" ("event_id");



CREATE UNIQUE INDEX "unique_token" ON "public"."push_tokens" USING "btree" ("token");



CREATE INDEX "usage_monthly_month_idx" ON "public"."usage_monthly" USING "btree" ("month");



CREATE OR REPLACE TRIGGER "trg_event_overrides_bump" BEFORE INSERT OR UPDATE ON "public"."event_overrides" FOR EACH ROW EXECUTE FUNCTION "public"."bump_version_and_updated_at"();



CREATE OR REPLACE TRIGGER "trg_events_bump" BEFORE INSERT OR UPDATE ON "public"."events" FOR EACH ROW EXECUTE FUNCTION "public"."bump_version_and_updated_at"();



CREATE OR REPLACE TRIGGER "trg_recurrence_rules_bump" BEFORE INSERT OR UPDATE ON "public"."recurrence_rules" FOR EACH ROW EXECUTE FUNCTION "public"."bump_version_and_updated_at"();



CREATE OR REPLACE TRIGGER "trg_tasks_bump" BEFORE INSERT OR UPDATE ON "public"."tasks" FOR EACH ROW EXECUTE FUNCTION "public"."bump_version_and_updated_at"();



ALTER TABLE ONLY "public"."entitlements"
    ADD CONSTRAINT "entitlements_plan_fkey" FOREIGN KEY ("plan") REFERENCES "public"."plans"("plan");



ALTER TABLE ONLY "public"."entitlements"
    ADD CONSTRAINT "entitlements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."event_overrides"
    ADD CONSTRAINT "event_overrides_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."push_tokens"
    ADD CONSTRAINT "push_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."recurrence_rules"
    ADD CONSTRAINT "recurrence_rules_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_parent_event_id_fkey" FOREIGN KEY ("parent_event_id") REFERENCES "public"."events"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tasks"
    ADD CONSTRAINT "tasks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usage_monthly"
    ADD CONSTRAINT "usage_monthly_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Delete own event overrides" ON "public"."event_overrides" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."events"
  WHERE (("events"."id" = "event_overrides"."event_id") AND ("events"."user_id" = "auth"."uid"())))));



CREATE POLICY "Delete own events" ON "public"."events" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Delete own recurrence rules" ON "public"."recurrence_rules" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."events"
  WHERE (("events"."id" = "recurrence_rules"."event_id") AND ("events"."user_id" = "auth"."uid"())))));



CREATE POLICY "Delete own tasks" ON "public"."tasks" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Insert own event overrides" ON "public"."event_overrides" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."events"
  WHERE (("events"."id" = "event_overrides"."event_id") AND ("events"."user_id" = "auth"."uid"())))));



CREATE POLICY "Insert own events" ON "public"."events" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Insert own push_tokens" ON "public"."push_tokens" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Insert own recurrence rules" ON "public"."recurrence_rules" FOR INSERT TO "authenticated" WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."events"
  WHERE (("events"."id" = "recurrence_rules"."event_id") AND ("events"."user_id" = "auth"."uid"())))));



CREATE POLICY "Insert own tasks" ON "public"."tasks" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Select own event overrides" ON "public"."event_overrides" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."events"
  WHERE (("events"."id" = "event_overrides"."event_id") AND ("events"."user_id" = "auth"."uid"())))));



CREATE POLICY "Select own events" ON "public"."events" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Select own recurrence rules" ON "public"."recurrence_rules" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."events"
  WHERE (("events"."id" = "recurrence_rules"."event_id") AND ("events"."user_id" = "auth"."uid"())))));



CREATE POLICY "Select own tasks" ON "public"."tasks" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Update own event overrides" ON "public"."event_overrides" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "event_overrides"."event_id") AND ("e"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "event_overrides"."event_id") AND ("e"."user_id" = "auth"."uid"())))));



CREATE POLICY "Update own events" ON "public"."events" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Update own push_tokens" ON "public"."push_tokens" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Update own recurrence rules" ON "public"."recurrence_rules" FOR UPDATE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "recurrence_rules"."event_id") AND ("e"."user_id" = "auth"."uid"()))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."events" "e"
  WHERE (("e"."id" = "recurrence_rules"."event_id") AND ("e"."user_id" = "auth"."uid"())))));



CREATE POLICY "Update own tasks" ON "public"."tasks" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."entitlements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entitlements_select_own" ON "public"."entitlements" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."event_overrides" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "plans_select_all_authenticated" ON "public"."plans" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."push_tokens" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."recurrence_rules" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tasks" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."usage_monthly" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usage_monthly_select_own" ON "public"."usage_monthly" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."bump_version_and_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."bump_version_and_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."bump_version_and_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_events"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_events"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_events"() TO "service_role";



GRANT ALL ON FUNCTION "public"."split_recurring_event"("p_original_event_id" "uuid", "p_split_date" timestamp with time zone, "p_new_event_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."split_recurring_event"("p_original_event_id" "uuid", "p_split_date" timestamp with time zone, "p_new_event_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."split_recurring_event"("p_original_event_id" "uuid", "p_split_date" timestamp with time zone, "p_new_event_data" "jsonb") TO "service_role";


















GRANT ALL ON TABLE "public"."entitlements" TO "anon";
GRANT ALL ON TABLE "public"."entitlements" TO "authenticated";
GRANT ALL ON TABLE "public"."entitlements" TO "service_role";



GRANT ALL ON TABLE "public"."event_overrides" TO "anon";
GRANT ALL ON TABLE "public"."event_overrides" TO "authenticated";
GRANT ALL ON TABLE "public"."event_overrides" TO "service_role";



GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";



GRANT ALL ON TABLE "public"."plans" TO "anon";
GRANT ALL ON TABLE "public"."plans" TO "authenticated";
GRANT ALL ON TABLE "public"."plans" TO "service_role";



GRANT ALL ON TABLE "public"."push_tokens" TO "anon";
GRANT ALL ON TABLE "public"."push_tokens" TO "authenticated";
GRANT ALL ON TABLE "public"."push_tokens" TO "service_role";



GRANT ALL ON TABLE "public"."recurrence_rules" TO "anon";
GRANT ALL ON TABLE "public"."recurrence_rules" TO "authenticated";
GRANT ALL ON TABLE "public"."recurrence_rules" TO "service_role";



GRANT ALL ON TABLE "public"."tasks" TO "anon";
GRANT ALL ON TABLE "public"."tasks" TO "authenticated";
GRANT ALL ON TABLE "public"."tasks" TO "service_role";



GRANT ALL ON TABLE "public"."usage_monthly" TO "anon";
GRANT ALL ON TABLE "public"."usage_monthly" TO "authenticated";
GRANT ALL ON TABLE "public"."usage_monthly" TO "service_role";



GRANT ALL ON TABLE "public"."v_entitlements_effective" TO "anon";
GRANT ALL ON TABLE "public"."v_entitlements_effective" TO "authenticated";
GRANT ALL ON TABLE "public"."v_entitlements_effective" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























RESET ALL;
