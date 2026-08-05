# Cell Forensic

Aplikasi pembelajaran AR berbasis kelompok (Flutter): investigasi sel, asisten AI deterministik, logbook/LKPD, POS evaluasi, dan dashboard guru (Flutter Web, login teacher) dengan backend Supabase.

## Quick start

```bash
flutter pub get
dart analyze

# Siswa — Android (ARCore) / iOS (ARKit) / emulator
flutter run -t lib/main_mobile.dart

# Web siswa + guru dalam satu build
flutter run -d chrome -t lib/main.dart
```

Route web: `/` untuk siswa, `/guru` untuk dashboard guru, dan `/dashboard`
sebagai alias. Vercel/Netlify cukup men-deploy satu folder `build/web`.

Demo teacher (pilot only): email `guru@cellforensic.demo` — password & langkah login di [`docs/E9_TEACHER_AUTH.md`](docs/E9_TEACHER_AUTH.md) → **Demo credentials**.

Supabase opsional lewat dart-define (**anon/publishable saja** — jangan `service_role`):

```bash
flutter run -t lib/main_mobile.dart \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Tanpa Supabase, app memakai content pack lokal (kode demo `CELL01`).

Build APK production dengan credentials dari `.env`:

```bash
flutter build apk --release --dart-define-from-file=.env
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Docs

| Dokumen | Isi |
|---|---|
| [`docs/E8_HANDOVER.md`](docs/E8_HANDOVER.md) | Cara jalan, env, flavors, CI, residual risks, sign-off |
| [`docs/E8_ACCEPTANCE.md`](docs/E8_ACCEPTANCE.md) | Checklist acceptance vs PRD/FR + regresi |
| [`docs/E9_TEACHER_AUTH.md`](docs/E9_TEACHER_AUTH.md) | Login guru, buat/aktifkan/tutup sesi, join RPC |
| [`docs/E11_AR_AI_INTEGRATION.md`](docs/E11_AR_AI_INTEGRATION.md) | Live AR M1–M3 + AI proxy (label “E10 AR+AI” → **E11**; E10 = security) |
| [`docs/00_README.md`](docs/00_README.md) | Indeks paket requirement |
| [`docs/TASK-REGISTRY.yaml`](docs/TASK-REGISTRY.yaml) | Status epic E0–E11 |
| [`docs/E7_RELEASE.md`](docs/E7_RELEASE.md) | Release APK + web dashboard |

### AI proxy secrets (server only)

Set via Supabase Dashboard → Edge Functions → Secrets (never commit ke Flutter / git):

```bash
OPENAI_API_KEY=sk-your-key-here
OPENAI_BASE_URL=https://api.arklabs.biz.id/v1
OPENAI_MODEL=cell-forensik
```

Deploy Edge Function:

```bash
supabase functions deploy ai-assistant
```

Atau set via CLI (sudah login `supabase login`):

```bash
supabase secrets set OPENAI_API_KEY=sk-your-key-here \
  OPENAI_BASE_URL=https://api.arklabs.biz.id/v1 \
  OPENAI_MODEL=cell-forensik
```

## Flavors & CI

- `APP_FLAVOR=dev|staging|prod` (default `dev`)
- CI: `.github/workflows/ci.yml` — analyze, test, web staging; release artifacts via `workflow_dispatch`
- Scripts: `scripts/release_android.sh`, `scripts/release_web_dashboard.sh` (satu build web)
