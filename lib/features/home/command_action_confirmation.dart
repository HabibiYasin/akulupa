import 'package:flutter/material.dart';

import '../../core/app_services.dart';
import '../../core/command_actions.dart';
import '../../core/parser/command_parser.dart';

Future<String?> confirmCommandAction(
  BuildContext context,
  AppServices services,
  ParsedCommand command,
) async {
  final candidates = await CommandActions(services.db).candidates(command);
  if (!context.mounted) return null;
  if (candidates.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Belum ada catatan yang cocok'),
        content: Text(
          command.intent == CommandIntent.updateItemLocation
              ? 'Belum ada barang yang cocok dengan “${command.title}”. Catat barangnya terlebih dahulu atau periksa namanya di Barang.'
              : 'Tidak ditemukan catatan aktif untuk “${command.title}” pada tanggal yang dimaksud. Coba nama kegiatan yang lebih spesifik atau periksa Jadwal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Oke'),
          ),
        ],
      ),
    );
    return null;
  }
  final multiple = command.intent == CommandIntent.cancelReminder;
  final selected = <int>{if (candidates.length == 1) candidates.single.id};
  var busy = false;
  String? error;
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(switch (command.intent) {
            CommandIntent.cancelReminder => 'Batalkan pengingat?',
            CommandIntent.skipHabit => 'Lewati tanggal ini saja?',
            CommandIntent.updateItemLocation => 'Perbarui lokasi barang?',
            _ => 'Catat +${command.amount} ${command.unit}?',
          }),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    multiple
                        ? 'Pilih pengingat yang dibatalkan. Riwayatnya tetap tersimpan.'
                        : command.intent == CommandIntent.updateItemLocation
                        ? 'Pilih barang yang dimaksud.'
                        : 'Pilih satu rutinitas yang dimaksud.',
                  ),
                  for (final candidate in candidates)
                    CheckboxListTile(
                      value: selected.contains(candidate.id),
                      title: Text(candidate.title),
                      subtitle: Text(candidate.detail),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              if (!multiple) selected.clear();
                              if (value == true) {
                                selected.add(candidate.id);
                              } else {
                                selected.remove(candidate.id);
                              }
                            }),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy || selected.isEmpty
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final result = await services.applyCommand(
                          command,
                          selected,
                        );
                        if (context.mounted) Navigator.pop(context, result);
                      } catch (_) {
                        if (context.mounted) {
                          setState(() {
                            busy = false;
                            error = 'Belum berhasil. Catatan mungkin sudah berubah; periksa kembali Jadwal.';
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Menyimpan…' : 'Konfirmasi'),
            ),
          ],
        ),
      ),
    ),
  );
}
