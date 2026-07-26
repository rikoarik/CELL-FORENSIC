-- E7-01: Replace permissive MVP write policies with active-session scope.
-- Classroom anon join for active sessions (e.g. CELL01) remains allowed.
-- Applied remotely via Supabase MCP; kept here for repo history / local replay.

create or replace function public.session_is_active(target_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.learning_sessions s
    where s.id = target_session_id
      and s.status = 'active'
  );
$$;

create or replace function public.group_in_active_session(target_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.groups g
    join public.learning_sessions s on s.id = g.session_id
    where g.id = target_group_id
      and s.status = 'active'
  );
$$;

revoke all on function public.session_is_active(uuid) from public;
revoke all on function public.group_in_active_session(uuid) from public;
grant execute on function public.session_is_active(uuid) to anon, authenticated;
grant execute on function public.group_in_active_session(uuid) to anon, authenticated;

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
grant execute on function public.join_active_session(text, text, text) to anon, authenticated;

drop policy if exists groups_select_all_mvp on public.groups;
drop policy if exists groups_insert_active_session on public.groups;
drop policy if exists group_members_select_mvp on public.group_members;
drop policy if exists group_members_insert_mvp on public.group_members;
drop policy if exists mission_progress_select_mvp on public.mission_progress;
drop policy if exists mission_progress_insert_mvp on public.mission_progress;
drop policy if exists mission_progress_update_mvp on public.mission_progress;
drop policy if exists student_questions_select_mvp on public.student_questions;
drop policy if exists student_questions_insert_mvp on public.student_questions;
drop policy if exists observation_select_mvp on public.observation_records;
drop policy if exists observation_insert_mvp on public.observation_records;
drop policy if exists observation_update_mvp on public.observation_records;
drop policy if exists conclusions_select_mvp on public.investigation_conclusions;
drop policy if exists conclusions_insert_mvp on public.investigation_conclusions;
drop policy if exists conclusions_update_mvp on public.investigation_conclusions;
drop policy if exists station_attempts_select_mvp on public.station_attempts;
drop policy if exists station_attempts_insert_mvp on public.station_attempts;
drop policy if exists station_attempts_update_mvp on public.station_attempts;
drop policy if exists answers_select_mvp on public.answers;
drop policy if exists answers_insert_mvp on public.answers;
drop policy if exists answers_update_mvp on public.answers;

create policy profiles_select_self on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

create policy groups_select_active_session on public.groups
  for select to anon, authenticated
  using (public.session_is_active(session_id));

create policy groups_insert_active_session on public.groups
  for insert to anon, authenticated
  with check (public.session_is_active(session_id));

create policy group_members_select_active_session on public.group_members
  for select to anon, authenticated
  using (public.group_in_active_session(group_id));

create policy group_members_insert_active_session on public.group_members
  for insert to anon, authenticated
  with check (public.group_in_active_session(group_id));

create policy group_members_update_active_session on public.group_members
  for update to anon, authenticated
  using (public.group_in_active_session(group_id))
  with check (public.group_in_active_session(group_id));

create policy mission_progress_select_active_session on public.mission_progress
  for select to anon, authenticated
  using (public.group_in_active_session(group_id));

create policy mission_progress_insert_active_session on public.mission_progress
  for insert to anon, authenticated
  with check (public.group_in_active_session(group_id));

create policy mission_progress_update_active_session on public.mission_progress
  for update to anon, authenticated
  using (public.group_in_active_session(group_id))
  with check (public.group_in_active_session(group_id));

create policy student_questions_select_active_session on public.student_questions
  for select to anon, authenticated
  using (public.group_in_active_session(group_id));

create policy student_questions_insert_active_session on public.student_questions
  for insert to anon, authenticated
  with check (public.group_in_active_session(group_id));

create policy observation_select_active_session on public.observation_records
  for select to anon, authenticated
  using (public.group_in_active_session(group_id));

create policy observation_insert_active_session on public.observation_records
  for insert to anon, authenticated
  with check (public.group_in_active_session(group_id));

create policy observation_update_active_session on public.observation_records
  for update to anon, authenticated
  using (public.group_in_active_session(group_id))
  with check (public.group_in_active_session(group_id));

create policy conclusions_select_active_session on public.investigation_conclusions
  for select to anon, authenticated
  using (public.group_in_active_session(group_id));

create policy conclusions_insert_active_session on public.investigation_conclusions
  for insert to anon, authenticated
  with check (public.group_in_active_session(group_id));

create policy conclusions_update_active_session on public.investigation_conclusions
  for update to anon, authenticated
  using (public.group_in_active_session(group_id))
  with check (public.group_in_active_session(group_id));

create policy station_attempts_select_active_session on public.station_attempts
  for select to anon, authenticated
  using (public.group_in_active_session(group_id));

create policy station_attempts_insert_active_session on public.station_attempts
  for insert to anon, authenticated
  with check (public.group_in_active_session(group_id));

create policy station_attempts_update_active_session on public.station_attempts
  for update to anon, authenticated
  using (public.group_in_active_session(group_id))
  with check (public.group_in_active_session(group_id));

create policy answers_select_active_session on public.answers
  for select to anon, authenticated
  using (public.group_in_active_session(group_id));

create policy answers_insert_active_session on public.answers
  for insert to anon, authenticated
  with check (public.group_in_active_session(group_id));

create policy answers_update_active_session on public.answers
  for update to anon, authenticated
  using (public.group_in_active_session(group_id))
  with check (public.group_in_active_session(group_id));
