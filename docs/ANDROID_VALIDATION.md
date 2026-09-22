# Verifikasi Android

Checklist perangkat untuk perilaku yang tidak dibuktikan unit test:

1. Simpan barang di dua lokasi, cari lokasi lama, pastikan hasil menunjukkan lokasi terbaru dan seluruh riwayat. Restart aplikasi untuk memeriksa persistensi.
2. Buat reminder beberapa menit ke depan. Edit preview; tanggal lampau ditolak; Batal tidak menulis data.
3. Tolak notifikasi dan exact alarm. Data tetap tersimpan, banner tampil, fallback tidak crash. Izinkan melalui Settings dan sinkronkan.
4. Galak + penting: periksa waktu utama, +5, +15, +30, +60. Sudah/Lewati membatalkan semuanya. Tunda mengganti rantai dengan satu alarm sepuluh menit lagi.
5. Matikan proses tanpa force-stop dan gunakan action notifikasi. Periksa cold start menyimpan status dan membatalkan retry. Force-stop berbeda: buka kembali untuk memulihkan jadwal.
6. Reboot sebelum reminder jatuh tempo; periksa pengiriman sesudah boot. Uji juga penggantian APK tanpa clear data.
7. Selesaikan habit sebelum jadwal: hari ini batal, besok tetap aktif. Batalkan selesai untuk memulihkan jadwal hari ini jika belum lewat. Uji pergantian tanggal, jeda, dan aktifkan kembali.
8. Ubah zona waktu lalu buka aplikasi: habit mengikuti jam lokal, reminder sekali mempertahankan instant. Unit test mencakup DST New York.
9. Uji ponsel fisik dengan Doze/battery saver dan konfigurasi OEM; emulator tidak mewakili semuanya.
10. Periksa layar kecil, teks besar, keyboard, list panjang, serta TalkBack. Voice/foto belum aktif pada Phase 1.

Catat hasil aktual pada laporan validasi. Keberhasilan build/unit test tidak berarti seluruh checklist perangkat telah lulus.
