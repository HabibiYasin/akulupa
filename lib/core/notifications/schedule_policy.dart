import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

class ReminderSchedulePolicy {
  static const strictOffsets = [0, 5, 15, 30, 60];
  List<({int slot, DateTime at})> occurrences({
    required DateTime scheduledAt,
    required Personality personality,
    required bool isImportant,
    required EntryStatus status,
  }) {
    if (status != EntryStatus.pending) return [];
    final offsets = personality == Personality.strict && isImportant
        ? strictOffsets
        : [0];
    return [
      for (var i = 0; i < offsets.length; i++)
        (slot: i, at: scheduledAt.add(Duration(minutes: offsets[i]))),
    ];
  }

  // User-requested snooze is a new single alarm, not another strict chain.
  DateTime snooze(DateTime now) => now.add(const Duration(minutes: 10));
  static int reminderId(int id, int slot) => id * 10 + slot;
  static int habitId(int id) => -id;
}

class HabitSchedulePolicy {
  // Calendar construction, not +24h, preserves wall-clock time across DST.
  tz.TZDateTime next({
    required tz.TZDateTime now,
    required int minutes,
    bool skipToday = false,
  }) {
    if (minutes < 0 || minutes > 1439) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    var date = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (skipToday || !date.isAfter(now)) {
      date = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + 1,
        minutes ~/ 60,
        minutes % 60,
      );
    }
    return date;
  }
}
