create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (length(trim(full_name)) > 0),
  role text not null check (role in ('student', 'teacher', 'admin')),
  created_at timestamptz not null default now()
);

create table if not exists public.content_versions (
  id uuid primary key default gen_random_uuid(),
  version_code text not null unique,
  status text not null check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  check ((status = 'published') = (published_at is not null) or status = 'archived')
);

create table if not exists public.missions (
  id uuid primary key default gen_random_uuid(),
  content_version_id uuid not null references public.content_versions(id) on delete cascade,
  code text not null,
  title text not null,
  order_number integer not null check (order_number > 0),
  sample_ref text not null,
  unique (content_version_id, code),
  unique (content_version_id, order_number)
);

create table if not exists public.learning_sessions (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id),
  content_version_id uuid not null references public.content_versions(id),
  title text not null,
  join_code text not null unique check (join_code ~ '^[A-Z0-9-]{4,16}$'),
  status text not null default 'draft' check (status in ('draft', 'active', 'closed')),
  station_duration_seconds integer not null default 300 check (station_duration_seconds between 30 and 7200),
  created_at timestamptz not null default now()
);

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.learning_sessions(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  device_installation_id uuid,
  created_at timestamptz not null default now(),
  unique (session_id, name),
  unique (session_id, device_installation_id)
);

create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  display_name text not null check (length(trim(display_name)) > 0),
  is_leader boolean not null default false
);
create unique index if not exists group_members_profile_group_uidx on public.group_members(group_id, profile_id) where profile_id is not null;
create unique index if not exists group_members_one_leader_uidx on public.group_members(group_id) where is_leader;

create table if not exists public.mission_progress (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  mission_id uuid not null references public.missions(id),
  status text not null default 'not_started' check (status in ('not_started', 'active', 'completed')),
  ar_mode text not null default 'arcore' check (ar_mode in ('arcore', 'fallback_3d')),
  started_at timestamptz,
  completed_at timestamptz,
  version integer not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  unique (group_id, mission_id),
  check (completed_at is null or started_at is not null)
);

create table if not exists public.student_questions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  mission_id uuid references public.missions(id),
  question_text text not null check (length(trim(question_text)) > 0),
  matched_intent text,
  confidence numeric check (confidence between 0 and 1),
  ar_sequence_code text,
  idempotency_key uuid,
  created_at timestamptz not null default now(),
  unique (group_id, idempotency_key)
);

create table if not exists public.observation_records (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  mission_id uuid references public.missions(id),
  sample_ref text not null,
  detected_structure text,
  structure_state text,
  glow_color text,
  visual_effects text[] not null default '{}',
  outer_layer_material text,
  outer_layer_condition text,
  function_analysis text,
  damage_impact text,
  version integer not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  unique (group_id, mission_id, sample_ref)
);

create table if not exists public.investigation_conclusions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null unique references public.groups(id) on delete cascade,
  sample_a_identity text not null default '',
  sample_a_reasoning text not null default '',
  sample_b_identity text not null default '',
  sample_b_reasoning text not null default '',
  group_hypothesis text not null default '',
  status text not null default 'draft' check (status in ('draft', 'submitted')),
  version integer not null default 1 check (version > 0),
  idempotency_key uuid,
  submitted_at timestamptz,
  check ((status = 'submitted') = (submitted_at is not null))
);

create table if not exists public.evaluation_stations (
  id uuid primary key default gen_random_uuid(),
  content_version_id uuid not null references public.content_versions(id) on delete cascade,
  code text not null,
  title text not null,
  marker_code text,
  unique (content_version_id, code)
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  station_id uuid not null references public.evaluation_stations(id) on delete cascade,
  code text not null,
  question_text text not null,
  question_type text not null check (question_type in ('text', 'single_choice', 'multiple_choice')),
  correct_answer jsonb,
  rubric jsonb,
  max_score numeric not null default 0 check (max_score >= 0),
  unique (station_id, code)
);

create table if not exists public.station_attempts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  station_id uuid not null references public.evaluation_stations(id),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  submitted_at timestamptz,
  status text not null default 'active' check (status in ('active', 'submitted', 'expired')),
  idempotency_key uuid,
  unique (group_id, idempotency_key),
  check (expires_at > started_at),
  check (submitted_at is null or submitted_at >= started_at)
);

create table if not exists public.answers (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  station_attempt_id uuid not null references public.station_attempts(id) on delete cascade,
  answer_text text,
  auto_score numeric check (auto_score >= 0),
  teacher_score numeric check (teacher_score >= 0),
  final_score numeric check (final_score >= 0),
  feedback text,
  version integer not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  unique (station_attempt_id, question_id)
);

create or replace function public.is_group_member(target_group_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.group_members gm where gm.group_id = target_group_id and gm.profile_id = auth.uid()) $$;

create or replace function public.is_session_teacher(target_session_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.learning_sessions s where s.id = target_session_id and s.teacher_id = auth.uid()) $$;

revoke all on function public.is_group_member(uuid) from public;
revoke all on function public.is_session_teacher(uuid) from public;
grant execute on function public.is_group_member(uuid), public.is_session_teacher(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.content_versions enable row level security;
alter table public.missions enable row level security;
alter table public.learning_sessions enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.mission_progress enable row level security;
alter table public.student_questions enable row level security;
alter table public.observation_records enable row level security;
alter table public.investigation_conclusions enable row level security;
alter table public.evaluation_stations enable row level security;
alter table public.questions enable row level security;
alter table public.station_attempts enable row level security;
alter table public.answers enable row level security;

create policy "profiles read self" on public.profiles for select to authenticated using (id = auth.uid());
create policy "published content versions read" on public.content_versions for select to authenticated using (status = 'published');
create policy "published missions read" on public.missions for select to authenticated using (exists (select 1 from public.content_versions cv where cv.id = content_version_id and cv.status = 'published'));
create policy "session teacher access" on public.learning_sessions for all to authenticated using (teacher_id = auth.uid()) with check (teacher_id = auth.uid());
create policy "groups member or teacher read" on public.groups for select to authenticated using (public.is_group_member(id) or public.is_session_teacher(session_id));
create policy "group members same group read" on public.group_members for select to authenticated using (public.is_group_member(group_id) or exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id)));

create policy "mission progress group access" on public.mission_progress for all to authenticated using (public.is_group_member(group_id) or exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id))) with check (public.is_group_member(group_id));
create policy "student questions group access" on public.student_questions for all to authenticated using (public.is_group_member(group_id) or exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id))) with check (public.is_group_member(group_id));
create policy "observations group access" on public.observation_records for all to authenticated using (public.is_group_member(group_id) or exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id))) with check (public.is_group_member(group_id));
create policy "conclusions group access" on public.investigation_conclusions for all to authenticated using (public.is_group_member(group_id) or exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id))) with check (public.is_group_member(group_id));
create policy "attempts group access" on public.station_attempts for all to authenticated using (public.is_group_member(group_id) or exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id))) with check (public.is_group_member(group_id));
create policy "answers group or teacher read" on public.answers for select to authenticated using (public.is_group_member(group_id) or exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id)));
create policy "answers group write" on public.answers for insert to authenticated with check (public.is_group_member(group_id));
create policy "answers group update" on public.answers for update to authenticated using (public.is_group_member(group_id)) with check (public.is_group_member(group_id));
create policy "answers teacher review" on public.answers for update to authenticated using (exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id))) with check (exists (select 1 from public.groups g where g.id = group_id and public.is_session_teacher(g.session_id)));
create policy "stations published read" on public.evaluation_stations for select to authenticated using (exists (select 1 from public.content_versions cv where cv.id = content_version_id and cv.status = 'published'));
create policy "questions published read" on public.questions for select to authenticated using (exists (select 1 from public.evaluation_stations es join public.content_versions cv on cv.id = es.content_version_id where es.id = station_id and cv.status = 'published'));
