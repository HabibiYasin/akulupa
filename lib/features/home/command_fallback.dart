import 'package:flutter/material.dart';

import '../../core/parser/command_parser.dart';

/// Choosing a type only opens the existing editable confirmation form.
/// Unknown text is never persisted until the user explicitly saves that form.
Future<ParsedCommand?> chooseCommandType(
  BuildContext context,
  ParsedCommand command,
) async {
  final intent = await showDialog<CommandIntent>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mau dicatat sebagai apa?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              command.notes.isEmpty
                  ? 'Aku belum yakin maksud kalimat ini. Pilih jenis catatan, lalu periksa isinya.'
                  : command.notes.join('\n'),
            ),
            const SizedBox(height: 12),
            Text('“${command.original}”'),
            const SizedBox(height: 16),
            for (final option in [
              (
                CommandIntent.saveItemLocation,
                Icons.inventory_2_outlined,
                'Lokasi barang',
              ),
              (
                CommandIntent.createReminder,
                Icons.notifications_none,
                'Pengingat',
              ),
              (CommandIntent.createHabit, Icons.repeat, 'Rutinitas'),
              (
                CommandIntent.logActivity,
                Icons.history,
                'Aktivitas yang sudah dilakukan',
              ),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(option.$2),
                title: Text(option.$3),
                onTap: () => Navigator.pop(context, option.$1),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ubah kalimat'),
        ),
      ],
    ),
  );
  if (intent == null) return null;
  return ParsedCommand(
    intent: intent,
    original: command.original,
    title: intent == CommandIntent.saveItemLocation ? '' : command.original,
    notes: const ['Lengkapi dan periksa isian sebelum menyimpan.'],
  );
}
