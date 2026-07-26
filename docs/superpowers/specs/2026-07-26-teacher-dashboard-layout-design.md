# Teacher dashboard layout rework (Buat Sesi + Detail kelompok)

**Status:** Approved (user 2026-07-26)  
**Scope:** UI/layout only — no mock production data; keep repository contracts & widget keys where tests depend on them.

## Decisions

| Surface | Choice |
|---|---|
| Buat Sesi | Center sheet ~720px (not AlertDialog / not full-page wizard) |
| Detail kelompok | Desktop split view (≥900px); stack on narrow |

## Buat Sesi

- Entry: `CreateSessionDialog.show` → centered `Dialog` (max width ~720, max height ~90% viewport).
- Left: form fields (judul, kode, versi, durasi, status).
- Right: live preview card (judul, kode besar, status chip, student hint).
- Footer sticky: Batal | Buat sesi (`create-session-submit`).
- Preserve keys: `create-session-title`, `create-session-join-code`, `create-session-content-version`, `create-session-duration`, `create-session-status`, `create-session-submit`.

## Detail kelompok

- Left rail (~340px): session title + join code, members, mission progress.
- Right: tabs **Penilaian** (default) | **Kesimpulan**.
- Penilaian: pending-review summary + answer cards; existing review bottom sheet.
- Kesimpulan: status + sampel A/B + hipotesis.
- &lt;900px: summary above, tabs below (same content).
- Preserve keys: `group-detail-refresh`, `group-detail-readonly`, `review-button-*`, review sheet keys.

## Out of scope

- Large rewrite of `dashboard_home.dart` management list.
- Separate deploy URLs for guru/siswa.
