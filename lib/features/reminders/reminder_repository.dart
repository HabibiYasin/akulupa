import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models.dart';

class ReminderRepository {
  ReminderRepository(this.db);
  final AppDatabase db;
  Stream<List<Reminder>> watchAll() => (db.select(
    db.reminders,
  )..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)])).watch();
  Future<List<Reminder>> all() => db.select(db.reminders).get();
  Future<Reminder?> get(int id) => (db.select(
    db.reminders,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<Reminder> create(
    String title,
    DateTime scheduledAt, {
    bool important = false,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Judul wajib diisi.');
    if (!scheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError('Waktu pengingat harus di masa depan.');
    }
    return db
        .into(db.reminders)
        .insertReturning(
          RemindersCompanion.insert(
            title: title.trim(),
            scheduledAt: scheduledAt,
            isImportant: Value(important),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> setStatus(int id, EntryStatus status) async {
    await (db.update(db.reminders)..where((t) => t.id.equals(id))).write(
      RemindersCompanion(
        status: Value(status),
        snoozedUntil: const Value(null),
      ),
    );
  }

  Future<void> snooze(int id, DateTime until) async {
    await (db.update(db.reminders)..where(
          (t) => t.id.equals(id) & t.status.equalsValue(EntryStatus.pending),
        ))
        .write(RemindersCompanion(snoozedUntil: Value(until)));
  }
}
