-- E10: Harden privileges that bypass or weaken RLS.
-- Safe for CELL01 join (SECURITY DEFINER RPC) + teacher dashboard.
-- Applied remotely via Supabase MCP; kept here for repo history / local replay.

-- ---------------------------------------------------------------------------
-- 1) TRUNCATE bypasses RLS — revoke from API roles
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
begin
  for r in
    select tablename
    from pg_tables
    where schemaname = 'public'
  loop
    execute format(
      'revoke truncate on table public.%I from anon, authenticated',
      r.tablename
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2) Content catalog: SELECT only; hide answer keys from anon
-- ---------------------------------------------------------------------------
revoke all on table public.content_versions from anon, authenticated;
revoke all on table public.missions from anon, authenticated;
revoke all on table public.evaluation_stations from anon, authenticated;
revoke all on table public.questions from anon, authenticated;

grant select on table public.content_versions to anon, authenticated;
grant select on table public.missions to anon, authenticated;
grant select on table public.evaluation_stations to anon, authenticated;

-- Anon may read question stems, never keys/rubrics. Teachers keep full SELECT.
grant select (id, station_id, code, question_text, question_type, max_score)
  on table public.questions to anon;
grant select on table public.questions to authenticated;

-- ---------------------------------------------------------------------------
-- 3) learning_sessions / profiles — least privilege for anon
-- ---------------------------------------------------------------------------
revoke insert, update, delete, truncate on table public.learning_sessions from anon;
grant select on table public.learning_sessions to anon;

revoke delete, truncate on table public.learning_sessions from authenticated;

revoke all on table public.profiles from anon;
revoke insert, delete, truncate on table public.profiles from authenticated;
grant select, update on table public.profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Student join is RPC-only — revoke direct INSERT on groups/members
--    (join_active_session is SECURITY DEFINER / owner and still inserts)
-- ---------------------------------------------------------------------------
revoke insert on table public.groups from anon, authenticated;
revoke insert on table public.group_members from anon, authenticated;
revoke delete, truncate on table public.groups from anon, authenticated;
revoke delete, truncate on table public.group_members from anon, authenticated;

-- No client path updates group_members; drop session-wide UPDATE surface.
drop policy if exists group_members_update_active_session on public.group_members;
revoke update on table public.group_members from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) answers — anon/student cannot write teacher scoring columns
-- ---------------------------------------------------------------------------
revoke insert, update, delete, truncate on table public.answers from anon, authenticated;

grant select on table public.answers to anon, authenticated;

grant insert (
  id, group_id, question_id, station_attempt_id,
  answer_text, auto_score, version, updated_at
) on table public.answers to anon, authenticated;

grant update (
  answer_text, auto_score, station_attempt_id, version, updated_at
) on table public.answers to anon;

grant update (
  answer_text, auto_score, teacher_score, final_score, feedback,
  station_attempt_id, version, updated_at
) on table public.answers to authenticated;

-- ---------------------------------------------------------------------------
-- 6) Defense-in-depth: no DELETE privilege on student write tables
-- ---------------------------------------------------------------------------
revoke delete, truncate on table public.mission_progress from anon, authenticated;
revoke delete, truncate on table public.student_questions from anon, authenticated;
revoke delete, truncate on table public.observation_records from anon, authenticated;
revoke delete, truncate on table public.investigation_conclusions from anon, authenticated;
revoke delete, truncate on table public.station_attempts from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7) Hide teacher helper RPCs from PostgREST (private schema)
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

alter function public.is_teacher_or_admin() set schema private;
alter function public.is_session_teacher(uuid) set schema private;

revoke all on function private.is_teacher_or_admin() from public, anon, authenticated;
revoke all on function private.is_session_teacher(uuid) from public, anon, authenticated;
grant execute on function private.is_teacher_or_admin() to authenticated;
grant execute on function private.is_session_teacher(uuid) to authenticated;

-- Recreate policies that referenced public helpers
drop policy if exists sessions_teacher_insert on public.learning_sessions;
create policy sessions_teacher_insert on public.learning_sessions
  for insert to authenticated
  with check (
    private.is_teacher_or_admin()
    and teacher_id = (select auth.uid())
  );

drop policy if exists groups_select_teacher on public.groups;
create policy groups_select_teacher on public.groups
  for select to authenticated
  using (private.is_session_teacher(session_id));

drop policy if exists group_members_select_teacher on public.group_members;
create policy group_members_select_teacher on public.group_members
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

drop policy if exists answers_select_teacher on public.answers;
create policy answers_select_teacher on public.answers
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

drop policy if exists answers_update_teacher_review on public.answers;
create policy answers_update_teacher_review on public.answers
  for update to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  )
  with check (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

drop policy if exists mission_progress_select_teacher on public.mission_progress;
create policy mission_progress_select_teacher on public.mission_progress
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

drop policy if exists conclusions_select_teacher on public.investigation_conclusions;
create policy conclusions_select_teacher on public.investigation_conclusions
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

drop policy if exists station_attempts_select_teacher on public.station_attempts;
create policy station_attempts_select_teacher on public.station_attempts
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

drop policy if exists observation_select_teacher on public.observation_records;
create policy observation_select_teacher on public.observation_records
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

drop policy if exists student_questions_select_teacher on public.student_questions;
create policy student_questions_select_teacher on public.student_questions
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and private.is_session_teacher(g.session_id)
    )
  );

-- ---------------------------------------------------------------------------
-- 8) Harden join_active_session input bounds (CELL01-compatible)
-- ---------------------------------------------------------------------------
create or replace function public.join_active_session(
  p_join_code text,
  p_group_name text,
  p_leader_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.learning_sessions%rowtype;
  v_group_id uuid;
  v_code text := upper(trim(coalesce(p_join_code, '')));
  v_group text := trim(coalesce(p_group_name, ''));
  v_leader text := trim(coalesce(p_leader_name, ''));
begin
  if v_code = '' or v_group = '' or v_leader = '' then
    raise exception 'invalid_join_args' using errcode = '22023';
  end if;

  if char_length(v_code) > 16
     or char_length(v_group) > 80
     or char_length(v_leader) > 80 then
    raise exception 'invalid_join_args' using errcode = '22023';
  end if;

  select * into v_session
  from public.learning_sessions
  where join_code = v_code
    and status = 'active';

  if not found then
    raise exception 'session_not_found' using errcode = 'P0002';
  end if;

  insert into public.groups (session_id, name)
  values (v_session.id, v_group)
  returning id into v_group_id;

  insert into public.group_members (group_id, display_name, is_leader)
  values (v_group_id, v_leader, true);

  return jsonb_build_object(
    'session_id', v_session.id,
    'group_id', v_group_id,
    'session_title', v_session.title,
    'join_code', v_session.join_code
  );
end;
$$;

revoke all on function public.join_active_session(text, text, text) from public;
grant execute on function public.join_active_session(text, text, text)
  to anon, authenticated;
