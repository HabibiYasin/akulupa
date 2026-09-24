# Aku Lupa

Asisten ingatan pribadi untuk Android. Ketik perintah bahasa Indonesia, periksa hasilnya, lalu simpan. Seluruh data dan pemrosesan berada di perangkat; tidak ada akun, backend, API AI, atau layanan berbayar.

Versi **0.2.0 — Phase 2**. Riwayat fitur dan batas rilis tersedia di [CHANGELOG.md](CHANGELOG.md). Tag `v0.2.0` dan `phase-2` menandai baseline fase 2; tag `v0.1.0` dan `phase-1` tetap menunjuk baseline fase 1.

## Fase 2: suara dan foto

- Tekan mic → **Mulai bicara** → **Selesai bicara** → periksa/edit hasil → **Gunakan teks** → **Bantu aku ingat**. Tidak ada penyimpanan otomatis dari hasil suara. Izin mikrofon diminta ketika mulai bicara; mengetik tetap tersedia jika izin ditolak.
- Speech memakai bahasa Indonesia dengan `onDevice: true`. Pada Android yang mendukung recognizer lokal, plugin memakai recognizer tersebut; pada perangkat lain dukungan offline bergantung layanan/paket bahasa sistem. Tidak ada API AI atau backend aplikasi, dan manifest utama tidak menambahkan izin internet. Uji mode pesawat pada HP yang akan dipakai; ketersediaan bahasa dan hasil suara tidak dijamin pada semua perangkat. Lihat [dokumentasi speech_to_text](https://pub.dev/packages/speech_to_text).
- Pada konfirmasi lokasi barang, pilih **Kamera** atau **Galeri**. Foto dikompres sebagai JPEG tanpa EXIF dengan penurunan dimensi/kualitas hingga paling besar 500 KB; foto kecil tidak diperbesar agar mencapai 100 KB. Jika gagal, pengguna dapat memilih foto lain atau menyimpan tanpa foto.
- Foto permanen disimpan di direktori privat `photos/` hanya saat **Simpan**. Membatalkan/menghapus foto dari preview tidak menulis file permanen. Jika penulisan database gagal, file baru dibersihkan. Foto melekat pada masing-masing riwayat lokasi, dengan thumbnail dan tampilan yang dapat diperbesar.
- Jika Android menghentikan proses saat kamera/galeri dibuka, hasil yang tersedia dari `retrieveLostData` ditampilkan di Beranda untuk dilengkapi nama/lokasinya. Draf teks yang belum disimpan tidak dipulihkan otomatis. Lihat [image_picker](https://pub.dev/packages/image_picker) dan [flutter_image_compress](https://pub.dev/packages/flutter_image_compress).
- Parser dikte memahami `jam sembilan pagi`, `pukul dua puluh satu`, `jam setengah sembilan pagi`, `jam sembilan kurang seperempat`, dan `sepuluh gelas`. Nama barang/lokasi seperti “buku dua” dan “laci satu” tetap utuh.

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
- Rutinitas harian/mingguan: waktu lokal, aktif/jeda, status dan progres per tanggal. Target 2–24 gelas memiliki rentang jam yang bisa diedit. Jadwal berulang native tidak dibatasi horizon beberapa hari.
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
| `Kunci rumah ada di laci` | Barang kunci rumah, lokasi laci |
| `pengen makan mie ayam hari minggu` | Pengingat Minggu terdekat; pilih jam |
| `aku ingin olahraga tiap minggu pagi` | Rutinitas Minggu, usulan 06.30 |
| `charger laptop dipinjam budi` | Barang, lokasi/status dipinjam budi |
| `minum obat tidur tiap malam` | Rutinitas harian, usulan 18.30 |
| `deadline tugas sabtu sore` | Pengingat Sabtu terdekat, usulan 15.30 |
| `jangan bangunkan aku besok pagi` | Pilih pengingat bangun besok yang dibatalkan, semua jam |
| `ga jadi makan mie ayam` | Pilih pengingat yang cocok dengan kata kunci mie ayam |
| `minggu pagi ini skip olahraga dulu` | Lewati olahraga pada Minggu terdekat saja |
| `charger laptop udah diambil` | Pilih barang; tambahkan status sudah diambil ke riwayat |
| `minum air setiap hari minimal 10 gelas` | Target 10 gelas, usulan rentang 06.00–22.00 |
| `sudah minum segelas` | Pilih rutinitas minum bertarget, tambah progres 1 gelas |

Parser mendukung jam/pukul, HH:mm/HH.mm, pagi/siang/sore/malam, hari ini/besok/lusa/kemarin, dan nama bulan Indonesia. Jam tanpa penanda memakai format 24 jam dan diberi catatan bila ambigu. Tanpa jam eksplisit, pagi diusulkan 06.30, siang 12.30, sore 15.30, malam 18.30; semua bisa diedit. Tanggal tanpa tahun yang sudah lewat memakai tahun berikutnya dengan pemberitahuan. Tanggal tidak valid/tidak dikenal dan waktu yang hilang harus dipilih manual. Reminder masa lalu dan aktivitas masa depan ditolak saat konfirmasi. Perintah tidak dikenal membuka pilihan jenis catatan dan form manual tanpa langsung menyimpan.

Pembatalan, skip, progres, dan status barang menampilkan catatan yang cocok sebelum diterapkan. Jika cocok dengan beberapa rutinitas/barang, pilih satu; pembatalan pengingat bisa memilih beberapa. Pengingat yang dibatalkan disimpan sebagai riwayat dilewati. Skip rutinitas mendukung hari ini hingga 31 hari ke depan dan tidak mematikan pengulangan berikutnya. Target gelas dibagi rata sepanjang rentang waktu pilihan; mencapai target menghentikan alarm hari itu dan hari berikutnya dimulai dari nol. Angka target berasal dari input pengguna.

Schema v2 dimigrasikan dari v1 tanpa menghapus data. Adapter `android_recurrence.dart` mempertahankan tanggal mulai pengulangan setelah skip/selesai melalui field kalender native plugin. Dependency notifikasi dipatok 22.3.1 karena API pencocokan jam/hari mengabaikan tanggal mulai; periksa kontrak native dan tes penjadwalan sebelum upgrade.

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
    speech/speech_service.dart      # pengenal suara Android dan kontrak test
    photos/photo_service.dart      # picker, kompresi, penyimpanan foto privat
  features/
    home/                           # Home dan preview/edit
    memory/                         # barang, pencarian, riwayat
    reminders/                      # repository dan UI jadwal
    habits/                         # repository dan log harian
    activity/                       # repository dan timeline
    settings/                       # personality dan izin
  shared/                           # providers dan widget reusable
test/                               # parser, scheduling, DB, UI
drift_schemas/                      # snapshot schema v1 dan v2
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
| speech_to_text | pengenalan suara sistem, bahasa Indonesia, permintaan mode offline |
| image_picker, flutter_image_compress | kamera/galeri, pemulihan hasil picker, kompresi JPEG |
| path_provider | direktori privat foto permanen |
| drift_dev, build_runner (dev) | codegen dan schema snapshot |

Versi tersimpan dalam `pubspec.lock`. Tidak ada package AI.

### Schema v2

| Tabel | Kolom |
|---|---|
| Items | id, name, normalizedName unik, createdAt, updatedAt |
| ItemLocations | id, itemId FK, location, photoPath?, createdAt |
| Reminders | id, title, scheduledAt, snoozedUntil?, status, isImportant, calendarEventId?, createdAt |
| Habits | id, title, scheduleTime menit 0–1439, repeatPattern, weekday?, targetCount, unit?, endTime?, isActive, createdAt |
| HabitLogs | id, habitId FK, date YYYY-MM-DD lokal, status, progress, completedAt?; unik habitId+date |
| ActivityLogs | id, title, description?, eventTime, createdAt |
| UserSettings | singleton id=1, personality |

`schemaVersion=2` menambahkan hari mingguan dan target/progres melalui migrasi v1 tanpa menghapus catatan lama. Foto menggunakan kolom `photoPath` yang sudah ada. Reminder disimpan sebagai instant; habit sebagai jam dinding lokal. `drift_flutter` menyimpan SQLite di direktori privat aplikasi. Upgrade berikutnya harus memiliki migrasi dan tes kompatibilitas tersendiri.

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

- Google Drive, Calendar, widget Android, reminder lokasi, pengulangan bulanan, editor umum semua catatan, dan backup/restore nyata. Pembatalan pengingat serta pembaruan status barang tersedia melalui command.
- `calendarEventId` menyiapkan integrasi Calendar fase 3. Foto tidak menjalankan OCR/pengenalan objek; nama dan lokasi tetap diisi pengguna.
- `BackupService`/`LocalBackupService` adalah **dummy** (`available: false`). Implementasi berikutnya perlu snapshot SQLite konsisten, manifest foto, dan restore atomik; jangan menyalin DB aktif tanpa memperhatikan WAL.
- Auto-backup Android dimatikan. Uninstall/clear data menghapus catatan dan belum ada pemulihan.
- Pencarian/timeline MVP memuat seluruh catatan; indeks/pagination/FTS dapat ditambahkan jika volume membesar.

## Pengujian

`flutter test` menguji intent, ambiguitas/tanggal/waktu, strict offsets, snooze, lintas hari/DST, pembatalan dan rekonsiliasi dengan fake gateway, transaksi lokasi, upsert habit, query aktivitas, settings, serta alur Home → konfirmasi → SQLite → pencarian. Pengiriman Android nyata harus diverifikasi terpisah dari unit test.

Hasil aktual dan batas verifikasi tercatat di [docs/VALIDATION_RESULTS.md](docs/VALIDATION_RESULTS.md). Preview Home pada emulator tersedia di [docs/home-emulator.png](docs/home-emulator.png).
