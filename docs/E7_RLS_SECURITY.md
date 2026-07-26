# E7-01 — RLS Security (Active-Session Scope)

Tanggal: 2026-07-26  
Project: Cell Forensic

## Goal

Replace MVP `USING (true)` / `WITH CHECK (true)` write policies with predicates scoped to **active learning sessions**, while keeping classroom join (`CELL01`) working for the anon Flutter client.

## Migrations applied (remote)

| Version | Name |
|---|---|
| `20260726033815` | `e7_tighten_active_session_rls` |
| `20260726033840` | `e7_rls_helpers_security_invoker` |

Repo mirrors: `supabase/migrations/20260726033815_*.sql`, `20260726033840_*.sql`.  
Canonical summary also in `docs/supabase_schema.sql`.

## Access model (pilot)

| Surface | Policy |
|---|---|
| Published content (`content_versions`, `missions`, `evaluation_stations`, `questions`) | SELECT when content is `published` |
| `learning_sessions` | SELECT when `status = 'active'` (teacher CRUD via E9 policies) |
| `groups` | SELECT when session active; **anon INSERT policies dropped in E9** — join via RPC |
| `group_members` + investigation/station tables | SELECT/INSERT/UPDATE when `group_in_active_session(group_id)` |
| `profiles` | Authenticated SELECT self (`auth.uid() = id`); role gate for dashboard in E9 |
| DELETE | No anon/authenticated policies → denied |

Helpers:

- `session_is_active(uuid)` — `SECURITY INVOKER`
- `group_in_active_session(uuid)` — `SECURITY INVOKER`
- `join_active_session(code, group, leader)` — `SECURITY DEFINER` RPC (**preferred** student join path; see E9)

`RemoteSessionService` prefers RPC join (E9). Direct anon `INSERT` on `groups` / `group_members` is no longer allowed:

```dart
await client.rpc('join_active_session', params: {
  'p_join_code': 'CELL01',
  'p_group_name': 'Kelompok A',
  'p_leader_name': 'Budi',
});
```

Current auth/session model: **`docs/E9_TEACHER_AUTH.md`**.

## Verification

- Anon role can `SELECT` active `CELL01` and join via `join_active_session` (direct group INSERT blocked post-E9).
- Advisor `rls_policy_always_true` on insert/update policies: **cleared**.
- Remaining advisor WARNs: only `join_active_session` executable by anon/authenticated as `SECURITY DEFINER` — **intentional** for classroom join.

## Residual risks (document for pilot)

1. **No per-device / per-member ownership.** Any client with the anon key can read/write **all groups** inside any active session (not only their own). Acceptable for closed-classroom pilot; not production.
2. **Join-code spam.** Anon can still create groups via RPC while a session is active (input length capped in E10).
3. **Teacher dashboard auth** — shipped in **E9** (`docs/E9_TEACHER_AUTH.md`): teacher JWT + `profiles.role`; session CRUD policies. Residual: active-session anon table access remains for students.
4. **No DELETE policies** (+ E10 revoked DELETE/TRUNCATE privileges). Sync queue deletes will fail until ownership/auth is designed.
5. **Closing a session** (`status != 'active'`, typically `closed`) locks further student writes — use dashboard **Tutup Sesi** (E9).

## E10 follow-up (privilege hardening) — applied

Migration `20260726120000_e10_security_harden_privileges` (remote + repo mirror).
Epic registered as **E10** in `docs/TASK-REGISTRY.yaml`.

> Live AR upgrades + OpenAI-compatible AI proxy are epic **E11**
> (`docs/E11_AR_AI_INTEGRATION.md`) — not E10.

- Revoke `TRUNCATE` from `anon`/`authenticated` (TRUNCATE bypasses RLS — confirmed wipeable before fix).
- Hide `questions.correct_answer` / `rubric` from anon (column privileges); teachers keep full SELECT.
- Anon cannot UPDATE `answers.teacher_score` / `final_score` / `feedback`.
- Direct INSERT on `groups`/`group_members` revoked (RPC-only join); drop `group_members` UPDATE policy.
- Teacher helpers moved to schema `private` (not PostgREST-exposed).
- Flutter: dashboard key loads require teacher JWT; student answer sync uses `StudentAnswerPayload` (no teacher columns).

## Coordination (E5 / E6 / E9 / E10)

- E5 station sync must keep sending a valid `group_id` that belongs to an active session; answer writes omit teacher score columns.
- E6 dashboard requires teacher login; teachers can SELECT groups/answers even when session is closed (`private.is_session_teacher`); keys need authenticated SELECT.
- Next hardening (post-pilot): replace session-wide anon write policies with per-member ownership; keep teacher policies from E9/E10.
