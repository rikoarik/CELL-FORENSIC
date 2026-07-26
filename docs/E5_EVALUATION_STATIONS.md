# E5 — Evaluation Stations

Tanggal: 2026-07-26  
Project: Cell Forensic

## Ringkasan

POS 1–3 offline-first di live path `JourneyHost` → `StationScreen` → `ResultsScreen`. Marker (simulasi) + PIN, timer 300 dtk, rotasi, autosave/restore snapshot, kunci jawaban saat submit/timeout.

| Task | Status | Catatan |
|---|---|---|
| E5-01 Marker & PIN | done | `Pindai Marker` simulasi + PIN fallback (FR-091/092); `MARKER-POS-1/2/3` |
| E5-02 POS 1 | done | Identifikasi struktur; PIN `1111` |
| E5-03 POS 2 | done | Analisis kerusakan; PIN `2222` |
| E5-04 POS 3 | done | Kesimpulan forensik; PIN `3333` |
| E5-05 Timer & rotasi | done | Countdown UI + `stationExpiresAt` wall-clock; rotasi POS 1→2→3 (FR-093/095/096) |
| E5-06 Autosave & submit | done | Snapshot answers/index/unlock/expiry; `StationSync` enqueue bila `remoteGroupId` |

## Persistensi

Additive fields di `SessionSnapshot`:

- `station_index`, `active_station_unlocked`
- `answers`, `submitted_station_codes`
- `station_expires_at_ms`

`StudentJourney.toSessionSnapshot` / `restoreFromSnapshot` mempertahankan stage `stations` / `results` (tidak lagi fallback ke onboarding). Timer yang sudah lewat saat restore otomatis `submitActiveStation(expired: true)`.

## Sinkronisasi

- Lokal selalu menang: `SessionSnapshotStore` via `JourneyHost` listener.
- Cloud opsional: `StationSync` → `station_attempts` / `answers` hanya jika `remoteGroupId` + `AppServices`.
- Dashboard review/scoring tetap E6.

## File kunci

- `lib/features/journey/screens/stations/station_screen.dart`
- `lib/features/journey/screens/stations/results_screen.dart`
- `lib/features/journey/student_journey.dart`
- `lib/features/journey/station_sync.dart`
- `lib/features/session/session_snapshot_store.dart`
- `lib/features/content/local_content_pack.dart`

## Gap untuk E6 / E7

- E6: tampilan jawaban POS + penilaian guru di dashboard web.
- E7: RLS `station_attempts`/`answers`, device matrix marker fisik (bukan simulasi).
