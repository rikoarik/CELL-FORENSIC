-- E9: Teacher auth helpers, session CRUD policies, tighten student join to RPC.
-- Authz uses public.profiles.role (and app_metadata via trigger) — never user_metadata.
-- Applied remotely via Supabase MCP; kept here for repo history / local replay.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_teacher_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('teacher', 'admin')
  );
$$;

-- Session owner, or admin (not every teacher).
create or replace function public.is_session_teacher(target_session_id uuid)
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
      and s.teacher_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

revoke all on function public.is_teacher_or_admin() from public;
revoke all on function public.is_session_teacher(uuid) from public;
grant execute on function public.is_teacher_or_admin() to authenticated;
grant execute on function public.is_session_teacher(uuid) to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_name text;
begin
  v_role := coalesce(nullif(trim(new.raw_app_meta_data->>'role'), ''), 'student');
  if v_role not in ('student', 'teacher', 'admin') then
    v_role := 'student';
  end if;

  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data->>'full_name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Pengguna'
  );

  insert into public.profiles (id, full_name, role)
  values (new.id, v_name, v_role)
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create or replace function public.promote_user_to_teacher(
  target_email text,
  display_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(target_email));
  if v_id is null then
    raise exception 'user_not_found: %', target_email using errcode = 'P0002';
  end if;

  update auth.users
  set raw_app_meta_data =
        coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', 'teacher')
  where id = v_id;

  insert into public.profiles (id, full_name, role)
  values (
    v_id,
    coalesce(nullif(trim(display_name), ''), split_part(target_email, '@', 1), 'Guru'),
    'teacher'
  )
  on conflict (id) do update
    set role = 'teacher',
        full_name = coalesce(nullif(trim(display_name), ''), public.profiles.full_name);

  return v_id;
end;
$$;

revoke all on function public.promote_user_to_teacher(text, text)
  from public, anon, authenticated;

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
grant execute on function public.join_active_session(text, text, text)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- learning_sessions
-- ---------------------------------------------------------------------------
drop policy if exists sessions_select_active on public.learning_sessions;
create policy sessions_select_active on public.learning_sessions
  for select to anon, authenticated
  using (status = 'active');

drop policy if exists sessions_teacher_select on public.learning_sessions;
create policy sessions_teacher_select on public.learning_sessions
  for select to authenticated
  using (
    teacher_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

drop policy if exists sessions_teacher_insert on public.learning_sessions;
create policy sessions_teacher_insert on public.learning_sessions
  for insert to authenticated
  with check (
    public.is_teacher_or_admin()
    and teacher_id = (select auth.uid())
  );

drop policy if exists sessions_teacher_update on public.learning_sessions;
create policy sessions_teacher_update on public.learning_sessions
  for update to authenticated
  using (
    teacher_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  )
  with check (
    teacher_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

-- ---------------------------------------------------------------------------
-- Student join via RPC only (drop direct anon inserts on groups/members)
-- ---------------------------------------------------------------------------
drop policy if exists groups_insert_active_session on public.groups;

drop policy if exists groups_select_teacher on public.groups;
create policy groups_select_teacher on public.groups
  for select to authenticated
  using (public.is_session_teacher(session_id));

drop policy if exists group_members_insert_active_session on public.group_members;

drop policy if exists group_members_select_teacher on public.group_members;
create policy group_members_select_teacher on public.group_members
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists answers_select_teacher on public.answers;
create policy answers_select_teacher on public.answers
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists answers_update_teacher_review on public.answers;
create policy answers_update_teacher_review on public.answers
  for update to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  )
  with check (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists answers_update_active_session on public.answers;
create policy answers_update_active_session on public.answers
  for update to anon
  using (public.group_in_active_session(group_id))
  with check (public.group_in_active_session(group_id));

drop policy if exists mission_progress_select_teacher on public.mission_progress;
create policy mission_progress_select_teacher on public.mission_progress
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists conclusions_select_teacher on public.investigation_conclusions;
create policy conclusions_select_teacher on public.investigation_conclusions
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists station_attempts_select_teacher on public.station_attempts;
create policy station_attempts_select_teacher on public.station_attempts
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists observation_select_teacher on public.observation_records;
create policy observation_select_teacher on public.observation_records
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists student_questions_select_teacher on public.student_questions;
create policy student_questions_select_teacher on public.student_questions
  for select to authenticated
  using (
    exists (
      select 1 from public.groups g
      where g.id = group_id and public.is_session_teacher(g.session_id)
    )
  );

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check (
    (select auth.uid()) = id
    and role = (select p.role from public.profiles p where p.id = (select auth.uid()))
  );
