# User Flow dan Gameplay

## Guru

```text
Login
→ Pilih kelas
→ Buat sesi
→ Atur durasi POS
→ Generate kode sesi
→ Mulai sesi
→ Pantau kelompok
→ Mulai fase POS
→ Review hasil
```

## Siswa

```text
Buka aplikasi
→ Device check
→ Masukkan kode sesi
→ Buat/gabung kelompok
→ Tutorial
→ Scan meja
→ Place laboratorium
→ Misi 1
→ Misi 2
→ Misi 3
→ Lengkapi logbook
→ Identifikasi sampel
→ Hipotesis
→ Submit investigasi
→ POS 1–3
→ Hasil sementara
```

## Interaction loop

```text
Amati
→ Tanya AI
→ Intent matcher
→ Event AR
→ Respons dan pertanyaan analisis
→ Isi logbook
→ Misi selesai
```

Jika tidak cocok:

```text
Tidak ada event
→ Hint
→ Contoh pertanyaan
→ Coba ulang
```

## State group

```text
joined
→ onboarding
→ ar_initializing
→ investigating
→ investigation_submitted
→ station_waiting
→ station_active
→ evaluation_submitted
→ reviewed
→ completed
```

## Error flow

### Tracking hilang
- Pause event.
- Minta arahkan kamera ke meja.
- Reset atau fallback setelah timeout.

### Offline
- Gameplay tetap berjalan.
- Tampilkan indikator offline.
- Queue data.

### Marker gagal
- Tampilkan panduan scan.
- Gunakan PIN POS.
