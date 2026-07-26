# Functional Requirements

## Auth dan sesi

- FR-001 Guru/admin login dengan email.
- FR-002 Siswa dapat masuk memakai kode sesi.
- FR-003 Guru dapat membuat sesi pembelajaran.
- FR-004 Siswa dapat membuat atau bergabung ke kelompok.
- FR-005 Satu perangkat dapat mewakili satu kelompok.
- FR-006 Anggota kelompok dapat memakai akun atau nama manual.

## Device dan onboarding

- FR-010 Aplikasi memeriksa dukungan AR perangkat; pada Android pemeriksaan mencakup dukungan ARCore.
- FR-011 Jika tidak didukung, aplikasi menawarkan mode 3D.
- FR-012 Tutorial menjelaskan scan, placement, AI, logbook, dan reset.

## AR initialization

- FR-020 Kamera mendeteksi plane horizontal.
- FR-021 Pengguna mengonfirmasi posisi laboratorium.
- FR-022 Meja, Sampel A, dan Sampel B muncul.
- FR-023 Anchor harus stabil.
- FR-024 Tersedia reset scene.
- FR-025 Tracking loss tidak boleh menghapus jawaban atau progres.

## AI Assistant

- FR-030 Input teks wajib tersedia.
- FR-031 Input suara opsional.
- FR-032 Engine mengenali intent:
  - `inspect_sample_a_organel`
  - `inspect_sample_b_membrane`
  - `compare_outer_layers`
  - `request_hint`
  - `off_topic`
- FR-033 Pertanyaan ambigu tidak memicu event.
- FR-034 Respons fakta inti berasal dari konten tervalidasi.
- FR-035 Riwayat pertanyaan disimpan.

## Misi 1

- FR-040 Fokus ke Sampel A.
- FR-041 Smooth zoom ke internal sel.
- FR-042 Glow kuning pada kloroplas dan vakuola.
- FR-043 Jalankan animasi menyusut/mengempes.
- FR-044 Aktifkan form logbook Misi 1.

## Misi 2

- FR-050 Fokus ke Sampel B.
- FR-051 Zoom ke membran.
- FR-052 Tampilkan fosfolipid bilayer robek.
- FR-053 Jalankan particle system cairan.
- FR-054 Aktifkan form logbook Misi 2.

## Misi 3

- FR-060 Tampilkan kedua sampel berdampingan.
- FR-061 Highlight dinding sel.
- FR-062 Tampilkan tanda silang pada Sampel B.
- FR-063 Tampilkan panah gaya.
- FR-064 Aktifkan form logbook Misi 3.

## Logbook

- FR-070 Identitas kelompok.
- FR-071 Bentuk/gejala klinis tiap sampel.
- FR-072 Organel yang rusak.
- FR-073 Warna dan efek AR.
- FR-074 Bahan lapisan terluar.
- FR-075 Kondisi lapisan terluar.
- FR-076 Fungsi dan dampak kerusakan.
- FR-077 Autosave lokal.
- FR-078 Sinkronisasi ketika online.
- FR-079 Submission dapat dikunci dan dibuka kembali oleh guru.

## Kesimpulan

- FR-080 Identifikasi Sampel A dan alasan.
- FR-081 Identifikasi Sampel B dan alasan.
- FR-082 Hipotesis kelompok.
- FR-083 Validasi field wajib sebelum submit.

## Evaluasi POS

- FR-090 Guru memulai fase POS.
- FR-091 Sistem mendukung tiga marker.
- FR-092 PIN/manual fallback jika marker gagal.
- FR-093 Timer default 300 detik.
- FR-094 Autosave selama timer berjalan.
- FR-095 Rotasi kelompok.
- FR-096 Jawaban terkunci saat submit/waktu habis.

## Dashboard guru

- FR-100 Daftar kelompok.
- FR-101 Progress misi.
- FR-102 Pertanyaan ke AI.
- FR-103 Logbook.
- FR-104 Jawaban POS.
- FR-105 Penilaian dan feedback.
- FR-106 Export CSV.

## Admin

- FR-110 Kelola content version.
- FR-111 Kelola intent rules.
- FR-112 Kelola respons AI.
- FR-113 Kelola event sequence.
- FR-114 Kelola pertanyaan/rubrik.
- FR-115 Kelola metadata asset.


## Requirement khusus Flutter

- FR-120 Seluruh fitur UI, session, logbook, POS, dan dashboard menggunakan Flutter/Dart.
- FR-121 Akses AR harus melalui interface Dart agar plugin atau native bridge dapat diganti.
- FR-122 Platform Channel hanya digunakan untuk kemampuan AR native yang tidak tersedia atau tidak stabil di plugin Flutter.
- FR-123 Event AR mengirim state kembali ke Flutter: preparing, running, completed, failed, dan tracking_lost.
- FR-124 Flutter harus menyediakan fallback scene 3D non-AR tanpa mengubah flow misi.
- FR-125 Flutter Web menggunakan model data, validation rules, dan design tokens yang konsisten dengan aplikasi mobile.
