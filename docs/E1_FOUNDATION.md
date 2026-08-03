# E1 — Flutter Foundation

## Entry points

| Target | Command |
|---|---|
| Mobile (default) | `flutter run` / `flutter run -t lib/main_mobile.dart` |
| Web siswa + guru | `flutter run -d chrome -t lib/main.dart` (`/` siswa, `/guru` guru) |

## Flavors (E1-06)

```bash
flutter run --dart-define=APP_FLAVOR=dev
flutter run --dart-define=APP_FLAVOR=staging
flutter run --dart-define=APP_FLAVOR=prod
```

Route `/dashboard` remains an alias for `/guru`.

## Services bootstrap

`AppServices.ensureInitialized()` wires:
1. `AppFlavor.current`
2. `SupabaseConfig` (optional offline)
3. `SharedPreferencesStorageBackend` + `LocalDatabase`
4. `SyncQueue` + `SupabaseRemoteSyncClient`

## Design tokens

`lib/shared/design_tokens.dart` — colors, radii, spacing, dashboard breakpoint.  
`AppTheme.light` consumes these tokens.
