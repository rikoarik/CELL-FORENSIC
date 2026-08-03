# E7-05 — Release Android APK & Flutter Web Dashboard

Tanggal: 2026-07-26  
Project: Cell Forensic

## Prerequisites

```bash
flutter pub get
dart analyze
flutter test
```

Provide Supabase publishable (anon) values — **never** `service_role`:

```bash
export SUPABASE_URL='https://<project>.supabase.co'
export SUPABASE_ANON_KEY='<anon-or-publishable-key>'
```

## Android APK (student app)

```bash
./scripts/release_android.sh
# or:
flutter build apk \
  -t lib/main_mobile.dart \
  --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Artifact: `build/app/outputs/flutter-apk/app-release.apk`

Sideload via `adb install -r …` for pilot devices. Play Store / internal track is out of scope for this checklist.

## Flutter Web terpadu (student + teacher)

```bash
./scripts/release_web_dashboard.sh
# or:
flutter build web \
  -t lib/main.dart \
  --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Artifact: `build/web/` — satu artifact untuk route siswa `/` dan guru `/guru`
(`/dashboard` adalah alias). Host harus me-rewrite route yang tidak cocok ke
`index.html`; konfigurasi Vercel dan Netlify tersedia di root repository.

## CI notes (`.github/workflows/ci.yml`)

| Job | What it does | Secrets |
|---|---|---|
| `analyze_and_test` | `dart analyze`, `flutter test`, staging web build | None required (offline fallback) |
| `release_artifacts` (`workflow_dispatch`) | Release APK + web with dart-defines from secrets | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |

CI **does not** run device matrix / ARCore. Upload of APK/web artifacts is via `actions/upload-artifact` on manual dispatch — wire CDN deploy separately when ready.

## Post-release smoke

1. Install APK → join `CELL01` → open misi 1.
2. Open hosted `/guru` → active session + groups visible.
3. Confirm browser network tab uses anon key only.
