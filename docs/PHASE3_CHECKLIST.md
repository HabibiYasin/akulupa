# Pemeriksaan fase 3

Versi aplikasi 0.3.0+3. Pasang APK terbaru dengan `flutter run` atau instal `build/app/outputs/flutter-apk/app-debug.apk`. Perubahan Kotlin/manifest memerlukan build ulang, bukan hot reload.

## Kalender

1. Buat pengingat bertanggal dan jam, misalnya kontrol psikiater.
2. Jadwal → menu pengingat → Buka di Kalender. Periksa judul, tanggal, jam, zona waktu, dan durasi.
3. Pilih akun Google lalu simpan di aplikasi Kalender. Buka Google Calendar untuk memeriksanya.
4. Ulangi lalu batalkan editor: tidak ada acara baru yang tersimpan. Aku Lupa tidak menandai pengingat selesai.
5. Perubahan/pembatalan pengingat Aku Lupa tidak mengubah acara Kalender yang sudah diekspor. Jangan ekspor berulang jika tidak ingin acara ganda.

## Cadangan dan pemulihan

1. Siapkan barang dengan foto dan riwayat lokasi, pengingat, rutinitas dengan progres, aktivitas, dan pengingat lokasi.
2. Pengaturan → Cadangan & pemulihan → Buat cadangan. Coba penyimpanan perangkat dan Drive bila muncul pada menu pemilih file. Batalkan pemilih: data tetap utuh.
3. Tambahkan catatan uji baru. Pilih file melalui Pulihkan dari file; periksa jumlah/tanggal lalu **Batal**. Catatan uji tetap ada.
4. Pulihkan lagi dan setujui penggantian. Catatan uji hilang; isi, foto, riwayat, progres, dan pengaturan kembali sesuai cadangan. Lokasi dijeda.
5. Pilih JSON rusak/versi tidak didukung: data aktif tetap ada dan muncul pesan kegagalan.
6. Uji di HP lain dengan file yang sama. Cadangan tidak terenkripsi; simpan hanya di tempat yang dipercaya. Batas file 32 MB.

## Widget

1. Pengaturan → Tambahkan widget jadwal → konfirmasi launcher. Jika tidak didukung, tambahkan dari menu widget launcher.
2. Buat pengingat hari ini dan rutinitas. Pastikan widget menampilkan jam dan maksimal tiga kegiatan, dengan jumlah sisanya.
3. Selesaikan, tunda, lewati, atau jeda kegiatan di aplikasi; widget mengikuti. Ketuk widget untuk membuka Aku Lupa.
4. Periksa setelah pergantian hari, perubahan zona waktu, reboot, dan pembatasan baterai. Pembaruan periodik dikelola Android, bukan timer tepat setiap menit.

## Pengingat lokasi (perlu HP fisik untuk uji perjalanan)

1. Jadwal → Pengingat saat tiba di lokasi. Izinkan lokasi presisi, lalu izin **Sepanjang waktu**, notifikasi, dan nyalakan GPS. Google Play Services diperlukan.
2. Tambah kegiatan/label tempat. Gunakan lokasi saat ini ketika berada di tempat tujuan, atau salin lintang/bujur tujuan dari aplikasi peta. Radius awal 200 m.
3. Simpan lalu aktifkan sakelar. Jika izin ditolak/tidak lengkap, catatan tetap dijeda dan pesan menjelaskan kebutuhan izin.
4. Keluar dari radius dan masuk kembali, termasuk saat aplikasi tertutup. Tunggu beberapa menit; harus ada satu notifikasi. Buka kembali aplikasi: status sudah diingatkan dan sakelar mati.
5. Masuk lagi tanpa mengaktifkan ulang: tidak ada notifikasi kedua. Aktifkan ulang untuk penggunaan berikutnya.
6. Jeda pengingat lalu masuk area: tidak muncul notifikasi. Uji reboot, cabut izin, dan force-stop; buka ulang aplikasi setelah force-stop.
7. Uji dengan baterai hemat pada HP sasaran. Jangan mengandalkan geofence untuk pengingat darurat atau ketepatan waktu.

Pengujian tanpa akun Google tidak membuktikan unggah Drive atau penyimpanan Calendar ke akun; pengujian unit tidak membuktikan pengiriman geofence dalam perjalanan nyata. Hasil yang sudah dijalankan ada di [VALIDATION_RESULTS.md](VALIDATION_RESULTS.md).
