create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('student','teacher','admin')),
  created_at timestamptz not null default now()
);

create table public.content_versions (
  id uuid primary key default gen_random_uuid(),
  version_code text not null unique,
  status text not null check (status in ('draft','published','archived')),
  created_at timestamptz not null default now()
);

create table public.missions (
  id uuid primary key default gen_random_uuid(),
  content_version_id uuid not null references public.content_versions(id),
  code text not null,
  title text not null,
  order_number int not null,
  sample_ref text not null,
  unique(content_version_id, code)
);

create table public.learning_sessions (
  id uuid primary key default gen_random_uuid(),
  -- Nullable until teacher auth/profile exists (demo seed CELL01).
  teacher_id uuid references public.profiles(id),
  content_version_id uuid not null references public.content_versions(id),
  title text not null,
  join_code text not null unique,
  status text not null default 'draft',
  station_duration_seconds int not null default 300,
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.learning_sessions(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique(session_id, name)
);

create table public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  profile_id uuid references public.profiles(id),
  display_name text not null,
  is_leader boolean not null default false
);

create table public.mission_progress (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  mission_id uuid not null references public.missions(id),
  status text not null default 'not_started',
  ar_mode text not null default 'arcore',
  updated_at timestamptz not null default now(),
  unique(group_id, mission_id)
);

create table public.student_questions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  mission_id uuid references public.missions(id),
  question_text text not null,
  matched_intent text,
  confidence numeric,
  ar_sequence_code text,
  created_at timestamptz not null default now()
);

create table public.observation_records (
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
  version int not null default 1,
  updated_at timestamptz not null default now()
);

create table public.investigation_conclusions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null unique references public.groups(id) on delete cascade,
  sample_a_identity text not null default '',
  sample_a_reasoning text not null default '',
  sample_b_identity text not null default '',
  sample_b_reasoning text not null default '',
  group_hypothesis text not null default '',
  status text not null default 'draft',
  submitted_at timestamptz
);

create table public.evaluation_stations (
  id uuid primary key default gen_random_uuid(),
  content_version_id uuid not null references public.content_versions(id),
  code text not null,
  title text not null,
  marker_code text,
  unique(content_version_id, code)
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  station_id uuid references public.evaluation_stations(id),
  code text not null unique,
  question_text text not null,
  question_type text not null,
  correct_answer jsonb,
  rubric jsonb,
  max_score numeric not null default 0
);

create table public.station_attempts (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  station_id uuid not null references public.evaluation_stations(id),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  submitted_at timestamptz,
  status text not null default 'active'
);

create table public.answers (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  station_attempt_id uuid references public.station_attempts(id),
  answer_text text,
  auto_score numeric,
  teacher_score numeric,
  final_score numeric,
  feedback text,
  version int not null default 1,
  updated_at timestamptz not null default now()
);

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

-- ---------------------------------------------------------------------------
-- E7-01 RLS (active-session scope for classroom pilot)
-- Migrations: e7_tighten_active_session_rls + e7_rls_helpers_security_invoker
-- Full narrative: docs/E7_RLS_SECURITY.md
-- ---------------------------------------------------------------------------

create or replace function public.session_is_active(target_session_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1 from public.learning_sessions s
    where s.id = target_session_id and s.status = 'active'
  );
$$;

create or replace function public.group_in_active_session(target_group_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select exists (
    select 1
    from public.groups g
    join public.learning_sessions s on s.id = g.session_id
    where g.id = target_group_id and s.status = 'active'
  );
$$;

revoke all on function public.session_is_active(uuid) from public;
revoke all on function public.group_in_active_session(uuid) from public;
grant execute on function public.session_is_active(uuid) to anon, authenticated;
grant execute on function public.group_in_active_session(uuid) to anon, authenticated;

-- join_active_session(code, group, leader) — SECURITY DEFINER; anon/authenticated
--   RPC for classroom join (direct INSERT on groups/members revoked in E9/E10).
--
-- E9 teacher auth (see docs/E9_TEACHER_AUTH.md):
--   private.is_teacher_or_admin() / private.is_session_teacher(uuid) — E10 moved
--     out of public PostgREST surface
--   handle_new_user trigger (role from app_metadata only; default student)
--   promote_user_to_teacher(email, name) — service/SQL only (no anon/auth EXECUTE)
--   learning_sessions: teacher INSERT/UPDATE/SELECT own rows; anon SELECT active
--   answers: teacher review UPDATE via private.is_session_teacher;
--     anon UPDATE columns exclude teacher_score/final_score/feedback (E10)
--
-- E10 privilege hardening (20260726120000):
--   REVOKE TRUNCATE from anon/authenticated (TRUNCATE bypasses RLS)
--   questions: anon SELECT without correct_answer/rubric
--   groups/group_members: no direct INSERT/UPDATE for API roles
--
-- Published content: SELECT for anon + authenticated
-- Student tables: SELECT/INSERT/UPDATE gated by session_is_active /
--   group_in_active_session for anon (active sessions only)
-- profiles: authenticated SELECT/UPDATE self (role immutable via WITH CHECK)
-- Residual: session-wide anon read/write inside any *active* session
--   (no per-device ownership until student auth / join tokens).
