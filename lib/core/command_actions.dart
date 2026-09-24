import 'database/app_database.dart';
import 'models.dart';
import 'parser/command_parser.dart';
import 'utils/dates.dart';
import '../features/habits/habit_repository.dart';
import '../features/reminders/reminder_repository.dart';
import '../features/memory/item_repository.dart';

class CommandTarget {
  const CommandTarget(this.id, this.title, this.detail);
  final int id;
  final String title;
  final String detail;
}

class CommandActions {
  CommandActions(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  bool _matches(String title, String query) {
    final words = normalize(query)
        .split(' ')
        .where(
          (w) => w.isNotEmpty && !['aku', 'saya', 'untuk', 'makan'].contains(w),
        )
        .toList();
    final text = normalize(title);
    return words.isNotEmpty && words.every((word) => text.contains(word));
  }

  Future<List<CommandTarget>> candidates(ParsedCommand command) async {
    if (!command.isMutation || command.title.trim().isEmpty) return [];
    if (command.intent == CommandIntent.updateItemLocation) {
      return [
        for (final memory in await ItemRepository(db).find(''))
          if (_matches(memory.item.name, command.title))
            CommandTarget(
              memory.item.id,
              memory.item.name,
              '${memory.latest.location} → ${command.location}',
            ),
      ];
    }
    if (command.intent == CommandIntent.cancelReminder) {
      return [
        for (final r in await ReminderRepository(db).all())
          if (r.status == EntryStatus.pending &&
              _matches(r.title, command.title) &&
              (command.date == null ||
                  dayKey(r.snoozedUntil ?? r.scheduledAt) ==
                      dayKey(command.date!)))
            CommandTarget(
              r.id,
              r.title,
              dateTimeText(r.snoozedUntil ?? r.scheduledAt),
            ),
      ];
    }
    final date = command.date;
    if (date == null) {
      throw ArgumentError(
        'Tanggal belum jelas. Sebutkan hari atau tanggal yang pasti.',
      );
    }
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isBefore(today) ||
        date.isAfter(DateTime(today.year, today.month, today.day + 31))) {
      throw ArgumentError(
        'Pilih tanggal mulai hari ini hingga 31 hari ke depan.',
      );
    }
    final repo = HabitRepository(db);
    final result = <CommandTarget>[];
    for (final h in await repo.all()) {
      if (!h.isActive ||
          !_matches(h.title, command.title) ||
          (h.weekday != null && h.weekday != date.weekday)) {
        continue;
      }
      final log = await repo.logFor(h.id, date);
      if (log?.status == EntryStatus.skipped ||
          log?.status == EntryStatus.completed) {
        continue;
      }
      if (command.intent == CommandIntent.incrementHabit &&
          (h.targetCount <= 1 || h.unit != command.unit)) {
        continue;
      }
      result.add(
        CommandTarget(
          h.id,
          h.title,
          '${fullDate(date)}${h.targetCount > 1 ? ' · ${log?.progress ?? 0}/${h.targetCount} ${h.unit}' : ''}',
        ),
      );
    }
    return result;
  }

  Future<String> apply(
    ParsedCommand command,
    Set<int> ids,
  ) => db.transaction(() async {
    final available = await candidates(command);
    if (ids.isEmpty || ids.any((id) => !available.any((c) => c.id == id))) {
      throw StateError('Catatan sudah berubah. Periksa kembali pilihanmu.');
    }
    if (command.intent == CommandIntent.cancelReminder) {
      for (final id in ids) {
        await ReminderRepository(db).setStatus(id, EntryStatus.skipped);
      }
      return '${ids.length} pengingat dibatalkan. Riwayat tetap tersimpan.';
    }
    if (command.intent == CommandIntent.updateItemLocation) {
      if (ids.length != 1) throw ArgumentError('Pilih satu barang.');
      final item = available.singleWhere((c) => c.id == ids.single);
      await ItemRepository(db).save(item.title, command.location);
      return '${item.title}: ${command.location}. Riwayat lokasi tetap tersimpan.';
    }
    if (ids.length != 1) throw ArgumentError('Pilih satu rutinitas.');
    final repo = HabitRepository(db);
    if (command.intent == CommandIntent.skipHabit) {
      await repo.mark(ids.single, command.date!, EntryStatus.skipped);
      return 'Rutinitas dilewati pada ${fullDate(command.date!)} saja.';
    }
    final progress = await repo.increment(
      ids.single,
      command.date!,
      command.amount,
    );
    final habit = (await repo.get(ids.single))!;
    return '$progress/${habit.targetCount} ${habit.unit} tercatat. ${progress == habit.targetCount ? 'Target hari ini selesai.' : 'Sisa ${habit.targetCount - progress} ${habit.unit}.'}';
  });
}
