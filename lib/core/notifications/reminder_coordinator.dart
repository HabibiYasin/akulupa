import 'habit_alarm_planner.dart';

import '../../features/reminders/reminder_repository.dart';
import '../../features/habits/habit_repository.dart';
import '../../features/settings/settings_repository.dart';
import '../database/app_database.dart';
import '../models.dart';
import 'notification_gateway.dart';
import 'schedule_policy.dart';

class ReminderCoordinator {
  ReminderCoordinator({
    required this.gateway,
    required this.reminders,
    required this.habits,
    required this.settings,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final NotificationGateway gateway;
  final ReminderRepository reminders;
  final HabitRepository habits;
  final SettingsRepository settings;
  final DateTime Function() clock;
  final reminderPolicy = ReminderSchedulePolicy();
  final habitPolicy = HabitSchedulePolicy();

  Future<void> cancelReminder(int id) async {
    for (var slot = 0; slot < 6; slot++) {
      await gateway.cancel(ReminderSchedulePolicy.reminderId(id, slot));
    }
  }

  Future<void> scheduleReminder(
    Reminder reminder,
    Personality personality,
  ) async {
    await cancelReminder(reminder.id);
    if (reminder.status != EntryStatus.pending) return;
    final now = clock();
    final occurrences = reminder.snoozedUntil != null
        ? [(slot: 5, at: reminder.snoozedUntil!)]
        : reminderPolicy.occurrences(
            scheduledAt: reminder.scheduledAt,
            personality: personality,
            isImportant: reminder.isImportant,
            status: reminder.status,
          );
    for (final occurrence in occurrences) {
      // Overdue reminders remain visible in the app; reopening must not create
      // another alarm chain or replay already delivered occurrences.
      if (!occurrence.at.isAfter(now)) continue;
      await gateway.schedule(
        Alarm(
          id: ReminderSchedulePolicy.reminderId(reminder.id, occurrence.slot),
          title: reminder.title,
          body: ResponseTemplates(personality).reminder(reminder.title),
          at: occurrence.at,
          payload: 'reminder:${reminder.id}',
        ),
      );
    }
  }

  Future<void> scheduleHabit(Habit habit, Personality personality) async {
    await gateway.cancelHabit(habit.id);
    for (final alarm in HabitAlarmPlanner().plan(
      habit,
      await habits.logsFor(habit.id),
      clock(),
      personality,
    )) {
      await gateway.schedule(alarm);
    }
  }

  Future<void> reconcile() async {
    final personality = await settings.get();
    for (final reminder in await reminders.all()) {
      await scheduleReminder(reminder, personality);
    }
    for (final habit in await habits.all()) {
      await scheduleHabit(habit, personality);
    }
  }

  Future<void> reminderAction(int id, String action) async {
    final reminder = await reminders.get(id);
    if (reminder == null || reminder.status != EntryStatus.pending) return;
    switch (action) {
      case 'done':
        await reminders.setStatus(id, EntryStatus.completed);
      case 'skip':
        await reminders.setStatus(id, EntryStatus.skipped);
      case 'snooze':
        await reminders.snooze(id, reminderPolicy.snooze(clock()));
      default:
        return;
    }
    await scheduleReminder((await reminders.get(id))!, await settings.get());
  }

  Future<void> habitAction(int id, DateTime day, EntryStatus status) async {
    final habit = await habits.get(id);
    if (habit == null) return;
    await habits.mark(id, day, status);
    await scheduleHabit(habit, await settings.get());
  }

  Future<void> notificationAction(String? payload, String? action) async {
    if (payload == null || !['done', 'skip', 'snooze'].contains(action)) return;
    final parts = payload.split(':');
    if (parts.length < 2 || parts.length > 4) return;
    final id = int.tryParse(parts[1]);
    if (id == null) return;
    if (parts[0] == 'reminder') await reminderAction(id, action!);
    if (parts[0] == 'habit' && action != 'snooze') {
      final habit = await habits.get(id);
      if (habit == null) return;
      final now = clock();
      // A daily alarm represents the most recent scheduled local day.
      var day = DateTime(
        now.year,
        now.month,
        now.day -
            (now.hour * 60 + now.minute <
                    (parts.length >= 3
                        ? int.tryParse(parts[2]) ?? habit.scheduleTime
                        : habit.scheduleTime)
                ? 1
                : 0),
      );
      if (parts.length == 4) {
        final explicit = DateTime.tryParse(parts[3]);
        if (explicit == null || explicit.isAfter(now)) return;
        day = explicit;
      } else if (habit.weekday != null) {
        day = DateTime(
          day.year,
          day.month,
          day.day - (day.weekday - habit.weekday! + 7) % 7,
        );
      }
      if (action == 'done' && habit.targetCount > 1) {
        final log = await habits.logFor(id, day);
        if (log?.status == EntryStatus.skipped ||
            log?.status == EntryStatus.completed) {
          return;
        }
        await habits.increment(id, day, 1);
        await scheduleHabit((await habits.get(id))!, await settings.get());
      } else {
        await habitAction(
          id,
          day,
          action == 'done' ? EntryStatus.completed : EntryStatus.skipped,
        );
      }
    }
  }
}
