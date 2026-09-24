import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../shared/providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool busy = false;
  String? message;
  Future<void> execute(bool restore) async {
    setState(() {
      busy = true;
      message = null;
    });
    File? temporary;
    try {
      final services = ref.read(servicesProvider);
      if (restore) {
        final path = await services.integrations.openDocument();
        if (path == null) return;
        temporary = File(path);
        final preview = await services.backups.inspect(temporary);
        if (!mounted) return;
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ganti semua catatan?'),
            content: Text(
              'Cadangan ${dateTimeText(preview.createdAt.toLocal())}\n${preview.records} catatan dan ${preview.photoCount} foto.\n\nSemua catatan saat ini akan diganti. Buat cadangan dahulu jika masih dibutuhkan. Pengingat lokasi hasil pemulihan akan dijeda.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ganti & pulihkan'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
        await services.restoreBackup(preview);
        message = 'Catatan dan foto berhasil dipulihkan. Periksa jadwal dan aktifkan kembali pengingat lokasi yang dibutuhkan.';
      } else {
        temporary = await services.backups.export();
        final saved = await services.integrations.saveDocument(
          temporary.path,
          temporary.uri.pathSegments.last,
        );
        message = saved
            ? 'Cadangan berhasil disimpan ke lokasi pilihanmu.'
            : 'Penyimpanan dibatalkan.';
      }
    } catch (e) {
      message = e is PlatformException
          ? e.message
          : e is FormatException
          ? e.message
          : 'Cadangan gagal diproses. Periksa file, ruang penyimpanan, dan koneksi penyedia file, lalu coba lagi.';
    } finally {
      try {
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      } catch (_) {}
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Cadangan & pemulihan')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Simpan catatan beserta foto ke file cadangan. Pilih Drive di menu pemilih file Android untuk menyimpannya ke akun Google yang terhubung. Jika Drive tidak muncul, simpan ke perangkat lalu unggah melalui aplikasi Drive.\n\nCadangan dibuat manual, maksimal 32 MB. File berisi catatan, foto, dan lokasi pribadi tanpa enkripsi; pilih tempat penyimpanan yang kamu percaya.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy ? null : () => execute(false),
            icon: const Icon(Icons.backup_outlined),
            label: const Text('Buat cadangan'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : () => execute(true),
            icon: const Icon(Icons.restore),
            label: const Text('Pulihkan dari file'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(message!, style: const TextStyle(height: 1.6)),
            ),
        ],
      ),
    ),
  );
}
