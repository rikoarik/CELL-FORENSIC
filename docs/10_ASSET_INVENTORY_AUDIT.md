# Asset Inventory dan Audit

## Status (E0-01 / E0-02 — selesai 2026-07-26)

| Metrik | Nilai |
|---|---|
| File GLB di disk | **21** (target dokumen awal ~30) |
| Format | 100% GLB |
| Animation clips | **0** di semua file |
| Embedded images/textures | **0** (warna via material) |
| Status `ready` | 16 |
| Status `fix` | 5 |
| Status `rebuild` | 0 |

Sumber data:
- CSV lengkap: [`docs/asset_inventory.csv`](./asset_inventory.csv)
- Manifest Dart: `lib/ar/ar_asset_manifest.dart`
- Spike report: [`docs/E0_AR_SPIKE_REPORT.md`](./E0_AR_SPIKE_REPORT.md)

## Mapping konseptual → file aktual

| asset_code (dokumen) | File / status |
|---|---|
| forensic_lab_table | `Meja/MejaLab.glb` — ready |
| plant_cell_sample_a | `SelTumbuhanRework_AllInOne.glb` — fix (287k tris) |
| animal_cell_sample_b | `SelHewanBroken.glb` — ready (node Cube/Plane) |
| cell_wall_layer | `DindingSel.glb` / `DindingSel_Solo.glb` — ready |
| chloroplast_intact | `Kloroplas.glb` / `KlooroPlas_Solo.glb` — ready |
| chloroplast_shrinking | **missing** |
| giant_vacuole_intact | `vakuola Main.glb` / `VakolaMain_Solo.glb` — solo ready |
| giant_vacuole_collapsed | **missing** |
| phospholipid_bilayer_* | **missing nodes** — proxy `RantaiProtein.glb` |
| organel X/Y numbered | **provisional** — lihat E0-08 |
| membrane parts 1/2 | **provisional** — tidak ada node bernomor |

## Temuan audit (E0-02)

### Format & texture
- Semua asset GLB valid (chunk JSON terbaca).
- Tidak ada texture image tertanam — cocok untuk ukuran, kurang untuk detail PBR fotoreal.

### Polygon
- Ringan: meja, dinding, vakuola solo (<5k tris).
- Sedang: sel hewan, kloroplas solo, nukleus solo.
- Berat: `AllInOne` (~288k), `All+Meja` (~516k) → preload selektif, jangan keduanya bersamaan.

### Node & pivot
- Node semantik stabil: `DindingSel`, `Vakuola Main`.
- Mayoritas node masih nama Blender (`Cube.*`, `Sphere.*`, `Plane.*`) → sulit glow/target per organel tanpa solo GLB.
- Pivot/scale: belum diukur di device; treat `unknown` sampai placement QA.

### Animation
- **Tidak ada clip** di inventory → sequence engine memakai **swap model + camera orbit**, bukan `playAnimation`.

### Filename
Hindari di Model Viewer / URL asset:
- `SelTumbuhanRework_All+Meja.glb`
- `SelHewanBroken+Meja.glb`
- `vakuola Main.glb`, `vakuola Kecil.glb`

## Integrasi Flutter

Wiring runtime: `lib/ar/ar_asset_registry.dart` (misi → path).  
Inventory lengkap: `ArAssetManifest.allAssets`.  
Label organel: `lib/ar/organelle_label_map.dart`.

Field yang dipakai:
- `flutter_asset_path`
- `supported_renderer` = `ar_plugin` + `fallback_3d`
- `preload_group` = `lab` | `sample_a` | `sample_a_solo` | `sample_b` | `sample_b_detail`
- `status` = ready/fix

## Keputusan setelah audit

| Status | Asset |
|---|---|
| READY | 16 file (meja, solo organel, SelHewanBroken, DindingSel, …) |
| FIX | AllInOne (tris), All+Meja (size+tris+`+`), file dengan spasi/`+` |
| REBUILD | — |
| MISSING | shrinking chloroplast, collapsed vacuole, numbered membrane, POS markers |

## Node map minimum (target vs aktual)

```text
ROOT_LAB          → MejaLab / TempatUji
SAMPLE_A          → SelTumbuhanRework_AllInOne
A_CELL_WALL       → DindingSel ✅
A_CHLOROPLAST     → KlooroPlas_Solo ✅ (bukan node di AllInOne)
A_VACUOLE         → Vakuola Main ✅
SAMPLE_B          → SelHewanBroken ✅
B_MEMBRANE        → provisional (Cube/Plane)
B_BILAYER         → RantaiProtein (proxy) ⚠️
B_LEAK_ORIGIN     → missing
```
