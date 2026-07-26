# E7-04 — Classroom Pilot Runbook

Tanggal: 2026-07-26  
Project: Cell Forensic  
Audience: facilitator + observer (1 class period)

## Pre-flight (T−1 day)

1. Confirm Supabase project: demo content published, `learning_sessions.join_code = CELL01`, `status = active`.
2. Build Android APK (`scripts/release_android.sh`) and install on Tier A devices (see `docs/E7_DEVICE_MATRIX.md`).
3. Deploy / serve teacher dashboard (`scripts/release_web_dashboard.sh`); open on facilitator laptop.
4. Print or display join code **CELL01** and station PINs (E5 content).
5. Wi-Fi: devices on same network; allow outbound HTTPS to Supabase.
6. Dry-run one device: join → misi 1 place → logbook line → dashboard sees group.

## Roles

| Role | Count | Responsibility |
|---|---|---|
| Facilitator (guru) | 1 | Dashboard, time boxes, unlock stations |
| Floater | 1 | Fix AR / Wi-Fi / join issues |
| Student groups | 4–8 | 2–4 siswa / kelompok |
| Observer | 1 | Fill checklist + notes (this doc) |

## Minute-by-minute script (~80 min)

| Time | Activity | Pass criteria |
|---|---|---|
| 0–5 | Intro + install check | All devices open app |
| 5–10 | Join `CELL01`, create groups | Dashboard shows N groups |
| 10–15 | Device check / AR vs fallback | Each group knows its mode |
| 15–35 | Misi 1–2 investigation + logbook | Steps advance; notes saved |
| 35–50 | Misi 3 + conclusion submit | Conclusion status submitted |
| 50–70 | POS rotation (E5) | Each group completes ≥1 station |
| 70–80 | Debrief + export | CSV or review screen OK |

## Observer checklist

- [ ] Join success rate ≥ 90% of groups
- [ ] Zero hard crashes requiring reinstall
- [ ] AR tracking recovery understood by students (or fallback used)
- [ ] Backgrounding app mid-misi does not corrupt progress
- [ ] Teacher sees groups / conclusions without refresh hack (or documents refresh)
- [ ] Station timer fairness acceptable
- [ ] Students do not invent Organel X/Y answers from Asisten (E4 guardrails)

## Incident playbook

| Symptom | Action |
|---|---|
| Join fails | Check session `active`; offline continues with local pack; note for sync gap |
| AR black screen | Switch device check → fallback 3D; reboot camera permission |
| Dashboard empty | Confirm anon key + active session; hard refresh |
| Duplicate group names | Allow; unique is `(session_id, name)` — rename locally |
| Suspected data peek across groups | Expected residual risk (E7-01); end session after class |

## After class

1. **Tutup Sesi** di dashboard (atau set `learning_sessions.status = closed`) agar write siswa terkunci (E7/E9 RLS).
2. Export scores (E6 CSV).
3. File issues with device model + tier + screenshot.
4. Mark this runbook date + pass/fail in `docs/TASK-REGISTRY.yaml` notes for E7-04.

## Pilot result log (fill in)

| Field | Value |
|---|---|
| Date | _TBD_ |
| School / class | _TBD_ |
| Devices used | _TBD_ |
| Groups completed | _TBD_ |
| Blockers | _TBD_ |
| Go / no-go for wider pilot | _TBD_ |
