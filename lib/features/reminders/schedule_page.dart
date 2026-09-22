import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models.dart';
import '../../core/utils/dates.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

class ReminderTile extends ConsumerWidget {
  const ReminderTile({super.key, required this.reminder});
  final Reminder reminder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = reminder.status == EntryStatus.pending;
    final at = reminder.snoozedUntil ?? reminder.scheduledAt;
    final overdue = pending && at.isBefore(DateTime.now());
    return Card(
      child: ListTile(
        leading: IconButton(
          tooltip: pending ? 'Tandai sudah' : 'Selesai',
          onPressed: pending
              ? () => runAction(
                  context,
                  () => ref
                      .read(servicesProvider)
                      .reminderAction(reminder.id, 'done'),
                )
              : null,
          icon: Icon(
            pending
                ? Icons.radio_button_unchecked
                : reminder.status == EntryStatus.completed
                ? Icons.check_circle
                : Icons.skip_next,
            color: pending ? muted : ink,
          ),
        ),
        title: Text(
          reminder.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: pending ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '${dateTimeText(at)}${overdue ? ' · Terlewat' : ''}${reminder.isImportant ? ' · Penting' : ''}${reminder.status == EntryStatus.skipped ? ' · Dilewati' : ''}',
          style: TextStyle(color: overdue ? const Color(0xFFA15B24) : muted),
        ),
        trailing: pending
            ? PopupMenuButton<String>(
                tooltip: 'Tindakan pengingat',
                onSelected: (action) => runAction(
                  context,
                  () => ref
                      .read(servicesProvider)
                      .reminderAction(reminder.id, action),
                ),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'done', child: Text('Sudah')),
                  PopupMenuItem(
                    value: 'snooze',
                    child: Text('Ingatkan lagi 10 menit'),
                  ),
                  PopupMenuItem(value: 'skip', child: Text('Lewati')),
                ],
              )
            : null,
      ),
    );
  }
}

class HabitTile extends ConsumerWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.status,
    this.manage = false,
  });
  final Habit habit;
  final EntryStatus status;
  final bool manage;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: IconButton(
        tooltip: status == EntryStatus.completed
            ? 'Batalkan selesai hari ini'
            : 'Selesai hari ini',
        onPressed: habit.isActive
            ? () => runAction(
                context,
                () => ref
                    .read(servicesProvider)
                    .markHabit(
                      habit.id,
                      status == EntryStatus.completed
                          ? EntryStatus.pending
                          : EntryStatus.completed,
                    ),
              )
            : null,
        icon: Icon(
          status == EntryStatus.completed
              ? Icons.check_circle
              : status == EntryStatus.skipped
              ? Icons.skip_next
              : Icons.radio_button_unchecked,
          color: status == EntryStatus.completed ? ink : muted,
        ),
      ),
      title: Text(
        habit.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${minutesText(habit.scheduleTime)} · ${habit.isActive ? 'Setiap hari' : 'Dijeda'}${status == EntryStatus.skipped ? ' · Hari ini dilewati' : ''}',
      ),
      trailing: manage
          ? PopupMenuButton<String>(
              tooltip: 'Tindakan rutinitas',
              onSelected: (action) => runAction(
                context,
                () => action == 'toggle'
                    ? ref.read(servicesProvider).toggleHabit(habit)
                    : ref
                          .read(servicesProvider)
                          .markHabit(habit.id, EntryStatus.skipped),
              ),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(
                    habit.isActive ? 'Jeda rutinitas' : 'Aktifkan rutinitas',
                  ),
                ),
                if (habit.isActive)
                  const PopupMenuItem(
                    value: 'skip',
                    child: Text('Lewati hari ini'),
                  ),
              ],
            )
          : const Icon(Icons.repeat, size: 18, color: muted),
    ),
  );
}

EntryStatus statusFor(List<HabitLog> logs, int habitId, DateTime now) =>
    logs
        .where((l) => l.habitId == habitId && l.date == dayKey(now))
        .firstOrNull
        ?.status ??
    EntryStatus.pending;

class TodaySchedule extends ConsumerWidget {
  const TodaySchedule({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    return AsyncSection(
      value: ref.watch(remindersProvider),
      builder: (reminders) => AsyncSection(
        value: ref.watch(habitsProvider),
        builder: (habits) => AsyncSection(
          value: ref.watch(habitLogsProvider),
          builder: (logs) {
            final rows = <({int minutes, Widget child})>[
              for (final r in reminders.where(
                (r) => dayKey(r.snoozedUntil ?? r.scheduledAt) == dayKey(now),
              ))
                (
                  minutes:
                      (r.snoozedUntil ?? r.scheduledAt).hour * 60 +
                      (r.snoozedUntil ?? r.scheduledAt).minute,
                  child: ReminderTile(reminder: r),
                ),
              for (final h in habits.where((h) => h.isActive))
                (
                  minutes: h.scheduleTime,
                  child: HabitTile(
                    habit: h,
                    status: statusFor(logs, h.id, now),
                  ),
                ),
            ]..sort((a, b) => a.minutes.compareTo(b.minutes));
            final overdue = reminders
                .where(
                  (r) =>
                      r.status == EntryStatus.pending &&
                      dayKey(r.snoozedUntil ?? r.scheduledAt)
                              .compareTo(dayKey(now)) <
                          0,
                )
                .length;
            return Column(
              children: [
                if (overdue > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$overdue pengingat sebelumnya belum selesai. Lihat di Jadwal.',
                      style: const TextStyle(color: Color(0xFFA15B24)),
                    ),
                  ),
                if (rows.isEmpty)
                  const EmptyCard(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Hari ini masih lapang',
                    subtitle: 'Tambahkan pengingat atau rutinitas dari kolom di atas.',
                  )
                else
                  ...rows.map((r) => r.child),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          'Satu per satu.',
          'Pengingat dan kebiasaan kecil yang membuat hari lebih teratur.',
        ),
        const SectionTitle('Pengingat'),
        AsyncSection(
          value: ref.watch(remindersProvider),
          builder: (rows) => rows.isEmpty
              ? const EmptyCard(
                  icon: Icons.notifications_none,
                  title: 'Belum ada pengingat',
                  subtitle:
                      'Coba “Ingatkan besok jam 8 pagi meeting” di Beranda.',
                )
              : Column(
                  children: [
                    for (final r in rows.where(
                      (r) => r.status == EntryStatus.pending,
                    ))
                      ReminderTile(reminder: r),
                    if (rows.any((r) => r.status != EntryStatus.pending))
                      ExpansionTile(
                        title: const Text('Selesai & dilewati'),
                        children: [
                          for (final r in rows.where(
                            (r) => r.status != EntryStatus.pending,
                          ))
                            ReminderTile(reminder: r),
                        ],
                      ),
                  ],
                ),
        ),
        const SectionTitle('Rutinitas harian'),
        AsyncSection(
          value: ref.watch(habitsProvider),
          builder: (habits) => AsyncSection(
            value: ref.watch(habitLogsProvider),
            builder: (logs) => habits.isEmpty
                ? const EmptyCard(
                    icon: Icons.repeat,
                    title: 'Mulai kebiasaan kecil',
                    subtitle:
                        'Coba “Sikat gigi setiap malam jam 9” di Beranda.',
                  )
                : Column(
                    children: [
                      for (final h in habits)
                        HabitTile(
                          habit: h,
                          status: statusFor(logs, h.id, now),
                          manage: true,
                        ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        title: const Text('Riwayat rutinitas'),
                        children: [
                          if (logs.isEmpty)
                            const ListTile(
                              title: Text('Belum ada rutinitas yang ditandai.'),
                            ),
                          for (final log in logs.take(60))
                            ListTile(
                              title: Text(
                                habits
                                        .where((h) => h.id == log.habitId)
                                        .firstOrNull
                                        ?.title ??
                                    'Rutinitas',
                              ),
                              subtitle: Text(log.date),
                              trailing: Text(switch (log.status) {
                                EntryStatus.completed => 'Selesai',
                                EntryStatus.skipped => 'Dilewati',
                                EntryStatus.pending => 'Belum',
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
