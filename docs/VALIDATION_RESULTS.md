# Hasil verifikasi — 22 September 2026

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
