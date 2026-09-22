import 'package:flutter/foundation.dart';

import 'database/app_database.dart';
import 'models.dart';
import 'notifications/notification_gateway.dart';
import 'notifications/reminder_coordinator.dart';
import 'parser/command_parser.dart';
import 'utils/dates.dart';
import '../features/activity/activity_repository.dart';
import '../features/habits/habit_repository.dart';
import '../features/memory/item_repository.dart';
import '../features/reminders/reminder_repository.dart';
import '../features/settings/settings_repository.dart';

class CommandDraft {
  const CommandDraft({
    required this.intent,
    required this.title,
    this.location = '',
    this.at,
    this.minutes,
    this.important = false,
  });
  final CommandIntent intent;
  final String title;
  final String location;
  final DateTime? at;
  final int? minutes;
  final bool important;
}

class AppServices {
  AppServices(this.db, this.notifications) {
    items = ItemRepository(db);
    reminders = ReminderRepository(db);
    habits = HabitRepository(db);
    activities = ActivityRepository(db);
    settings = SettingsRepository(db);
    coordinator = ReminderCoordinator(
      gateway: notifications,
      reminders: reminders,
      habits: habits,
      settings: settings,
    );
  }
  final AppDatabase db;
  final AndroidNotificationGateway notifications;
  late final ItemRepository items;
  late final ReminderRepository reminders;
  late final HabitRepository habits;
  late final ActivityRepository activities;
  late final SettingsRepository settings;
  late final ReminderCoordinator coordinator;
  final CommandParser parser = IndonesianCommandParser();
  final notificationWarning = ValueNotifier<String?>(null);
  Future<void> _queue = Future.value();

  // Serialize scheduling and actions so a resume cannot restore an alarm
  // concurrently with the user's completion/cancellation.
  Future<void> _serialized(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return next;
  }

  Future<void> initialize() async {
    await settings
        .get(); // Surface DB failures instead of silently losing writes.
    try {
      final launch = await notifications.initialize((response) {
        notificationAction(response.payload, response.actionId);
      });
      if (launch != null) {
        await notificationAction(launch.payload, launch.actionId);
      }
      await refreshNotifications();
    } catch (e) {
      notificationWarning.value =
          'Notifikasi belum siap. Buka Pengaturan untuk mencoba kembali.';
      debugPrint('Notification initialization: $e');
    }
  }

  void _permissionWarning() {
    notificationWarning.value = !notifications.enabled
        ? 'Notifikasi belum diizinkan. Aktifkan di Pengaturan agar pengingat muncul.'
        : !notifications.exact
        ? 'Alarm presisi belum diizinkan; pengingat bisa terlambat. Aktifkan di Pengaturan.'
        : null;
  }

  Future<void> _notificationJob(Future<void> Function() job) async {
    try {
      await _serialized(job);
      _permissionWarning();
    } catch (e) {
      notificationWarning.value = 'Notifikasi gagal diperbarui. Periksa status jadwal, lalu coba sinkronkan di Pengaturan.';
      debugPrint('Notification scheduling: $e');
    }
  }

  Future<void> refreshNotifications() => _notificationJob(() async {
    if (!notifications.initialized) {
      await notifications.initialize((response) {
        notificationAction(response.payload, response.actionId);
      });
    }
    await notifications.refreshTimezone();
    await notifications.refreshPermissions();
    await coordinator.reconcile();
  });
  Future<void> requestPermissions() async {
    await notifications.requestPermissions(requestExact: true);
    await refreshNotifications();
  }

  Future<void> notificationAction(String? payload, String? action) =>
      _notificationJob(() => coordinator.notificationAction(payload, action));
  Future<void> reminderAction(int id, String action) async {
    // Persist status errors propagate to the UI; scheduling errors are reported
    // separately with a saved-data warning.
    final reminder = await reminders.get(id);
    if (reminder == null || reminder.status != EntryStatus.pending) return;
    if (action == 'snooze') {
      await reminders.snooze(
        id,
        coordinator.reminderPolicy.snooze(DateTime.now()),
      );
    } else {
      await reminders.setStatus(
        id,
        action == 'done' ? EntryStatus.completed : EntryStatus.skipped,
      );
    }
    await _notificationJob(
      () async => coordinator.scheduleReminder(
        (await reminders.get(id))!,
        await settings.get(),
      ),
    );
  }

  Future<void> markHabit(int id, EntryStatus status) async {
    await habits.mark(id, DateTime.now(), status);
    await _notificationJob(
      () async => coordinator.scheduleHabit(
        (await habits.get(id))!,
        await settings.get(),
      ),
    );
  }

  Future<void> toggleHabit(Habit habit) async {
    await habits.setActive(habit.id, !habit.isActive);
    await _notificationJob(
      () async => coordinator.scheduleHabit(
        (await habits.get(habit.id))!,
        await settings.get(),
      ),
    );
  }

  Future<void> changePersonality(Personality personality) async {
    await settings.set(personality);
    await refreshNotifications();
  }

  Future<String> query(ParsedCommand command) async {
    if (command.intent == CommandIntent.findItem) {
      final matches = await items.find(command.title);
      if (matches.isEmpty) {
        return 'Belum ada catatan untuk “${command.title}”. Coba simpan lokasinya dulu.';
      }
      final templates = ResponseTemplates(await settings.get());
      return matches
          .take(5)
          .map(
            (m) =>
                '${templates.found(m.item.name, m.latest.location)}\n${dateTimeText(m.latest.createdAt)}',
          )
          .join('\n\n');
    }
    final activity = await activities.latest(command.title);
    return activity == null
        ? 'Belum ada aktivitas “${command.title}” yang dicatat.'
        : '${activity.title} terakhir dicatat pada ${dateTimeText(activity.eventTime)}.';
  }

  Future<String> save(CommandDraft draft) async {
    switch (draft.intent) {
      case CommandIntent.saveItemLocation:
        await items.save(draft.title, draft.location);
      case CommandIntent.createReminder:
        final reminder = await reminders.create(
          draft.title,
          draft.at!,
          important: draft.important,
        );
        await _notificationJob(
          () async =>
              coordinator.scheduleReminder(reminder, await settings.get()),
        );
      case CommandIntent.createHabit:
        final habit = await habits.create(draft.title, draft.minutes!);
        await _notificationJob(
          () async => coordinator.scheduleHabit(habit, await settings.get()),
        );
      case CommandIntent.logActivity:
        await activities.create(draft.title, draft.at!);
      default:
        throw ArgumentError('Perintah tidak dapat disimpan.');
    }
    return ResponseTemplates(await settings.get()).saved(draft.title);
  }
}
