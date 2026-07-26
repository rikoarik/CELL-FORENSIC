# E1 — Flutter Foundation

## Entry points

| Target | Command |
|---|---|
| Mobile (default) | `flutter run` / `flutter run -t lib/main_mobile.dart` |
| Teacher dashboard (web) | `flutter run -d chrome -t lib/main_dashboard.dart` |

## Flavors (E1-06)

```bash
flutter run --dart-define=APP_FLAVOR=dev
flutter run --dart-define=APP_FLAVOR=staging
flutter run --dart-define=APP_FLAVOR=prod
```

CI builds web dashboard with `APP_FLAVOR=staging`.

## Services bootstrap

`AppServices.ensureInitialized()` wires:
1. `AppFlavor.current`
2. `SupabaseConfig` (optional offline)
3. `SharedPreferencesStorageBackend` + `LocalDatabase`
4. `SyncQueue` + `SupabaseRemoteSyncClient`

## Design tokens

`lib/shared/design_tokens.dart` — colors, radii, spacing, dashboard breakpoint.  
`AppTheme.light` consumes these tokens.
