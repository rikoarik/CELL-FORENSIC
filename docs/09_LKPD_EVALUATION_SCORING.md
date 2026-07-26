# LKPD dan Scoring

## Form identitas
- Nama kelompok.
- Sekolah.
- Kelas.
- Anggota.
- Guru.
- Sesi.

## Pengamatan internal

Per sampel:
- Bentuk/gejala.
- Struktur yang diamati.
- Kondisi.
- Glow.
- Efek.
- Fungsi.
- Dampak kerusakan.

## Lapisan terluar

Per sampel:
- Nama lapisan.
- Bahan penyusun.
- Kondisi.
- Fungsi.
- Dampak.

## Kesimpulan

### Sampel A
- Identitas.
- Alasan berdasarkan dinding sel.
- Alasan berdasarkan organel.

### Sampel B
- Identitas.
- Alasan berdasarkan bentuk dan lapisan.

### Hipotesis
Satu paragraf berbasis bukti.

## Bobot rekomendasi

| Komponen | Bobot |
|---|---:|
| Data laboratorium | 25 |
| Identifikasi sampel | 15 |
| Hipotesis | 10 |
| POS 1 | 15 |
| POS 2 | 20 |
| POS 3 | 15 |
| Total | 100 |

## Catatan kunci

- Organel X/Y belum boleh ditetapkan sebelum asset final dikonfirmasi.
- Bagian nomor 1/2 pada membran belum boleh ditetapkan sebelum diagram final dikonfirmasi.

### Status validasi E0-08 (2026-07-26)

Sumber: `lib/ar/organelle_label_map.dart` + `docs/E0_AR_SPIKE_REPORT.md`.

- **Boleh dipakai di UI/logbook:** dinding sel, vakuola, nukleus, kloroplas, mitokondria, sitoplasma, sel hewan rusak, rantai protein (proxy membran), meja lab.
- **Tetap provisional (jangan auto-score):** `ORGANELLE_X`, `ORGANELLE_Y`, `B_MEMBRANE_PART_1`, `B_MEMBRANE_PART_2` — tidak ada node/file semantik di GLB.
- Esai harus dapat direview guru.
- AI hanya memberikan skor saran.
