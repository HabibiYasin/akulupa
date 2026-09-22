# Aku Lupa

Asisten ingatan pribadi untuk Android. Ketik perintah bahasa Indonesia, periksa hasilnya, lalu simpan. Seluruh data dan pemrosesan berada di perangkat; tidak ada akun, backend, API AI, atau layanan berbayar.

Versi **0.1.0 — Phase 1 MVP**. Riwayat fitur dan batas rilis tersedia di [CHANGELOG.md](CHANGELOG.md). Tag `v0.1.0` dan `phase-1` menunjuk baseline Phase 1 yang sama.

## Menjalankan

Dibuat dengan Flutter **3.47.1 stable**, Dart **3.13.1**, Android SDK 36/37. Siapkan Flutter stable, Android SDK, dan lisensi (`flutter doctor`). Hubungkan Android atau jalankan emulator, lalu dari root proyek:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Target proyek: **Android**. Codegen Drift (`app_database.g.dart`) disertakan sehingga perintah di atas langsung berjalan. Jika schema berubah:

```sh
dart run build_runner build
```

APK pengujian:

```sh
flutter build apk --debug
```

Hasil di `build/app/outputs/flutter-apk/app-debug.apk`. Signing release masih memakai debug key bawaan scaffold; siapkan keystore sendiri sebelum distribusi produksi.

Kotlin incremental compilation dinonaktifkan di `android/gradle.properties` untuk menghindari kegagalan cache ketika Pub cache berada di C: dan proyek di D: pada Windows.

## Fitur Phase 1

- Home dengan input universal, contoh perintah, jadwal hari ini, dan memory terbaru. Semua perintah tulis melewati preview yang dapat diedit.
- Barang: nama ternormalisasi, banyak lokasi, timestamp, pencarian nama/lokasi/seluruh riwayat. Pencarian lokasi lama tetap menampilkan **lokasi terbaru**.
- Reminder: tanggal/jam, penting/tidak, pending/completed/skipped, notifikasi Android, Sudah, tunda 10 menit, dan Lewati.
- Galak: pengingat penting pada offset 0, 5, 15, 30, 60 menit (maksimal lima per rantai). Sudah/Lewati membatalkan seluruh rantai. Tunda menggantinya dengan satu alarm baru sepuluh menit sejak aksi.
- Habit harian: waktu lokal, aktif/jeda, selesai/batal selesai/lewati hari ini, riwayat per tanggal. Jadwal berulang native tidak dibatasi horizon beberapa hari.
- Aktivitas: waktu kejadian, query terakhir berdasarkan eventTime, timeline gabungan aktivitas dan perpindahan barang.
- Settings Santai/Galak persisten, memperbarui jadwal mendatang saat diganti.
- Berfungsi offline; manifest aplikasi release tidak meminta internet. Tidak ada data contoh yang disisipkan.

## Contoh perintah

| Input | Hasil |
|---|---|
| `Taruh kunci motor di laci meja komputer` | Preview barang dan lokasi |
| `Kunci motor di mana?` | Lokasi terbaru beserta waktunya |
| `Ingatkan besok jam 8 pagi meeting` | Preview reminder |
| `Jumat ini aku ke psikiater jam 9` | Reminder ke psikiater, Jumat pekan ini, 09:00; jam dapat diedit |
| `Besok aku kontrol ke dokter jam 2 siang` | Reminder besok 14:00 |
| `Tolong ingetin aku untuk kontrol Jumat ini 09:00` | Kalimat santai dan jam tanpa awalan jam/pukul |
| `Ingatkan tanggal 13 September 2027 ada meeting jam 2 siang` | Meeting, 13 September 2027, 14:00 |
| `Ingatkan sikat gigi setiap malam jam 9` | Habit harian 21:00 |
| `Minum obat setiap hari jam 8 pagi` | Habit harian 08:00 |
| `Tadi jam 1 sudah minum obat` | Preview aktivitas 01:00 dengan catatan ambiguitas |
| `Tadi sudah olahraga` | Aktivitas waktu sekarang |
| `Kapan terakhir olahraga?` | Aktivitas relevan terbaru |

Parser mendukung jam/pukul, HH:mm/HH.mm, pagi/siang/sore/malam, hari ini/besok/lusa/kemarin, dan nama bulan Indonesia. Jam tanpa penanda memakai format 24 jam dan diberi catatan bila ambigu. Tanggal tanpa tahun yang sudah lewat memakai tahun berikutnya dengan pemberitahuan. Tanggal tidak valid/tidak dikenal dan waktu yang hilang harus dipilih manual. Reminder masa lalu dan aktivitas masa depan ditolak saat konfirmasi. Hanya pengulangan harian didukung. Perintah tidak dikenal tidak disimpan.

Pengingat tidak harus diawali “ingatkan”: kegiatan dengan petunjuk hari/jam otomatis masuk preview. Alias “ingetin”, “ingatin”, “jangan lupa”, dan “jadwalkan” juga didukung. “Jumat ini” berarti Jumat pada pekan Senin–Minggu saat ini; hari yang sudah lewat tidak diam-diam digeser. “Jumat depan” memakai pekan berikutnya dengan catatan di preview. Nama hari tanpa “ini/depan” memakai hari terdekat mulai hari ini. “Minggu depan” tanpa hari tertentu, tanggal/hari yang bertentangan, dan waktu yang belum lengkap meminta pilihan manual. “Aku mau ke psikiater” membuka form dengan tanggal dan jam kosong. Pertanyaan dan pembatalan tidak otomatis membuat reminder. Parsing tetap memakai aturan lokal, tanpa AI/API eksternal.

## Arsitektur dan struktur

```text
UI → Riverpod + AppServices → Parser / ReminderCoordinator
                           → Repository → Drift/SQLite
                           → NotificationGateway → Android
```

Widget menangani tampilan/form; akses data, query, template personality, dan penjadwalan berada di service/repository. Model dan companion bertipe dihasilkan Drift. `CommandParser` dan `NotificationGateway` berbentuk interface agar dapat diganti dan diuji. Penulisan lokasi memakai transaksi; habit memakai unique key dan upsert. Foreign keys aktif.

```text
lib/
  main.dart                         # bootstrap
  app.dart                          # tema, navigasi, lifecycle
  core/
    app_services.dart               # orkestrasi perintah dan aksi
    models.dart                     # enum dan response template
    database/app_database.dart      # schema dan migration strategy
    database/app_database.g.dart    # generated models/companions
    parser/command_parser.dart      # interface dan parser Indonesia
    notifications/
      notification_gateway.dart     # plugin, izin, timezone
      schedule_policy.dart          # aturan murni Galak/habit/tunda
      reminder_coordinator.dart     # DB → jadwal native
    utils/dates.dart
    backup/backup_service.dart       # kontrak dan dummy eksplisit
    speech/speech_service.dart      # kontrak Phase 2
  features/
    home/                           # Home dan preview/edit
    memory/                         # barang, pencarian, riwayat
    reminders/                      # repository dan UI jadwal
    habits/                         # repository dan log harian
    activity/                       # repository dan timeline
    settings/                       # personality dan izin
  shared/                           # providers dan widget reusable
test/                               # parser, scheduling, DB, UI
drift_schemas/                      # snapshot schema v1
docs/                               # verifikasi Android
```

### Pilihan database dan dependency

Drift + SQLite dipilih karena relasi barang-lokasi dan habit-log membutuhkan transaksi, foreign key, uniqueness, dan migrasi eksplisit. Query bertipe dan stream reaktif terhubung langsung ke Riverpod. Model hasil codegen menghindari duplikasi tanpa menambah banyak lapisan. Lihat [setup resmi Drift](https://drift.simonbinder.eu/setup/).

| Dependency | Peran |
|---|---|
| flutter_riverpod | dependency injection dan state reaktif |
| drift, drift_flutter | query bertipe dan SQLite native |
| flutter_local_notifications | notifikasi, actions, alarm, reboot receiver |
| timezone, flutter_timezone | zona waktu IANA dan kalender lokal |
| intl, flutter_localizations | format dan date/time picker Indonesia |
| drift_dev, build_runner (dev) | codegen dan schema snapshot |

Versi tersimpan dalam `pubspec.lock`. Tidak ada package AI.

### Schema v1

| Tabel | Kolom |
|---|---|
| Items | id, name, normalizedName unik, createdAt, updatedAt |
| ItemLocations | id, itemId FK, location, photoPath?, createdAt |
| Reminders | id, title, scheduledAt, snoozedUntil?, status, isImportant, calendarEventId?, createdAt |
| Habits | id, title, scheduleTime menit 0–1439, repeatPattern, isActive, createdAt |
| HabitLogs | id, habitId FK, date YYYY-MM-DD lokal, status, completedAt?; unik habitId+date |
| ActivityLogs | id, title, description?, eventTime, createdAt |
| UserSettings | singleton id=1, personality |

`schemaVersion=1` dan `MigrationStrategy` disiapkan. Jalur upgrade yang belum diimplementasikan gagal secara eksplisit, tidak menghapus database. Untuk v2: tambah langkah `onUpgrade`, naikkan versi, ekspor schema baru, dan buat migration test dari snapshot v1. Reminder disimpan sebagai instant; habit sebagai jam dinding lokal. `drift_flutter` menyimpan SQLite di direktori privat aplikasi.

## Notifikasi dan batas keandalan

Konfigurasi mengikuti [dokumentasi resmi plugin](https://pub.dev/packages/flutter_local_notifications). Manifest mencakup POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, receiver jadwal/action/reboot, serta icon notifikasi yang dijaga resource shrinker. Java desugaring aktif.

1. Buka **Pengaturan → Izinkan notifikasi & alarm presisi**. Penolakan izin tidak membatalkan penyimpanan. Banner menjelaskan izin yang belum tersedia.
2. Exact alarm memakai `exactAllowWhileIdle`; tanpa izin digunakan `inexactAllowWhileIdle`. Tidak meminta full-screen atau melewati Do Not Disturb.
3. Plugin menyimpan jadwal untuk reschedule lewat boot receiver. Startup/resume merekonsiliasi database. ID deterministik menghindari duplikasi. Status selesai/dilewati tidak dijadwalkan ulang. Reminder lewat tetap terlihat di Jadwal, tidak diputar ulang saat aplikasi dibuka.
4. Aksi notifikasi **membuka aplikasi** (`showsUserInterface: true`) agar penulisan database dan pembatalan dilakukan pada satu isolate. Cold-start action diproses sebelum rekonsiliasi.
5. Zona perangkat diperbarui pada startup/resume. Habit dihitung berdasarkan kalender lokal (bukan +24 jam), termasuk DST. Reminder sekali mempertahankan instant yang dikonfirmasi. Buka aplikasi setelah mengganti zona ketika aplikasi tertutup.
6. Notifikasi habit mewakili occurrence terbaru yang sudah jatuh tempo. Aksi sebelum jam hari ini dicatat untuk hari sebelumnya; ID harian yang sama menggantikan notifikasi lama.
7. Battery saver OEM, force-stop, izin yang dicabut, atau perangkat mati dapat menunda/menghentikan alarm. Buka ulang aplikasi setelah force-stop/perubahan izin. Pengiriman tepat waktu di semua ponsel belum dapat dijamin; lihat `docs/ANDROID_VALIDATION.md`.

Jika penjadwalan gagal setelah penulisan berhasil, data tetap tersimpan dan banner meminta sinkronisasi ulang. Batas jumlah alarm beberapa OEM belum diatasi dengan antrean horizon untuk ribuan reminder.

## Belum diimplementasikan

- Speech-to-text, foto/kompresi 100–500 KB, Google Drive, Calendar, widget Android, reminder lokasi, pengulangan mingguan/bulanan, edit/hapus catatan yang sudah disimpan, backup/restore nyata. Mic berlabel “segera hadir” dan tidak meminta permission.
- `photoPath`, `calendarEventId`, dan `SpeechService` menyiapkan Phase 2/3. Offline voice kelak bergantung model bahasa perangkat.
- `BackupService`/`LocalBackupService` adalah **dummy** (`available: false`). Implementasi berikutnya perlu snapshot SQLite konsisten, manifest foto, dan restore atomik; jangan menyalin DB aktif tanpa memperhatikan WAL.
- Auto-backup Android dimatikan. Uninstall/clear data menghapus catatan dan belum ada pemulihan.
- Pencarian/timeline MVP memuat seluruh catatan; indeks/pagination/FTS dapat ditambahkan jika volume membesar.

## Pengujian

`flutter test` menguji intent, ambiguitas/tanggal/waktu, strict offsets, snooze, lintas hari/DST, pembatalan dan rekonsiliasi dengan fake gateway, transaksi lokasi, upsert habit, query aktivitas, settings, serta alur Home → konfirmasi → SQLite → pencarian. Pengiriman Android nyata harus diverifikasi terpisah dari unit test.

Hasil aktual dan batas verifikasi tercatat di [docs/VALIDATION_RESULTS.md](docs/VALIDATION_RESULTS.md). Preview Home pada emulator tersedia di [docs/home-emulator.png](docs/home-emulator.png).
