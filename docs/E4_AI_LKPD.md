# E4 — AI and Digital LKPD

Tanggal: 2026-07-26  
Project: Cell Forensic

## Ringkasan

Asisten deterministik + logbook/kesimpulan offline-first terhubung ke journey student live (`MissionScreen` / `ConclusionScreen`).

| Task | Status | Catatan |
|---|---|---|
| E4-01 Assistant chat | done | Bubble chat di misi; `AssistantView` tetap tersedia |
| E4-02 IntentMatcher | done | Per-misi rules di `local_content_pack` |
| E4-03 Controlled responses | done | Guard provisional Organel X/Y & membran 1/2; off-topic |
| E4-04 Observation logbook | done | 4 prompt/misi, autosave lokal |
| E4-05 Autosave & sync | done | Snapshot mid-misi + `SyncQueue` bila `remoteGroupId` |
| E4-06 Conclusions & hypothesis | done | Draft autosave + validasi submit + sync |

## Sinkronisasi

- Lokal selalu menang: `SessionSnapshotStore` + `StudentJourney` fields.
- Cloud opsional: `InvestigationSync` enqueue ke `observation_records` / `investigation_conclusions` hanya jika `remoteGroupId` ada dan `AppServices` terinisialisasi.
- Tanpa `service_role` di client.

## File kunci

- `lib/domain/intent_matcher.dart`
- `lib/ui/features/assistant/assistant_view_model.dart`
- `lib/features/investigation/investigation_sync.dart`
- `lib/features/session/session_snapshot_store.dart`
- `lib/features/journey/student_journey.dart`
- `lib/features/journey/screens/investigation/mission_screen.dart`
- `lib/features/journey/screens/investigation/conclusion_screen.dart`

## Gap untuk E5

Ditutup di `docs/E5_EVALUATION_STATIONS.md` — persist/restore POS + marker scan + timer/rotasi.
