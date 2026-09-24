# Hasil verifikasi

## Phase 2 — 23 September 2026

Perbaikan berikutnya: “gelas diatas meja” kini langsung membuka preview berisi nama **gelas** dan lokasi **atas meja**. Ditambahkan 22 tes untuk preposisi tergabung, pertanyaan/negasi, dan preview UI; seluruh **196 tes lulus**, analyzer bersih. APK debug diperbarui.

- Flutter analyzer bersih; **174 unit/widget test lulus**. Tes baru mencakup angka hasil dikte, stop/edit/batal suara, penolakan izin, kompresi bertahap, preview foto tanpa penulisan, keterkaitan foto dengan riwayat, serta pembersihan file jika DB gagal.
- APK debug **0.2.0+2** berhasil dibangun dan diinstal sebagai pembaruan di emulator Medium_Phone API 37; catatan lama tetap tersedia.
- Galeri Android → pilih gambar → preview kompresi → Simpan: berhasil. File JPEG permanen berukuran **140.382 byte (138 KB)** ditemukan dalam `app_flutter/photos/`.
- Setelah force-stop dan cold start, foto tetap tampil pada thumbnail dan riwayat lokasi. Mengetuk foto membuka tampilan penuh tanpa exception. [Bukti foto pada riwayat](phase2-photo-emulator.png); gambar di dalam lampiran merupakan screenshot Phase 1 yang dipakai sebagai bahan uji.
- Mic → Mulai bicara memunculkan izin rekam audio Android. Memilih “Don’t allow” menampilkan pesan izin dan tetap menyediakan isian teks, tanpa crash.
- Pengenalan ucapan nyata melalui mikrofon HP, paket bahasa offline/mode pesawat, pengambilan foto kamera fisik, dan pemulihan picker saat process death belum diuji pada perangkat fisik. Transkripsi serta pembatalan diuji melalui service palsu pada widget test; ini tidak membuktikan akurasi speech engine perangkat.
- Build masih memberi peringatan kompatibilitas Kotlin pada `flutter_timezone` dan `flutter_image_compress_common`; build Flutter stable yang digunakan tetap berhasil.

Sumber utama fase 2: `core/speech/speech_service.dart`, `core/photos/photo_service.dart`, `core/parser/spoken_numbers.dart`, dialog `features/home/voice_input.dart`, konfirmasi foto, dan `features/memory/memory_photo.dart`. Foto memakai kolom `photoPath` yang sudah ada pada schema v2.

## Pembaruan perintah bahasa sehari-hari

- `flutter analyze`: bersih. `flutter test`: **154 tes lulus**, termasuk seluruh 11 contoh pengguna, seleksi kandidat, pembatalan berdasarkan tanggal, riwayat barang, progres gelas, skip tanggal mendatang, migrasi v1→v2, dan form konfirmasi/fallback.
- APK debug dibangun, diinstal sebagai pembaruan, dan dibuka di emulator Medium_Phone API 37.
- Dari UI emulator, “minum air setiap hari minimal 10 gelas” menghasilkan 10 jadwal native `Daily`, tersebar dari 06.00 hingga 22.00. “sudah minum 10 gelas” membuka konfirmasi progres.
- “olahraga tiap minggu pagi” terdaftar native `Weekly` pada **27 September 2026 06.30**. Setelah “minggu pagi ini skip olahraga dulu” dan konfirmasi, jadwal native berubah menjadi **4 Oktober 2026 06.30**, tanpa mematikan rutinitas.
- Tanggal dan frekuensi di atas diperiksa dari cache penjadwalan Android pada emulator, bukan hanya fake gateway. Jalur native yang mempertahankan tanggal mulai memiliki tes kontrak tersendiri; plugin dipatok 22.3.1.
- Setelah force-stop lalu cold start untuk menguji pemuatan ulang, Jadwal tetap menampilkan **10/10 gelas hari ini**, dan alarm olahraga tetap **4 Oktober 2026 06.30 Weekly**.
- Pengiriman jadwal mingguan hingga tanggal tersebut, perilaku reboot/Doze, dan ponsel fisik belum diuji pada pembaruan ini. Bukti pengiriman notifikasi Phase 1 di bawah tetap merupakan pengujian terpisah.

## Baseline Phase 1

Lingkungan: Windows, Flutter 3.47.1 stable, Dart 3.13.1, emulator Android Medium_Phone API 37.

| Pemeriksaan | Hasil |
|---|---|
| `flutter pub get` | Berhasil |
| `flutter analyze` | No issues found |
| `flutter test` | 76 pengujian lulus, termasuk regresi pengingat bahasa sehari-hari |
| `flutter build apk --debug` | Berhasil |
| APK diinstall dan dibuka pada emulator | Berhasil; Home tampil tanpa exception startup |
| Alur Home → preview → simpan → cari → riwayat | Lulus widget test dengan SQLite in-memory |
| Layout 360×800 dengan skala teks 1,4 | Lulus, tanpa overflow |
| Penjadwalan native Android | Alarm terdaftar di AlarmManager sebagai RTC_WAKEUP dengan exact permission |
| Pengiriman ketika proses aplikasi sudah dihentikan | Berhasil; reminder uji pukul 10:52 muncul dengan tiga action setelah `am kill` (bukan force-stop) |
| Action Sudah dari notifikasi, cold start | Berhasil; membuka aplikasi dan memindahkan reminder ke kelompok Selesai & dilewati |

Pengujian otomatis meliputi parser tujuh intent, waktu/tanggal invalid dan ambigu, batas lima pengingat Galak, snooze, cancel/reconcile, habit lintas hari dan DST, repository, serta alur UI.

Perbaikan parser berikutnya pada 22 September: kalimat “Jumat ini aku ke psikiater jam 9” menghasilkan pengingat “ke psikiater”, 25 September 2026, 09:00 untuk acuan waktu pada screenshot. Ditambahkan 24 test parser dan satu widget test yang memastikan preview muncul dan tombol Batal tidak menyimpan reminder. Analyzer kembali bersih. Bukti notifikasi/emulator di bawah berasal dari verifikasi Phase 1; pembaruan parser diuji melalui unit/widget test.

APK debug: `build/app/outputs/flutter-apk/app-debug.apk`.

Bukti emulator: [notifikasi](notification-emulator.png), [status selesai](completed-emulator.png), dan [Home](home-emulator.png). Izin notifikasi dan exact alarm diberikan pada emulator khusus pengujian. Data uji hanya berada pada emulator, tidak disisipkan dalam aplikasi.

Build menghasilkan peringatan kompatibilitas Kotlin lama pada dependency `flutter_timezone`; tidak menggagalkan build Flutter stable yang dipakai. Upgrade Flutter berikutnya perlu memeriksa versi plugin tersebut. Kotlin incremental compilation dimatikan karena cache plugin dan workspace berada pada drive Windows berbeda.

Belum diverifikasi penuh: ponsel fisik berbagai OEM, Doze/battery saver, pengiriman seluruh rantai Galak selama 60 menit, serta reschedule setelah reboot. Checklist lanjutan ada di [ANDROID_VALIDATION.md](ANDROID_VALIDATION.md). Unit test fake gateway tidak dianggap bukti pengiriman pada semua perangkat.
