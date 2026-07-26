# E9 — Teacher Auth, Session CRUD & Join RPC

Tanggal: 2026-07-26  
Project: Cell Forensic

## Goal

Ship the next production slice after E0–E8:

1. Teacher email/password login; dashboard requires `profiles.role ∈ {teacher, admin}`
2. Create / activate / close `learning_sessions` from the web dashboard
3. Student join prefers `rpc('join_active_session')`; closed sessions lock writes
4. RLS: teacher policies for dashboard mutations; anon join only via RPC for **active** sessions

## Migrations (remote)

| Version | Name |
|---|---|
| `20260726110000` (MCP: `e9_teacher_auth_session_rls`) | Helpers, trigger, promote RPC, teacher policies, drop anon group inserts |
| MCP: `e9_fix_teacher_helpers_grants` | Scope `is_session_teacher` to owner/admin; revoke PUBLIC execute on internal helpers |
| `20260726120000` (MCP: `e10_security_harden_privileges`) | Revoke TRUNCATE; column locks on keys/scores; helpers → `private`; join input bounds |

Repo mirrors: `supabase/migrations/20260726110000_e9_teacher_auth_session_rls.sql`, `20260726120000_e10_security_harden_privileges.sql`

## Auth model

| Claim | Trusted? |
|---|---|
| `public.profiles.role` | **Yes** — authorization source for dashboard + RLS helpers |
| `auth.users.raw_app_meta_data.role` | Seeded by admin/SQL only (trigger reads it on signup) |
| `user_metadata` / `raw_user_meta_data` | **Never for authz** (user-editable) |

Client uses publishable/anon key + teacher JWT after login. **No service_role in Flutter.**

### Create first teacher

1. Supabase Dashboard → **Authentication → Users → Add user** (email + password, confirm email).
2. Promote via SQL (MCP `execute_sql` or SQL editor), as postgres/service role:

```sql
select public.promote_user_to_teacher('guru@sekolah.id', 'Nama Guru');
```

Or manually:

```sql
update auth.users
set raw_app_meta_data =
      coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"teacher"}'::jsonb
where lower(email) = lower('guru@sekolah.id');

insert into public.profiles (id, full_name, role)
select id, 'Nama Guru', 'teacher'
from auth.users
where lower(email) = lower('guru@sekolah.id')
on conflict (id) do update
  set role = 'teacher',
      full_name = excluded.full_name;
```

`promote_user_to_teacher` is **not** granted to `anon` / `authenticated` (SQL console / service_role only).

Self-serve dashboard sign-up is **not** exposed. New Auth users get `profiles.role = student` by default (`handle_new_user` trigger).

## Dashboard usage

```bash
flutter run -d chrome -t lib/main_dashboard.dart
```

1. Login with teacher email/password
2. **Buat Sesi** — judul, join code, content version (`v1-demo`), durasi, status draft/aktif
3. **Aktifkan** / **Tutup Sesi** — `status = active|closed`
4. Siswa join dengan kode saat sesi **active**; menutup sesi mengunci write siswa (`group_in_active_session` / RPC)

Demo seed `CELL01` remains joinable while `status = active`. `teacher_id` is null on the seed row — regular teachers cannot mutate it; create a new session or assign ownership via SQL.

## Student join

`RemoteSessionService.joinActiveSession` calls:

```dart
await client.rpc('join_active_session', params: {
  'p_join_code': code,
  'p_group_name': group,
  'p_leader_name': leader,
});
```

Direct anon `INSERT` on `groups` / `group_members` was removed. Offline local `CELL01` journey is unchanged.

## RLS summary

| Actor | Capability |
|---|---|
| Anon | SELECT active sessions + active-session student tables; `join_active_session` RPC; answer UPDATE (`answer_text`/`auto_score` only) while session active; no question keys |
| Teacher JWT | CRUD own sessions; SELECT groups/answers even when closed; teacher review UPDATE on answers (incl. scores); full `questions` SELECT |
| Admin profile | Same as teacher for all sessions (`private.is_session_teacher` admin branch) |

Helpers: `private.is_teacher_or_admin()`, `private.is_session_teacher(uuid)` — not exposed via `/rest/v1/rpc`.

## Verification

- Anon `join_active_session('CELL01', …)` — **OK** (MCP SQL)
- Direct anon `INSERT` into `groups` — blocked by RLS
- Closing a session (`status ≠ active`) blocks further student writes / join RPC

## Key files

- `lib/features/auth/teacher_auth_service.dart` — login + profile role gate
- `lib/features/auth/teacher_auth_gate.dart` — wraps dashboard
- `lib/features/dashboard/create_session_dialog.dart` — create session UI
- `lib/app/dashboard_home.dart` — activate/close + FAB
- `lib/features/session/remote_session_service.dart` — RPC-first join
- `test/app/dashboard_auth_gate_test.dart` — auth-gated fake tests

## Dashboard ownership vs RLS

`SupabaseDashboardSessionRepository.loadActiveSessions` filters client-side after RLS:

| Row | Shown? | Aktifkan / Tutup / Nilai |
|---|---|---|
| `teacher_id = auth.uid()` | Yes (any status) | Yes |
| `teacher_id` null + `active` (e.g. CELL01) | Yes (read-only) | No — banner explains |
| Other teacher's `active` session | Hidden (non-admin) | — |
| Admin profile | All visible sessions | Yes |

RLS still allows SELECT on any active session (E7 residual); the dashboard must not treat that as “my classroom.” Review updates that return 0 rows distinguish version conflict vs ownership deny.

## Residual risks

1. Session-wide anon **read/write** on active session investigation tables remains (no per-device ownership).
2. Join-code spam via RPC still possible while a session is active (input length capped in E10).
3. Demo `CELL01` has `teacher_id = null` — not owned by a teacher until reassigned; dashboard shows it read-only.
4. Advisor WARN on `join_active_session` SECURITY DEFINER executable by anon — intentional.
5. JWT `app_metadata.role` is not refreshed until token refresh; dashboard always re-checks `profiles`.
6. Authenticated non-teachers could still UPDATE answer scoring columns if a student Auth account exists (mitigate: only create teacher users, or add role-gated column privileges later).

## E10 client notes

Privilege hardening (E10) is applied; Flutter dashboard key loads / teacher review require a signed-in teacher JWT. Student `StationSync` / `StudentAnswerPayload` never write `teacher_score` / `final_score` / `feedback`. See `docs/TASK-REGISTRY.yaml` epic **E10**.
