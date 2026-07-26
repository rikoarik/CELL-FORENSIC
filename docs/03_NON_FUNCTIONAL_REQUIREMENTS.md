# Non-Functional Requirements

## Performance
- Target minimal 30 FPS.
- Asset lokal tampil maksimal 5 detik setelah placement.
- Particle count adaptif.
- Texture mayoritas 1K, maksimal 2K untuk asset penting.
- Audit triangle count dan draw call untuk seluruh 30 asset.

## Reliability
- Tidak crash saat tracking hilang.
- Event AR tidak boleh berjalan ganda.
- Jawaban disimpan sebelum aplikasi masuk background.
- Submission memakai idempotency key.

## Offline
- Misi, logbook, dan POS dapat berjalan tanpa koneksi setelah content pack tersedia.
- Data disimpan pada database lokal SQLite-backed di Flutter.
- Sinkronisasi menggunakan retry.

## Security
- Supabase RLS wajib.
- Siswa hanya mengakses kelompoknya.
- Guru hanya mengakses kelas/sesinya.
- Service role key tidak boleh ada di aplikasi.
- Skor final tidak dapat diubah dari client siswa.

## Privacy
- Kamera tidak direkam.
- Audio hanya aktif saat tombol mic ditekan.
- Tidak mengunggah video kelas.
- Data siswa diminimalkan.

## Accessibility
- Semua informasi visual memiliki label teks.
- Warna bukan satu-satunya indikator.
- Ada reduce motion.
- Input teks selalu tersedia.

## Maintainability
- Event AR config-driven.
- Konten pendidikan terpisah dari kode.
- Asset mempunyai version dan checksum.
- Unit test untuk matcher, scoring, sync, dan completion guard.


## Flutter-specific

- Widget UI tidak boleh menyimpan business state permanen.
- AR renderer ditempatkan di belakang interface, bukan dipanggil langsung dari feature screen.
- Method Channel/Event Channel wajib memiliki timeout, error mapping, dan lifecycle handling.
- Native view tidak boleh menyebabkan memory leak saat route Flutter ditutup.
- Rebuild Flutter tidak boleh me-reset anchor atau event AR tanpa perintah domain.
- Dashboard Flutter Web harus diuji untuk Chrome versi sekolah yang digunakan.
