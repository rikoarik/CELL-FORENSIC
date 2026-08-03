# Audit Placement AR, Viewer 3D, dan Dukungan 16 KB

Tanggal audit: 1 Agustus 2026

Status akhir: **Patch library lokal dipilih.** APK, AAB, dan web release berhasil dibangun. Pemeriksaan statis APK/AAB untuk 16 KB lulus pada ABI 64-bit yang relevan, tetapi pengujian runtime AR dan 16 KB pada perangkat/emulator nyata belum dapat dilakukan karena tidak ada perangkat ADB dan executable Android Emulator tidak tersedia pada mesin ini.

# Library yang Digunakan

| Komponen | Library/versi efektif | Status |
|---|---|---|
| Flutter AR bridge | ar_flutter_plugin_2 0.0.3+cellforensic.1 dari packages/ar_flutter_plugin_2 | Fork lokal yang dipatch |
| Android scene/AR renderer | SceneView arsceneview 2.3.2 | Dipertahankan agar API bridge 2.x tetap kompatibel |
| Android renderer native | Filament 1.68.2, transitif dari SceneView 2.3.2 | Diperbarui melalui SceneView |
| Android tracking | Google ARCore 1.54.0 | Eksplisit di app dan plugin |
| Viewer web/fallback | model_viewer_plus 1.10.0 | Dipertahankan |
| WebView transitif | webview_flutter 4.14.1, webview_flutter_android 4.12.0, webview_flutter_wkwebview 3.25.1 | Dipertahankan |
| Toolchain Android | AGP 8.11.1, Gradle 8.14, Kotlin 2.2.20, compile/target SDK 36, min SDK 28, NDK 28.2.13676358 | Mendukung packaging modern |

Ringkasan audit implementasi:

- Package AR: ar_flutter_plugin_2, fork lokal.
- Versi: 0.0.3+cellforensic.1.
- Status maintenance upstream: rendah/tidak sering. Versi publik 0.0.3 sudah lama dan repositori upstream kecil; upstream tidak layak dipakai tanpa patch untuk kebutuhan ini. Referensi: [pub.dev](https://pub.dev/packages/ar_flutter_plugin_2) dan [repositori upstream](https://github.com/hlefe/ar_flutter_plugin_2).
- Native dependency: SceneView 2.3.2, Filament 1.68.2, ARCore 1.54.0. Referensi rilis SceneView: [v2.3.2](https://github.com/sceneview/sceneview/releases/tag/v2.3.2).
- Lokasi placement: lib/ar/mission_scene_panel.dart, metode _onPlaneTapped.
- Lokasi normalisasi scale: lib/ar/model_placement_config.dart dan _normalizedTransformFor di mission_scene_panel.dart.
- Lokasi pembacaan model/bounds: lib/ar/glb_asset_loader.dart.
- Package viewer web: model_viewer_plus 1.10.0.

# Implementasi Placement Saat Ini

Alur placement Android setelah patch:

1. ARView meminta deteksi horizontal.
2. Bridge Android hanya menerima Plane.Type.HORIZONTAL_UPWARD_FACING yang TRACKING, tidak tersubsumsi, memiliki extent minimum 0,25 m, dan stabil setidaknya 750 ms.
3. Callback bidang stabil mengubah UI dari “Mencari permukaan” menjadi “Permukaan ditemukan”.
4. Pengguna harus mengetuk di dalam polygon bidang yang stabil. Hasil feature point dan hit di luar polygon ditolak.
5. Dart membaca pose kamera dan pose hit, kemudian menghitung jarak horizontal kamera-ke-hit.
6. Hit di bawah 1,0 m atau di atas 3,5 m ditolak. Jarak rekomendasi adalah 1,6 m.
7. Bounds GLB lengkap dibaca sebelum anchor dibuat.
8. Satu ARPlaneAnchor dibuat dari pose hit pada bidang. Model lengkap menjadi child dari anchor tersebut.
9. Scale seragam dihitung dari tinggi bounds, lalu minY dikoreksi agar dasar model tepat di Y=0 anchor.
10. Placement dikunci setelah berhasil; perpindahan hanya melalui reset eksplisit.

Scene aktif memakai GLB komposisi lengkap, bukan merakit meja dan sampel dengan offset dunia terpisah:

- assets/ar_models/scene-1.glb
- assets/ar_models/scenes/scene-misi1-kloroplas.glb
- assets/ar_models/scenes/scene-misi1-vakuola.glb
- assets/ar_models/scenes/scene-misi2-membran.glb
- assets/ar_models/scenes/scene-misi3-dinding.glb

# Penyebab Deteksi Lantai Buruk

Sebelum patch, konfigurasi “horizontal” pada Dart belum cukup ketat di native:

- Bridge tidak menjamin hanya bidang horizontal yang menghadap ke atas.
- Plane dapat diumumkan segera, sebelum tracking dan extent stabil.
- Hit non-plane/feature point dapat ikut diteruskan.
- Hit belum selalu dibatasi ke polygon bidang yang benar-benar terdeteksi.
- Kualitas tracking dan status plane tidak menjadi gerbang placement yang konsisten.

Akibatnya, dinding/meja kecil atau plane yang masih berubah dapat dianggap sebagai target placement.

# Penyebab Model Mengambang

Bounds authored GLB memiliki minY positif sekitar 0,0106598. Menempatkan origin model langsung pada anchor membuat dasar geometri berada sedikit di atas plane.

Masalah diperparah oleh bridge lama yang tidak selalu menerapkan matriks node lengkap. Translation, rotation, dan scale dari Dart dapat tereduksi menjadi perilaku helper lama seperti scaleToUnits, sehingga koreksi lantai tidak identik dengan transform yang dihitung aplikasi.

Patch menggunakan:

- baseCorrectionY = -(bounds.minY × uniformScale)
- transform = translation dasar + rotasi Y + scale seragam
- matriks transform lengkap diteruskan ke SceneView

Untuk scene utama:

- tinggi authored: 0,9983939 unit
- scale normal: 0,450723907668106
- tinggi akhir: 0,45 m
- koreksi dasar: -0,004804626710960 m

# Penyebab Scale Terlalu Besar

Implementasi lama memakai konstanta skala/scaleToUnits yang terpisah untuk meja, sampel, dan model misi. Nilai tersebut tidak berasal dari bounds GLB lengkap, sehingga model dengan ukuran authored berbeda dapat menjadi terlalu besar.

Patch menetapkan satu sumber konfigurasi:

- target tinggi normal: 0,45 m
- scale minimum: 0,20
- scale maksimum: 0,80
- formula: targetHeight / bounds.height, lalu dikalikan multiplier gesture/sequence dan di-clamp

Pada scene utama, footprint akhir normal sekitar 0,93 m × 0,57 m. Ukuran ini dipilih sebagai miniatur meja laboratorium yang tetap terbaca di layar ponsel, bukan meja berukuran nyata.

# Penyebab Placement Terlalu Dekat

Sebelum patch tidak ada validasi jarak horizontal antara kamera dan pose hit. Plane pertama atau origin fallback dapat menghasilkan objek sangat dekat dengan kamera.

Patch menghitung:

distance = sqrt((hitX - cameraX)^2 + (hitZ - cameraZ)^2)

Aturan:

- kurang dari 1,0 m: ditolak sebagai terlalu dekat
- 1,0–3,5 m: valid
- lebih dari 3,5 m: ditolak sebagai terlalu jauh
- 1,6 m: jarak rekomendasi untuk framing awal

Audit bridge juga menemukan kontrak data yang rusak: Android mengirim pose kamera sebagai map position/rotation, sedangkan Dart mengharapkan list matriks 4×4. Dampaknya getCameraPose selalu gagal diparse dan placement berhenti sebelum validasi jarak. ArView.kt sekarang mengirim camera pose dan anchor pose melalui serializePose sehingga formatnya sesuai dengan Matrix4 Dart.

# Perbaikan AR

- Membatasi deteksi ke horizontal upward-facing plane.
- Mensyaratkan plane TRACKING, tidak tersubsumsi, extent minimum, polygon valid, dan stabil 750 ms.
- Mengembalikan plane hit saja; feature point tidak dipakai untuk placement.
- Menghapus auto-place dan fallback origin/camera offset.
- Menambahkan gate tracking dan state planeReady sebelum tap diterima.
- Menambahkan validasi jarak horizontal kamera-ke-hit.
- Membuat anchor dari pose hit pada plane.
- Menjamin satu placement dan satu anchor aktif.
- Membaca bounds semua GLB lengkap, termasuk node hierarchy dan transform authored.
- Menggunakan scale seragam berdasarkan tinggi bounds.
- Menggeser minY hasil scale tepat ke bidang anchor.
- Menerapkan matriks transform node lengkap di bridge SceneView.
- Menggunakan UI scanning singkat: “Mencari permukaan...” lalu “Permukaan ditemukan”.
- Menambahkan log diagnostik AR berawalan [AR_FIX] untuk tracking, plane, hit pose, jarak, bounds, scale, koreksi dasar, transform, anchor, dan visibilitas.

# Perbaikan Web 3D Viewer

Web memakai source of truth yang sama dengan AR:

- asset scene yang sama dari ArAssetRegistry
- bounds audited yang sama
- formula scale, clamp, rotasi, dan target tinggi yang sama
- camera-target dihitung dari pusat X/Z yang sudah dirotasi dan setengah tinggi model setelah grounding
- camera-orbit, min/max camera orbit, field-of-view, dan min/max field-of-view eksplisit

Normalisasi tidak lagi bergantung pada relatedJs. Pada Flutter web, model_viewer_plus membuat elemen dengan innerHTML; script yang ditanam lewat innerHTML tidak dieksekusi oleh browser. Karena itu scale dan camera-target kini dikirim langsung sebagai atribut model-viewer sebelum model dimuat. Model Viewer akan memperhitungkan scale/orientation awal saat auto-framing, sesuai [dokumentasi resmi Model Viewer](https://modelviewer.dev/docs/index.html).

Verifikasi browser lokal pada seluruh sequence Misi 1 menunjukkan:

- scene-1 dan scene misi termuat
- model terlihat sebelum dan sesudah langkah sequence
- scale seragam berubah mengikuti multiplier sequence
- camera-target berubah konsisten bersama scale
- tidak ada warning/error browser
- contoh awal: scale 0,45072390766810577 dan camera-target 0m 0.225m 0.01067627466473903m

# Audit Native Library

APK release memuat 10 library native per ABI:

| Library .so | Asal utama |
|---|---|
| libarcore_sdk_c.so, libarcore_sdk_jni.so | Google ARCore 1.54.0 |
| libfilament-jni.so, libfilament-utils-jni.so, libgltfio-jni.so | Filament 1.68.2 melalui SceneView 2.3.2 |
| libandroidx.graphics.path.so | AndroidX Graphics Path, transitif SceneView |
| libflutter.so, libapp.so | Flutter engine dan AOT app |
| libdartjni.so | AndroidX/JNI runtime transitif |
| libdatastore_shared_counter.so | AndroidX DataStore |

ABI APK:

- arm64-v8a
- armeabi-v7a
- x86_64

Hasil ELF LOAD alignment:

| ABI | Alignment yang ditemukan | Di bawah 16 KB |
|---|---|---|
| arm64-v8a | 0x4000 dan 0x10000 | tidak ada |
| x86_64 | 0x4000 dan 0x10000 | tidak ada |
| armeabi-v7a | 0x1000, 0x4000, dan 0x10000 | dua library ARCore: libarcore_sdk_c.so dan libarcore_sdk_jni.so |

Dua ABI yang disediakan Android untuk pengujian lingkungan 16 KB adalah ARM64 dan x86_64; keduanya bersih pada audit ELF ini. Temuan 4 KB pada ARCore 32-bit tetap dicatat sebagai risiko transparan dan tidak disembunyikan.

# Hasil Validasi 16 KB

Referensi prosedur: [Panduan Android 16 KB](https://developer.android.com/guide/practices/page-sizes?hl=id) dan [zipalign Android](https://developer.android.com/tools/zipalign?hl=id).

Hasil final:

- flutter build apk --release: berhasil, 95,9 MB.
- flutter build appbundle --release: berhasil, 76,8 MB.
- flutter build web --release: berhasil.
- zipalign -c -P 16 -v 4 app-release.apk: Verification successful.
- bundletool dump config app-release.aab: PAGE_ALIGNMENT_16K.
- ELF arm64-v8a: semua LOAD segment minimal 0x4000.
- ELF x86_64: semua LOAD segment minimal 0x4000.
- adb shell getconf PAGE_SIZE: belum dijalankan karena tidak ada perangkat ADB.
- Runtime install/launch pada perangkat 16 KB: belum diverifikasi.

Kesimpulan yang aman: artefak final memenuhi pemeriksaan packaging dan ELF 16 KB untuk ABI 64-bit, tetapi belum boleh disebut “lulus runtime 16 KB” sampai APK/AAB dipasang dan alur AR dijalankan pada perangkat atau emulator yang mengembalikan PAGE_SIZE=16384.

# Keputusan Library

Keputusan: **Patch Library**.

Alasan:

- Mempertahankan upstream tanpa patch tidak aman: bridge pose, plane filtering, transform node, dan native dependencies tidak memenuhi kebutuhan.
- Migrasi penuh belum diperlukan untuk menyelesaikan masalah placement yang teridentifikasi.
- Fork lokal mempertahankan API Dart dan alur aplikasi saat ini, sehingga risiko perubahan mission flow kecil.
- SceneView 2.3.2 tetap kompatibel dengan API bridge 2.x dan membawa Filament 1.68.2 yang lulus audit ABI 64-bit.
- ARCore 1.54.0 dan toolchain Android modern berhasil dibuild.

Pemicu migrasi di masa depan:

- kegagalan runtime berulang pada perangkat ARCore yang tidak dapat diperbaiki di bridge lokal
- kebutuhan API SceneView 4.x atau lifecycle baru
- beban pemeliharaan fork lebih besar daripada membuat bridge baru
- library native baru kembali gagal pada pengujian 16 KB

Jika pemicu itu terjadi, migrasikan lapisan native secara terisolasi di belakang API Dart ARView/manager yang sekarang; jangan mengubah mission flow, navigation, atau model data.

# File yang Diubah

File utama dalam patch AR/3D:

- android/app/build.gradle.kts
- android/app/src/main/AndroidManifest.xml
- android/app/src/main/res/xml/network_security_config.xml
- pubspec.yaml
- pubspec.lock
- packages/ar_flutter_plugin_2/pubspec.yaml
- packages/ar_flutter_plugin_2/android/build.gradle
- packages/ar_flutter_plugin_2/android/src/main/kotlin/com/uhg0/ar_flutter_plugin_2/ArView.kt
- packages/ar_flutter_plugin_2/android/src/main/kotlin/com/uhg0/ar_flutter_plugin_2/Serialization/Serializers.kt
- packages/ar_flutter_plugin_2/lib/managers/ar_session_manager.dart
- lib/ar/glb_asset_loader.dart
- lib/ar/model_placement_config.dart
- lib/ar/mission_scene_panel.dart
- test/ar/model_placement_config_test.dart
- AR_PLACEMENT_AND_16KB_REPORT.md

Perubahan lain yang sudah ada di worktree, seperti .env.example dan konfigurasi Supabase, tidak disentuh sebagai bagian audit ini.

# Hasil Pengujian Perangkat

Pengujian yang selesai:

- dart analyze: selesai; tidak ada error/warning, hanya 4 info unnecessary_const yang sudah ada di lib/ar/ar_asset_manifest.dart.
- test/ar/model_placement_config_test.dart: lulus.
- test/ar/glb_asset_loader_test.dart: lulus.
- Bounds runtime kelima GLB aktif cocok dengan bounds audited.
- Build APK release: lulus.
- Build AAB release: lulus.
- Build web release: lulus.
- Viewer web diuji interaktif sampai seluruh langkah sequence Misi 1; model tetap terlihat dan console bersih.
- Full flutter test: 276 lulus, 29 gagal.

Kegagalan full suite tidak disamarkan. Kelompok kegagalan yang terlihat:

- ekspektasi lama pada fallback asisten
- journey/station state, sinkronisasi, skor, dan snapshot
- inventory asset manifest lama
- satu ekspektasi offset fidelity lama
- dua tes Wave 5 yang tidak menemukan field input asisten

Kegagalan tersebut tidak diperbaiki karena berada di luar ruang lingkup placement/rendering atau membutuhkan keputusan flow/data. Tes placement/bounds yang ditambahkan tetap lulus.

Pengujian yang belum selesai:

- Tidak ada perangkat fisik Android/ARCore pada adb devices.
- AVD Android 36 dengan image google_apis_ps16k ARM64 terkonfigurasi, tetapi binary emulator tidak terpasang, sehingga AVD tidak dapat dijalankan.
- Tracking, deteksi lantai, kestabilan anchor, relocalization, dan visual scale di kamera nyata belum memiliki bukti runtime.
- PAGE_SIZE=16384 dan install/launch native belum memiliki bukti runtime.

# Risiko Tersisa

1. **Validasi perangkat wajib.** Packaging 16 KB bukan pengganti uji runtime. Jalankan pada perangkat ARCore nyata dan lingkungan PAGE_SIZE=16384.
2. **Fork lokal perlu dirawat.** Update ARCore, SceneView, Filament, Flutter, AGP, atau Kotlin harus diikuti build, ELF audit, dan smoke test ulang.
3. **ARCore armeabi-v7a masih 4 KB.** ABI 64-bit lulus, tetapi dua library ARCore 32-bit masih memiliki alignment ELF 0x1000.
4. **Kualitas bidang bergantung lingkungan.** Permukaan reflektif, polos, gelap, atau minim fitur tetap dapat memperlambat ARCore meskipun filter sudah benar.
5. **Bounds audited harus diperbarui saat GLB berubah.** Tes runtime sekarang akan mendeteksi mismatch, tetapi konfigurasi perlu disinkronkan sebelum rilis.
6. **Full test suite belum hijau.** Ada 29 kegagalan lama/di luar scope yang perlu backlog terpisah agar sinyal regresi proyek kembali kuat.
7. **Migrasi besar belum dilakukan.** Keputusan Patch tepat untuk masalah saat ini, tetapi bukan komitmen bahwa bridge 2.x akan layak selamanya.
