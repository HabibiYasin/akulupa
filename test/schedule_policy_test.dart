import 'package:aku_lupa/core/models.dart';
import 'package:aku_lupa/core/notifications/schedule_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  data.initializeTimeZones();
  final policy = ReminderSchedulePolicy();
  final at = DateTime(2026, 9, 13, 14);
  test('Galak penting maksimum lima, pada offset yang ditentukan', () {
    final result = policy.occurrences(
      scheduledAt: at,
      personality: Personality.strict,
      isImportant: true,
      status: EntryStatus.pending,
    );
    expect(result.map((r) => r.at.difference(at).inMinutes), [
      0,
      5,
      15,
      30,
      60,
    ]);
    expect(result.map((r) => r.slot).toSet().length, 5);
  });
  test('Santai dan pengingat biasa hanya satu alarm', () {
    expect(
      policy
          .occurrences(
            scheduledAt: at,
            personality: Personality.relaxed,
            isImportant: true,
            status: EntryStatus.pending,
          )
          .length,
      1,
    );
    expect(
      policy
          .occurrences(
            scheduledAt: at,
            personality: Personality.strict,
            isImportant: false,
            status: EntryStatus.pending,
          )
          .length,
      1,
    );
  });
  for (final status in [EntryStatus.completed, EntryStatus.skipped]) {
    test(
      '$status tidak memiliki alarm',
      () => expect(
        policy.occurrences(
          scheduledAt: at,
          personality: Personality.strict,
          isImportant: true,
          status: status,
        ),
        isEmpty,
      ),
    );
  }
  test('tunda sepuluh menit melintasi hari', () {
    expect(
      policy.snooze(DateTime(2026, 12, 31, 23, 55)),
      DateTime(2027, 1, 1, 0, 5),
    );
  });
  final habits = HabitSchedulePolicy();
  final jakarta = tz.getLocation('Asia/Jakarta');
  test('habit hari ini sebelum jam jatuh tempo', () {
    final now = tz.TZDateTime(jakarta, 2026, 9, 13, 7);
    expect(
      habits.next(now: now, minutes: 480),
      tz.TZDateTime(jakarta, 2026, 9, 13, 8),
    );
  });
  test('habit tepat/pasca jadwal dan selesai hari ini menuju besok', () {
    expect(
      habits.next(now: tz.TZDateTime(jakarta, 2026, 12, 31, 8), minutes: 480),
      tz.TZDateTime(jakarta, 2027, 1, 1, 8),
    );
    expect(
      habits.next(
        now: tz.TZDateTime(jakarta, 2026, 9, 13, 7),
        minutes: 480,
        skipToday: true,
      ),
      tz.TZDateTime(jakarta, 2026, 9, 14, 8),
    );
  });
  test('DST mempertahankan jam lokal, bukan interval 24 jam', () {
    final zone = tz.getLocation('America/New_York');
    final now = tz.TZDateTime(zone, 2026, 3, 7, 10);
    final next = habits.next(now: now, minutes: 9 * 60);
    expect(next.hour, 9);
    expect(next.day, 8);
    expect(next.difference(now).inHours, 22);
  });
  test(
    'menit habit di luar rentang ditolak',
    () => expect(
      () => habits.next(now: tz.TZDateTime.now(jakarta), minutes: 1440),
      throwsArgumentError,
    ),
  );
}
