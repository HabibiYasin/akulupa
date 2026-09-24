import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/models.dart';
import 'package:aku_lupa/core/notifications/notification_gateway.dart';
import 'package:aku_lupa/core/notifications/reminder_coordinator.dart';
import 'package:aku_lupa/features/habits/habit_repository.dart';
import 'package:aku_lupa/features/reminders/reminder_repository.dart';
import 'package:aku_lupa/features/settings/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

class FakeNotifications implements NotificationGateway {
  final alarms = <int, Alarm>{};
  final cancelled = <int>[];
  @override
  Future<void> cancelHabit(int id) async {
    for (final alarm in alarms.values.toList()) {
      if (alarm.payload == 'habit:$id' ||
          alarm.payload.startsWith('habit:$id:')) {
        await cancel(alarm.id);
      }
    }
    await cancel(-id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    alarms.remove(id);
  }

  @override
  Future<void> schedule(Alarm alarm) async {
    alarms[alarm.id] = alarm;
  }
}

void main() {
  late AppDatabase db;
  late ReminderRepository reminders;
  late HabitRepository habits;
  late SettingsRepository settings;
  late FakeNotifications gateway;
  late ReminderCoordinator coordinator;
  final now = DateTime(2030, 1, 1, 7);
  setUp(() async {
    data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reminders = ReminderRepository(db);
    habits = HabitRepository(db);
    settings = SettingsRepository(db);
    gateway = FakeNotifications();
    coordinator = ReminderCoordinator(
      gateway: gateway,
      reminders: reminders,
      habits: habits,
      settings: settings,
      clock: () => now,
    );
    await settings.set(Personality.strict);
  });
  tearDown(() => db.close());
  test(
    'Sudah membatalkan seluruh rantai dan tetap selesai setelah reconcile',
    () async {
      final r = await reminders.create(
        'Obat',
        now.add(const Duration(hours: 1)),
        important: true,
      );
      await coordinator.reconcile();
      expect(gateway.alarms.length, 5);
      await coordinator.notificationAction('reminder:${r.id}', 'done');
      expect((await reminders.get(r.id))!.status, EntryStatus.completed);
      expect(gateway.alarms, isEmpty);
      await coordinator.reconcile();
      expect(gateway.alarms, isEmpty);
    },
  );
  test('Lewati membatalkan seluruh rantai', () async {
    final r = await reminders.create(
      'Obat',
      now.add(const Duration(hours: 1)),
      important: true,
    );
    await coordinator.reconcile();
    await coordinator.reminderAction(r.id, 'skip');
    expect((await reminders.get(r.id))!.status, EntryStatus.skipped);
    expect(gateway.alarms, isEmpty);
  });
  test(
    'tunda mengganti rantai dengan satu alarm dan persisten setelah reconcile',
    () async {
      final r = await reminders.create(
        'Obat',
        now.add(const Duration(hours: 1)),
        important: true,
      );
      await coordinator.reconcile();
      await coordinator.reminderAction(r.id, 'snooze');
      expect(
        gateway.alarms.values.single.at,
        now.add(const Duration(minutes: 10)),
      );
      await coordinator.reconcile();
      expect(
        gateway.alarms.values.single.at,
        now.add(const Duration(minutes: 10)),
      );
      await coordinator.reminderAction(r.id, 'done');
      await coordinator.reminderAction(r.id, 'snooze');
      expect(gateway.alarms, isEmpty);
    },
  );
  test('perubahan Galak ke Santai membuang retry', () async {
    await reminders.create(
      'Obat',
      now.add(const Duration(hours: 1)),
      important: true,
    );
    await coordinator.reconcile();
    await settings.set(Personality.relaxed);
    await coordinator.reconcile();
    expect(gateway.alarms.length, 1);
  });
  test(
    'habit selesai sebelum jadwal tidak mengingatkan lagi hari ini',
    () async {
      final h = await habits.create('Sarapan', 480);
      await coordinator.reconcile();
      expect(gateway.alarms.values.single.daily, isTrue);
      await coordinator.habitAction(h.id, now, EntryStatus.completed);
      expect(gateway.alarms.values.single.at.day, 2);
      await habits.setActive(h.id, false);
      await coordinator.reconcile();
      expect(gateway.alarms, isEmpty);
    },
  );
  test('payload tidak valid dan tap biasa tidak mengubah data', () async {
    await coordinator.notificationAction('garbage', 'done');
    await coordinator.notificationAction('reminder:abc', 'done');
    await coordinator.notificationAction(null, null);
    expect(gateway.alarms, isEmpty);
  });
}
