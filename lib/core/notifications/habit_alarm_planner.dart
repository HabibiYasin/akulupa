import 'package:timezone/timezone.dart' as tz;

import '../database/app_database.dart';
import '../models.dart';
import '../utils/dates.dart';
import 'notification_gateway.dart';

/// Explicit exceptions precede native recurrence, so a future skip survives
/// closing the app. Each habit reserves 1024 IDs (32 days * 24 + recurrence).
class HabitAlarmPlanner {
  List<Alarm> plan(
    Habit habit,
    List<HabitLog> logs,
    DateTime clock,
    Personality personality,
  ) {
    if (!habit.isActive) return [];
    final now = tz.TZDateTime.from(clock, tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    var boundary = tz.TZDateTime(
      tz.local,
      today.year,
      today.month,
      today.day - 1,
    );
    final excluded = <String>{};
    for (final log in logs.where((l) => l.status != EntryStatus.pending)) {
      excluded.add(log.date);
      final parsed = DateTime.parse(log.date);
      final date = tz.TZDateTime(
        tz.local,
        parsed.year,
        parsed.month,
        parsed.day,
      );
      if (date.isAfter(boundary)) boundary = date;
    }
    if (boundary.isAfter(
      tz.TZDateTime(tz.local, today.year, today.month, today.day + 31),
    )) {
      throw StateError('Pengecualian rutinitas maksimal 31 hari ke depan.');
    }
    final alarms = <Alarm>[];
    void add(tz.TZDateTime at, int minutes, {required bool repeating}) {
      final index = alarms.length;
      alarms.add(
        Alarm(
          id: index == 0 ? -habit.id : -(1000000 + habit.id * 1024 + index),
          title: habit.title,
          body: habit.targetCount > 1
              ? '${ResponseTemplates(personality).reminder(habit.title)} Target ${habit.targetCount} ${habit.unit} hari ini.'
              : ResponseTemplates(personality).reminder(habit.title),
          at: at,
          payload:
              'habit:${habit.id}:$minutes${repeating ? '' : ':${dayKey(at)}'}',
          daily: repeating && habit.weekday == null,
          weekly: repeating && habit.weekday != null,
          doneLabel: habit.targetCount > 1 ? '+1 ${habit.unit}' : 'Sudah',
        ),
      );
    }

    for (var slot = 0; slot < habit.targetCount; slot++) {
      final minutes = habit.targetCount == 1
          ? habit.scheduleTime
          : habit.scheduleTime +
                ((habit.endTime! - habit.scheduleTime) *
                        slot /
                        (habit.targetCount - 1))
                    .round();
      var date = today;
      while (!date.isAfter(boundary)) {
        final at = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          minutes ~/ 60,
          minutes % 60,
        );
        if ((habit.weekday == null || habit.weekday == date.weekday) &&
            !excluded.contains(dayKey(date)) &&
            at.isAfter(now)) {
          add(at, minutes, repeating: false);
        }
        date = tz.TZDateTime(tz.local, date.year, date.month, date.day + 1);
      }
      while (habit.weekday != null && date.weekday != habit.weekday) {
        date = tz.TZDateTime(tz.local, date.year, date.month, date.day + 1);
      }
      if (!tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        minutes ~/ 60,
        minutes % 60,
      ).isAfter(now)) {
        date = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day + (habit.weekday == null ? 1 : 7),
        );
      }
      add(
        tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          minutes ~/ 60,
          minutes % 60,
        ),
        minutes,
        repeating: true,
      );
    }
    return alarms;
  }
}
