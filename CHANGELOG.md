# Changelog

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
