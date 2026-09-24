# Changelog

## 0.3.0 — Phase 3 — 2026-09-24

- Ekspor pengingat melalui editor Kalender Android, dengan pilihan akun di aplikasi tujuan.
- Cadangan/pemulihan JSON beserta foto melalui Storage Access Framework; Drive tersedia jika provider Android terpasang. Validasi sebelum konfirmasi penggantian dan transaksi restore atomik; batas 32 MB.
- Widget Android menampilkan pengingat dan rutinitas hari ini, mengikuti perubahan data, status, snooze, serta tanggal lokal.
- Pengingat memasuki lokasi dengan geofence Google Play Services, radius 100–2000 m, izin eksplisit, jeda/aktifkan ulang, status sekali kirim, serta registrasi ulang setelah reboot.
- Schema v3 menambah PlaceReminders dan mempertahankan data v1/v2. Hasil restore menjeda lokasi dan menjadwalkan ulang alarm waktu.
- Integrasi Google masih manual lewat aplikasi Android; OAuth, sinkronisasi Calendar dua arah, dan backup Drive otomatis belum tersedia.
- Versi 0.3.0+3; tag `v0.3.0` dan `phase-3`. Tag fase sebelumnya tidak dipindahkan.

## 0.2.0 — Phase 2 — 2026-09-24

- Perbaikan lokasi dengan preposisi tergabung: “gelas diatas meja”, “kunci didalam tas”, dan variasi bawah/luar/depan/belakang/samping/sebelah/tengah. Pertanyaan serta negasi tetap tidak menjadi penyimpanan otomatis.

- Mic Android dengan permintaan mode offline bahasa Indonesia, mulai/stop/batal, pesan izin/bahasa yang tidak tersedia, dan transkripsi yang bisa diedit sebelum diproses.
- Kamera/galeri pada konfirmasi barang; JPEG maksimal 500 KB, tanpa EXIF, disimpan privat saat konfirmasi. Foto tetap mengikuti riwayat lokasi dan dapat diperbesar.
- Pemulihan hasil picker yang tersedia setelah proses Android dihentikan, dengan pengisian ulang nama/lokasi.
- Parser angka dikte pada jam dan jumlah gelas, termasuk setengah/lewat/kurang seperempat.
- Tombol kategori Barang/Pengingat/Rutinitas/Aktivitas hanya mengganti placeholder contoh, tanpa menimpa teks pengguna.
- Versi aplikasi 0.2.0+2; tag `v0.2.0` dan `phase-2`. Tag Phase 1 tidak dipindahkan.

### Perbaikan perintah dan rutinitas dalam rilis ini

- Lokasi barang: “ada di”, “berada di”, “disimpan di”, serta dipinjam/diambil/dikembalikan; pembaruan berdasarkan pilihan barang menjaga riwayat.
- Rutinitas mingguan, usulan jam yang dapat diedit, target gelas harian dan rentang pengingat.
- Pembatalan berdasarkan kata kunci/tanggal, skip satu tanggal, dan progres dengan konfirmasi catatan yang cocok.
- Form manual ketika parser belum yakin, tanpa menyimpan otomatis.
- Migrasi SQLite v1 ke v2 mempertahankan catatan lama.
- Pengulangan Android mempertahankan tanggal mulai setelah skip/selesai. Dependency notifikasi dipatok 22.3.1.

Tag Phase 1 yang sudah diterbitkan tetap menunjuk baseline semula.

## 0.1.0 — Phase 1 MVP — 2026-09-22

Rilis awal Aku Lupa untuk Android, dengan penyimpanan lokal dan parser berbasis aturan tanpa backend atau API AI.

### Fitur

- Home, navigasi, input teks universal, dan preview yang dapat diedit sebelum penyimpanan.
- Parser Indonesia untuk lokasi barang, pencarian, reminder, habit, aktivitas, dan query aktivitas terakhir.
- Kalimat pengingat sehari-hari tanpa awalan wajib: “Jumat ini aku ke psikiater jam 9”; dukungan nama hari, tanggal, waktu, dan alias “ingetin”. Informasi ambigu/tidak lengkap meminta pemeriksaan manual.
- Drift/SQLite dengan repository terpisah, model bertipe, schema v1, dan persiapan migrasi.
- Riwayat lokasi barang serta pencarian nama, lokasi terbaru, dan lokasi sebelumnya.
- Reminder lokal Android, izin notifikasi/alarm presisi, timezone, dan konfigurasi reboot receiver.
- Aksi Sudah, tunda 10 menit, dan Lewati. Mode Galak mengulang pengingat penting maksimal lima kali.
- Habit harian, jeda/aktifkan, status per tanggal, dan riwayat penyelesaian.
- Activity log, timeline, dan personality Santai/Galak yang persisten.
- Kontrak layanan untuk speech dan backup mendatang.

### Verifikasi

- Analyzer bersih dan 76 unit/widget test lulus pada implementasi Phase 1.
- APK debug berhasil dibangun dan pengiriman notifikasi/aksi Sudah saat cold start diuji di emulator.
- Detail dan batas pengujian ada di [docs/VALIDATION_RESULTS.md](docs/VALIDATION_RESULTS.md).

### Belum tersedia

Voice, foto/kompresi, backup/restore nyata, sinkronisasi Google, widget Android, reminder berbasis lokasi, serta pengulangan selain harian. Pengujian reboot dan pembatasan baterai pada ponsel fisik tetap diperlukan sebelum distribusi produksi.

Tag `v0.1.0` menandai versi aplikasi; tag `phase-1` menandai milestone yang sama. Tag yang sudah diterbitkan tidak dipindahkan: perbaikan berikutnya memakai versi baru, misalnya `v0.1.1`.
