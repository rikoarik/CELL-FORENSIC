# E0 — Asset Audit & Flutter AR Spike Report

Tanggal: 2026-07-26  
Project: Cell Forensic  
Device spike: Pixel 8 (Android)

## Ringkasan keputusan

| Task | Hasil |
|---|---|
| E0-01 Inventory | **21 GLB** terinventarisasi (bukan 30). CSV: `docs/asset_inventory.csv` |
| E0-02 Audit | Format OK (semua GLB). **0 animation clips**. Banyak node Blender default. 3 file `fix` (ukuran/`+`/spaces) |
| E0-03 AR spike init | Done — `ar_flutter_plugin_2`, minSdk 28, camera optional |
| E0-04 Plugin capabilities | Plane tap + anchor + load GLB lokal (via documents) **lulus**. Anim clip / marker / particle **belum** |
| E0-05 Native bridge | **Tidak diperlukan sekarang** (Strategi B ditunda) |
| E0-06 Fallback 3D | Done — `model_viewer_plus`, sequence sama dengan AR |
| E0-07 Pilih renderer | **Final MVP:** plugin AR + Model Viewer fallback |
| E0-08 Label organel/membran | Label semantik A + meja **validated**. Organel X/Y & membran 1/2 **tetap provisional** |

## Capability matrix (E0-04)

| Capability | Status | Bukti |
|---|---|---|
| Horizontal plane detection | Pass | `PlaneDetectionConfig.horizontal` + tap place |
| Stable anchor | Pass | `ARPlaneAnchor` |
| GLB loading | Pass | `fileSystemAppFolderGLB` + `GlbAssetLoader` |
| Animation clip control | Fail | Tidak ada clip di inventory |
| Material opacity / glow | Partial | Belum di-API-kan; material ada di GLB |
| Particle system | Fail | Tidak ada emitter di asset |
| Image/marker tracking | Not tested | POS memakai PIN fallback |
| Tracking recovery | Partial | Lifecycle pause ada; relocalize belum diuji ketat |
| ≥30 FPS | Pending device matrix | AllInOne 287k tris; All+Meja 516k — risiko thermal |
| Fallback 3D drag/pinch | Pass | `ModelViewer` cameraControls |

## Gap vs target “30 asset”

Dokumen awal menyebut ~30 asset. Folder aktual berisi **21 file GLB**.

Yang hilang relatif ke batch PRD (perlu modeling atau rename node):
- `chloroplast_shrinking` (hanya kloroplas utuh/solo)
- `giant_vacuole_collapsed`
- `phospholipid_bilayer_intact` / `_torn` sebagai node bernama (proxy: `RantaiProtein`)
- Marker POS 3D
- Force-arrow / highlight indicators terpisah
- Node membran bernomor 1 & 2

## Renderer final (E0-07)

```text
StudentJourney.arSupported == true
  → ar_flutter_plugin_2 (ARCore / sceneview)
else
  → model_viewer_plus (fallback_3d)
```

Native Android AR bridge **hanya** dibuka ulang jika device matrix gagal pada plane/anchor/FPS, atau jika anim clip + marker wajib untuk pilot kelas.

## Label validation (E0-08)

Kode: `lib/ar/organelle_label_map.dart`

- **Validated:** dinding sel, vakuola, nukleus, kloroplas, mitokondria, sitoplasma, sel hewan broken, rantai protein, meja, tempat uji.
- **Provisional (jangan dipakai scoring otomatis):** Organel X, Organel Y, Bagian membran 1, Bagian membran 2.

Sesuai `docs/09_LKPD_EVALUATION_SCORING.md`.
