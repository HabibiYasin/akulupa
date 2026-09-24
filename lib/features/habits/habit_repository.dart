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
  Future<List<HabitLog>> logsFor(int id) =>
      (db.select(db.habitLogs)..where((t) => t.habitId.equals(id))).get();

  Future<Habit> create(
    String title,
    int minutes, {
    int? weekday,
    int targetCount = 1,
    String? unit,
    int? endMinutes,
  }) {
    if (title.trim().isEmpty || minutes < 0 || minutes > 1439) {
      throw ArgumentError('Rutinitas tidak valid.');
    }
    if ((weekday != null && (weekday < 1 || weekday > 7)) ||
        targetCount < 1 ||
        targetCount > 24 ||
        (targetCount > 1 &&
            (unit == null ||
                unit.trim().isEmpty ||
                endMinutes == null ||
                endMinutes <= minutes ||
                endMinutes > 1439))) {
      throw ArgumentError('Periksa hari, target, dan rentang waktu rutinitas.');
    }
    return db
        .into(db.habits)
        .insertReturning(
          HabitsCompanion.insert(
            title: title.trim(),
            scheduleTime: minutes,
            weekday: Value(weekday),
            repeatPattern: Value(
              weekday == null ? RepeatPattern.daily : RepeatPattern.weekly,
            ),
            targetCount: Value(targetCount),
            unit: Value(unit),
            endTime: Value(endMinutes),
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
    final habit = await get(id);
    if (habit == null ||
        (habit.weekday != null && habit.weekday != day.weekday)) {
      throw ArgumentError('Hari ini bukan jadwal rutinitas tersebut.');
    }
    await db
        .into(db.habitLogs)
        .insert(
          HabitLogsCompanion.insert(
            habitId: id,
            date: dayKey(day),
            status: status,
            progress: Value(
              status == EntryStatus.completed ? habit.targetCount : 0,
            ),
            completedAt: Value(
              status == EntryStatus.completed ? DateTime.now() : null,
            ),
          ),
          onConflict: DoUpdate(
            (_) => HabitLogsCompanion(
              status: Value(status),
              progress: Value(
                status == EntryStatus.completed ? habit.targetCount : 0,
              ),
              completedAt: Value(
                status == EntryStatus.completed ? DateTime.now() : null,
              ),
            ),
            target: [db.habitLogs.habitId, db.habitLogs.date],
          ),
        );
  }

  Future<int> increment(int id, DateTime day, int amount) =>
      db.transaction(() async {
        final habit = await get(id);
        if (habit == null ||
            !habit.isActive ||
            habit.targetCount <= 1 ||
            amount < 1 ||
            (habit.weekday != null && habit.weekday != day.weekday)) {
          throw ArgumentError(
            'Rutinitas bertarget tidak tersedia pada tanggal ini.',
          );
        }
        final log = await logFor(id, day);
        if (log?.status == EntryStatus.skipped) {
          throw StateError('Rutinitas hari ini sudah dilewati.');
        }
        final progress = ((log?.progress ?? 0) + amount).clamp(
          0,
          habit.targetCount,
        );
        final status = progress == habit.targetCount
            ? EntryStatus.completed
            : EntryStatus.pending;
        final row = HabitLogsCompanion.insert(
          habitId: id,
          date: dayKey(day),
          status: status,
          progress: Value(progress),
          completedAt: Value(
            status == EntryStatus.completed ? DateTime.now() : null,
          ),
        );
        await db
            .into(db.habitLogs)
            .insert(
              row,
              onConflict: DoUpdate(
                (_) => row,
                target: [db.habitLogs.habitId, db.habitLogs.date],
              ),
            );
        return progress;
      });
}
