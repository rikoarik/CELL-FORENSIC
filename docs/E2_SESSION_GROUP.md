# E2 — Session and Group

## Student flow (live path)

`JourneyHost` → device check → **Gabung Sesi** (join code) → **Buat Kelompok** (leader + members) → onboarding → missions…

| Task | Behaviour |
|---|---|
| E2-01 | Enter join code (default `CELL01`). Resolves via local `SessionRepository`, then remote `findActiveSession` if needed. |
| E2-02 | Create group with leader in `groupSetup`. Best-effort Supabase insert; continues offline on failure. |
| E2-03 | Add members; promote any member to leader (exactly one leader). |
| E2-04 | `PersistedSessionRepository` stores sessions/groups in `LocalDatabase`. `SessionSnapshotStore` restores active join on relaunch. |

## Key files

- `lib/features/journey/screens/intro/join_group_screen.dart` — join + group UI
- `lib/features/session/persisted_session_repository.dart` — durable session/group store
- `lib/features/session/session_snapshot_store.dart` — active student snapshot
- `lib/features/journey/journey_host.dart` — wires repository + restore
- `lib/features/session/session_view_model.dart` — still available for unit tests / thin `SessionScreen`

## Offline-first

If Supabase is unset or the network fails, join/create still succeed against the local CELL01 seed and SharedPreferences-backed `LocalDatabase`.
