# Deploy Web ke Vercel atau Netlify

Panduan ini memakai **satu build Flutter Web** untuk dua pengalaman:

- `/` — aplikasi siswa
- `/guru` — login dan dashboard guru
- `/dashboard` — alias dashboard guru

Tidak diperlukan build dashboard terpisah dan tidak diperlukan CI.

## 1. Siapkan konfigurasi Supabase

Jalankan dari root repository:

```bash
export CF_SUPABASE_URL='https://<project-ref>.supabase.co'
export CF_SUPABASE_ANON_KEY='<publishable-or-anon-key>'
```

Gunakan **publishable/anon key**, jangan pernah memakai `service_role` pada
Flutter Web.

Variabel tersebut dibaca saat proses build dan ditanam ke bundle JavaScript.
Mengubah environment variable di Vercel atau Netlify setelah `build/web`
selesai dibuat tidak akan mengubah bundle lama; build ulang dan deploy ulang.

## 2. Buat satu build web

```bash
flutter pub get
flutter build web \
  -t lib/main.dart \
  --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=SUPABASE_URL="$CF_SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$CF_SUPABASE_ANON_KEY"
```

Hasilnya berada di:

```text
build/web/
```

Pastikan file berikut tersedia:

```bash
ls -lh build/web/index.html build/web/main.dart.js
```

## 3. Deploy manual ke Vercel

Repository sudah memiliki `vercel.json` yang menunjuk `build/web` dan
me-rewrite deep link seperti `/guru` ke `index.html`.

Instal dan login Vercel CLI:

```bash
npm install -g vercel
vercel login
```

Dari root repository, deploy production:

```bash
vercel --prod
```

Jika baru pertama kali, pilih atau buat project Vercel saat diminta. Jalankan
perintah dari root repository, bukan dari dalam `build/web`, agar
`vercel.json` ikut terbaca.

Setelah selesai, uji:

```text
https://<domain-vercel>/
https://<domain-vercel>/guru
https://<domain-vercel>/dashboard
```

Refresh browser ketika berada langsung di `/guru`. Halaman harus tetap terbuka
dan tidak berubah menjadi 404.

## 4. Deploy manual ke Netlify

Repository sudah memiliki `netlify.toml` dengan publish directory `build/web`
dan fallback SPA ke `index.html`.

Instal dan login Netlify CLI:

```bash
npm install -g netlify-cli
netlify login
```

Untuk deploy pertama atau menghubungkan project lokal:

```bash
netlify deploy --dir=build/web
```

Perintah pertama membuat draft URL untuk pengujian. Jika hasilnya benar,
deploy ke production:

```bash
netlify deploy --dir=build/web --prod
```

Jalankan dari root repository agar `netlify.toml` terbaca. Setelah deploy,
uji `/`, `/guru`, `/dashboard`, dan refresh langsung pada `/guru`.

Alternatif tanpa CLI adalah menyeret folder `build/web` ke Netlify Drop.
Namun untuk memastikan fallback route `/guru` ikut diterapkan, cara CLI dari
root repository lebih disarankan.

## 5. Diagnosis login guru

Login guru menggunakan dua lapis pemeriksaan:

1. email/password harus valid di Supabase Authentication;
2. user yang sama harus memiliki baris `public.profiles` dengan role
   `teacher` atau `admin`.

Pada 3 Agustus 2026, project pilot yang menjadi default repository telah
diperiksa langsung:

- endpoint password login aktif;
- akun demo berhasil terautentikasi;
- profil akun demo ditemukan dengan role `teacher`.

Artinya, bila akun demo gagal pada situs hasil deploy, periksa apakah situs
masih menyajikan build lama atau dibangun memakai project/key Supabase lain.

### Arti pesan error

| Pesan atau gejala | Penyebab | Perbaikan |
|---|---|---|
| `Email atau kata sandi salah...` | Credential salah, email belum confirmed, atau user berada di project Supabase lain | Cek user di **Authentication > Users** pada project yang URL-nya dipakai saat build |
| `Profil guru belum ada` | User Auth ada tetapi baris `public.profiles` tidak ada | Buat/promosikan profil melalui SQL admin |
| `Akun ini bukan guru/admin` | `profiles.role` masih `student` atau role lain | Jalankan fungsi promosi guru melalui SQL admin |
| `Supabase belum dikonfigurasi` | Build tidak menerima URL/key yang valid | Build ulang memakai dua `--dart-define` di atas |
| Tombol selesai lalu kembali ke login | Auth berhasil tetapi pemeriksaan profil gagal | Periksa baris `profiles`, role, dan policy SELECT profil sendiri |
| Lokal berhasil, hosting gagal | Bundle hosting lama atau dibangun dengan konfigurasi berbeda | Hapus cache deploy bila perlu, build ulang, lalu deploy ulang `build/web` |

### Membuat atau mempromosikan akun guru

Untuk akun demo pilot, jalankan seluruh isi
[`scripts/seed_demo_teacher.sql`](../scripts/seed_demo_teacher.sql) dari SQL
Editor. Script tersebut aman diulang dan akan memperbaiki password, email
identity, metadata, serta `profiles.role` akun demo.

Untuk akun guru milik sendiri, ikuti langkah berikut.

Di Supabase Dashboard:

1. buka **Authentication > Users**;
2. buat user dengan email/password dan pastikan email dikonfirmasi;
3. buka SQL Editor sebagai admin lalu jalankan:

```sql
select public.promote_user_to_teacher(
  'guru@sekolah.id',
  'Nama Guru'
);
```

Verifikasi hasilnya:

```sql
select u.email, p.full_name, p.role
from auth.users u
left join public.profiles p on p.id = u.id
where lower(u.email) = lower('guru@sekolah.id');
```

Hasil yang benar harus menunjukkan `role = teacher` atau `role = admin`.
Fungsi promosi hanya boleh dijalankan dari SQL Editor/admin, bukan dari client
Flutter dan bukan menggunakan `service_role` di browser.

## 6. Checklist setelah deploy

- Buka `/` dan pastikan halaman siswa muncul.
- Buka `/guru` dan pastikan form login guru muncul.
- Refresh langsung pada `/guru`; tidak boleh 404.
- Login memakai user dari project Supabase yang sama dengan build.
- Pastikan `public.profiles.role` adalah `teacher` atau `admin`.
- Buka dashboard dan pastikan daftar sesi dapat dimuat.
- Jangan mengunggah atau menanam `service_role` ke bundle web.

Detail model autentikasi dan akun demo tersedia di
[`E9_TEACHER_AUTH.md`](E9_TEACHER_AUTH.md).

## Referensi resmi hosting

- [Vercel CLI deployment](https://vercel.com/docs/cli/deploying-from-cli)
- [Netlify manual deployment](https://docs.netlify.com/deploy/create-deploys/)
- [Netlify CLI manual deploy](https://docs.netlify.com/api-and-cli-guides/cli-guides/get-started-with-cli/#manual-deploys)
