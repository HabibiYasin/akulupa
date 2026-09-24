import 'package:flutter/foundation.dart';

import 'backup/backup_service.dart';
import 'platform/android_integrations.dart';
import 'platform/widget_service.dart';
import '../features/places/place_repository.dart';
import '../features/places/place_service.dart';

import 'database/app_database.dart';
import 'command_actions.dart';
import 'models.dart';
import 'notifications/notification_gateway.dart';
import 'notifications/reminder_coordinator.dart';
import 'parser/command_parser.dart';
import 'photos/photo_service.dart';
import 'speech/speech_service.dart';
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
    this.weekday,
    this.targetCount = 1,
    this.unit,
    this.endMinutes,
    this.photo,
  });
  final CommandIntent intent;
  final String title;
  final String location;
  final DateTime? at;
  final int? minutes;
  final bool important;
  final int? weekday;
  final int targetCount;
  final String? unit;
  final int? endMinutes;
  final PreparedPhoto? photo;
}

class AppServices {
  AppServices(
    this.db,
    this.notifications, {
    SpeechService? speech,
    PhotoService? photos,
  }) : speech = speech ?? AndroidSpeechService(),
       photos = photos ?? LocalPhotoService() {
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
    backups = LocalBackupService(db, this.photos);
    places = PlaceRepository(db);
    placeService = PlaceService(places, integrations);
    widget = WidgetService(db, integrations);
  }
  final AppDatabase db;
  final AndroidNotificationGateway notifications;
  final SpeechService speech;
  final PhotoService photos;
  final integrations = const AndroidIntegrations();
  late final LocalBackupService backups;
  late final PlaceRepository places;
  late final PlaceService placeService;
  late final WidgetService widget;
  final integrationWarning = ValueNotifier<String?>(null);
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
    widget.start();
    await refreshIntegrations();
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

  Future<void> refreshIntegrations() async {
    try {
      await placeService.refresh();
      integrationWarning.value = null;
    } catch (_) {
      integrationWarning.value = 'Pengingat lokasi belum aktif. Periksa izin dan GPS, lalu coba aktifkan ulang.';
    }
  }

  Future<void> restoreBackup(BackupPreview preview) => _serialized(
    () => placeService.replaceData(() async {
      await notifications.plugin.cancelAll();
      try {
        await backups.restore(preview);
      } finally {
        // Even failed restores must re-establish alarms for the surviving data.
        try {
          await coordinator.reconcile();
        } catch (_) {
          notificationWarning.value = 'Data tersedia, tetapi alarm perlu disinkronkan ulang di Pengaturan.';
        }
        await widget.refresh();
      }
    }),
  );

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

  Future<void> incrementHabit(int id) async {
    await habits.increment(id, DateTime.now(), 1);
    await _notificationJob(
      () async => coordinator.scheduleHabit(
        (await habits.get(id))!,
        await settings.get(),
      ),
    );
  }

  Future<String> applyCommand(ParsedCommand command, Set<int> ids) async {
    final result = await CommandActions(db).apply(command, ids);
    if (command.intent == CommandIntent.updateItemLocation) return result;
    await _notificationJob(() async {
      for (final id in ids) {
        if (command.intent == CommandIntent.cancelReminder) {
          await coordinator.scheduleReminder(
            (await reminders.get(id))!,
            await settings.get(),
          );
        } else {
          await coordinator.scheduleHabit(
            (await habits.get(id))!,
            await settings.get(),
          );
        }
      }
    });
    return result;
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
        String? path;
        try {
          if (draft.photo != null) path = await photos.store(draft.photo!);
          await items.save(draft.title, draft.location, photoPath: path);
        } catch (_) {
          if (path != null) await photos.discard(path);
          rethrow;
        }
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
        final habit = await habits.create(
          draft.title,
          draft.minutes!,
          weekday: draft.weekday,
          targetCount: draft.targetCount,
          unit: draft.unit,
          endMinutes: draft.endMinutes,
        );
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
