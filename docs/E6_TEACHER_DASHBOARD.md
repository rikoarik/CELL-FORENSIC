# E6 — Flutter Web Teacher Dashboard

## Entry

```bash
flutter run -d chrome -t lib/main_dashboard.dart
```

UI copy is Indonesian (`Ringkasan Sesi`, `Ekspor CSV`, `Nilai esai`, …).

## Tasks

| Task | Behaviour |
|---|---|
| E6-01 | `DashboardHome` lists active `learning_sessions` + groups; shows pending-review count; responsive sidebar layout. |
| E6-02 | Tapping a group opens `GroupDetailScreen`: members, mission progress, investigation conclusion, POS answers. |
| E6-03 | Each answer is scored with `ScoringEngine` (objective auto-score; essays require teacher review). Teacher saves score + feedback via optimistic `version` update. |
| E6-04 | Per-session **Ekspor CSV** builds RFC-style CSV (`DashboardCsvExporter`); downloads on web, clipboard fallback elsewhere. |

## Key files

- `lib/main_dashboard.dart` — web entry
- `lib/app/dashboard_home.dart` — session overview + CSV + navigation
- `lib/features/dashboard/group_detail_screen.dart` — group drill-down + review sheet
- `lib/features/dashboard/dashboard_session_repository.dart` — Supabase + `FakeDashboardSessionRepository`
- `lib/features/dashboard/dashboard_models.dart` — detail / export models
- `lib/features/dashboard/dashboard_csv_exporter.dart` — pure CSV builder
- `lib/domain/scoring/scoring_engine.dart` — shared scoring (no hallucination of Organel X/Y)

## Data assumptions (for E7)

Dashboard reads/writes Supabase tables when configured:

| Table | Use |
|---|---|
| `learning_sessions` | Active sessions (`status = active`) |
| `groups` / `group_members` | Overview + detail |
| `mission_progress` (+ `missions`) | Group mission status |
| `investigation_conclusions` | Conclusion draft/submitted |
| `answers` (+ nested `questions` → `evaluation_stations`) | Answers + review |
| `answers` update | Teacher review: `teacher_score`, `final_score`, `feedback`, `version = base+1` where `version = base` |

**Question type mapping:** DB check uses `text` / `single_choice` / `multiple_choice` (see foundation migration). Dashboard maps `single_choice`/`multiple_choice` → objective, `text` → essay. Also accepts `objective`/`essay` aliases.

**Auth / RLS (E9):** Dashboard requires teacher JWT + `profiles.role ∈ {teacher,admin}`. Session create/activate/close and scoring use teacher policies (`is_session_teacher`). See `docs/E9_TEACHER_AUTH.md`. OpenAPI reference: `GET /teacher/sessions/{sessionId}/overview`, `POST /teacher/answers/{answerId}/review`.

## Offline / tests

Without Supabase env, overview returns `[]` (empty state). Widget tests inject `FakeDashboardSessionRepository`.
