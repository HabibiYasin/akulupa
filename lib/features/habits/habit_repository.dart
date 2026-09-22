import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models.dart';
import '../../core/utils/dates.dart';

class HabitRepository {
  HabitRepository(this.db);
  final AppDatabase db;
  Stream<List<Habit>> watchAll() => (db.select(
    db.habits,
  )..orderBy([(t) => OrderingTerm.asc(t.scheduleTime)])).watch();
  Future<List<Habit>> all() => db.select(db.habits).get();
  Future<Habit?> get(int id) =>
      (db.select(db.habits)..where((t) => t.id.equals(id))).getSingleOrNull();
  Stream<List<HabitLog>> watchLogs() => (db.select(
    db.habitLogs,
  )..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
  Future<HabitLog?> logFor(int id, DateTime day) =>
      (db.select(db.habitLogs)
            ..where((t) => t.habitId.equals(id) & t.date.equals(dayKey(day))))
          .getSingleOrNull();
  Future<Habit> create(String title, int minutes) {
    if (title.trim().isEmpty || minutes < 0 || minutes > 1439) {
      throw ArgumentError('Rutinitas tidak valid.');
    }
    return db
        .into(db.habits)
        .insertReturning(
          HabitsCompanion.insert(
            title: title.trim(),
            scheduleTime: minutes,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> setActive(int id, bool active) async {
    await (db.update(db.habits)..where((t) => t.id.equals(id))).write(
      HabitsCompanion(isActive: Value(active)),
    );
  }

  Future<void> mark(int id, DateTime day, EntryStatus status) async {
    await db
        .into(db.habitLogs)
        .insert(
          HabitLogsCompanion.insert(
            habitId: id,
            date: dayKey(day),
            status: status,
            completedAt: Value(
              status == EntryStatus.completed ? DateTime.now() : null,
            ),
          ),
          onConflict: DoUpdate(
            (_) => HabitLogsCompanion(
              status: Value(status),
              completedAt: Value(
                status == EntryStatus.completed ? DateTime.now() : null,
              ),
            ),
            target: [db.habitLogs.habitId, db.habitLogs.date],
          ),
        );
  }
}
