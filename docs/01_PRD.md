# Product Requirements Document — Cell Forensic

## 1. Ringkasan

Cell Forensic adalah aplikasi pembelajaran AR berbasis Flutter yang menempatkan siswa sebagai tim penyelidik forensik sel. Siswa memindai meja, memunculkan laboratorium virtual, mengamati dua sampel sel rusak, bertanya kepada Asisten AI Lab, mengisi logbook, membuat identifikasi dan hipotesis, lalu menyelesaikan tiga pos evaluasi.

## 2. Sampel

### Sampel A — Sel Tumbuhan
- Bentuk kotak dan kaku.
- Memiliki dinding sel.
- Kloroplas menyusut.
- Vakuola raksasa mengempes.
- Kondisi tampak layu dan warna memudar.

### Sampel B — Sel Hewan
- Bentuk bulat/tidak beraturan.
- Tidak memiliki dinding sel.
- Membran fosfolipid robek.
- Cairan sel bocor keluar.
- Kondisi tampak mengkerut/kempes.

## 3. Tujuan pembelajaran

Siswa mampu:
1. Membedakan sel tumbuhan dan sel hewan.
2. Menjelaskan fungsi kloroplas dan vakuola.
3. Menjelaskan fosfolipid bilayer dan selektif permeabel.
4. Menjelaskan fungsi dinding sel dan selulosa.
5. Menganalisis dampak kerusakan struktur sel.
6. Menyusun hipotesis berdasarkan bukti visual.
7. Menerapkan konsep pada kasus ekosistem dan hewan.

## 4. Target pengguna

### Siswa
- Bergabung ke sesi.
- Membentuk kelompok.
- Menjalankan AR.
- Bertanya lewat teks/suara.
- Mengisi logbook.
- Menyelesaikan evaluasi.

### Guru
- Membuat sesi dan kelompok.
- Memantau progres.
- Meninjau jawaban.
- Memberi skor dan feedback.

### Admin
- Mengelola akun, konten, pertanyaan, rubrik, trigger, dan asset.

## 5. Platform dan Teknologi

- Flutter Mobile untuk aplikasi siswa.
- Android menjadi target MVP.
- Flutter Web untuk dashboard guru/admin.
- Supabase untuk authentication, PostgreSQL, storage, dan backend function.
- AR dijalankan melalui adapter Flutter. Implementasi dapat memakai plugin Flutter yang lolos spike atau native ARCore bridge melalui Platform Channel.
- Asset 3D GLB/GLTF memakai sekitar 30 file yang telah tersedia.
- Mode fallback menampilkan scene 3D non-AR dengan gameplay yang sama.

## 6. Scope

### In scope
- Android AR.
- Surface detection.
- Dua sampel sel.
- Tiga misi.
- AI intent/keyword trigger.
- Logbook digital.
- Identifikasi dan hipotesis.
- POS 1–3 dengan marker atau PIN fallback.
- Timer lima menit.
- Dashboard guru.
- Supabase.
- Fallback 3D non-AR.

### Out of scope MVP
- Multiplayer AR sinkron.
- iOS.
- AI generatif bebas.
- LMS integration.
- Cloud anchors.
- Penilaian esai sepenuhnya otomatis.
- Pembuatan asset 3D baru jika asset lama sudah layak.

## 7. Misi

### Misi 1
Memeriksa organel Sampel A.

Trigger intent:
`inspect_sample_a_organel`

Output:
- Smooth zoom.
- Glow kuning.
- Kloroplas menyusut.
- Vakuola mengempes.
- Prompt analisis fungsi dan dampak.

### Misi 2
Memeriksa membran Sampel B.

Trigger intent:
`inspect_sample_b_membrane`

Output:
- Zoom ke membran.
- Fosfolipid bilayer robek.
- Particle system cairan biru.
- Prompt selektif permeabel.

### Misi 3
Membandingkan lapisan luar.

Trigger intent:
`compare_outer_layers`

Output:
- Side-by-side.
- Dinding sel hijau.
- Tanda silang merah pada Sampel B.
- Panah indikator tekanan.

## 8. Evaluasi POS

### POS 1
- Identifikasi organel X dan Y.
- Dampak kerusakan massal terhadap ekosistem dan rantai makanan.

### POS 2
- Identifikasi bagian membran nomor 1 dan 2.
- Analisis zat lipofilik dan selektif permeabel.

### POS 3
- Perbedaan Sampel A dan B.
- Analisis klaim suplemen selulosa untuk kucing/anjing.

## 9. Success criteria

- Seluruh tiga misi dapat diselesaikan.
- Jawaban tidak hilang saat offline.
- Asset berjalan minimal 30 FPS pada perangkat target.
- Guru dapat melihat hasil semua kelompok.
- Kelompok dapat menyelesaikan POS dengan timer.
- Tidak ada event AR salah akibat pertanyaan ambigu.

## 10. Risiko

| Risiko | Mitigasi |
|---|---|
| Asset lama tidak kompatibel | Audit format, node, animasi, polygon, texture |
| AR tidak tersedia atau adapter gagal | Fallback 3D |
| Pertanyaan tidak dikenali | Hint dan contoh prompt |
| Internet sekolah buruk | Offline-first |
| Asset terlalu berat | LOD, texture compression, batching |
| Jawaban esai salah dinilai AI | Review guru |
