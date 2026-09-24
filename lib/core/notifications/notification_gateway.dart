import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'android_recurrence.dart';

class Alarm {
  const Alarm({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.payload,
    this.daily = false,
    this.weekly = false,
    this.doneLabel = 'Sudah',
  });
  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String payload;
  final bool daily;
  final bool weekly;
  final String doneLabel;
}

abstract interface class NotificationGateway {
  Future<void> schedule(Alarm alarm);
  Future<void> cancel(int id);
  Future<void> cancelHabit(int id);
}

class AndroidNotificationGateway implements NotificationGateway {
  final plugin = FlutterLocalNotificationsPlugin();
  bool exact = false;
  bool enabled = false;
  bool initialized = false;
  AndroidFlutterLocalNotificationsPlugin? get android => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<NotificationResponse?> initialize(
    void Function(NotificationResponse) onAction,
  ) async {
    tz_data.initializeTimeZones();
    await refreshTimezone();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_memory'),
      ),
      onDidReceiveNotificationResponse: onAction,
    );
    initialized = true;
    await refreshPermissions();
    final launch = await plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse
        : null;
  }

  Future<void> refreshTimezone() async {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  }

  Future<void> refreshPermissions() async {
    enabled = await android?.areNotificationsEnabled() ?? false;
    exact = await android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestPermissions({bool requestExact = false}) async {
    await android?.requestNotificationsPermission();
    if (requestExact) await android?.requestExactAlarmsPermission();
    await refreshPermissions();
  }

  @override
  Future<void> cancel(int id) => plugin.cancel(id: id);
  @override
  Future<void> cancelHabit(int id) async {
    final ids = <int>{-id};
    for (final n in await plugin.pendingNotificationRequests()) {
      if (n.payload == 'habit:$id' ||
          (n.payload?.startsWith('habit:$id:') ?? false)) {
        ids.add(n.id);
      }
    }
    for (final n in await plugin.getActiveNotifications()) {
      final value = n.id;
      if (value != null &&
          value <= -(1000000 + id * 1024) &&
          value > -(1000000 + (id + 1) * 1024)) {
        ids.add(value);
      }
    }
    for (final value in ids) {
      await cancel(value);
    }
  }

  @override
  Future<void> schedule(Alarm alarm) async {
    if (!initialized) throw StateError('Notifikasi belum siap.');
    final details = AndroidNotificationDetails(
      'aku_lupa_reminders',
      'Pengingat Aku Lupa',
      channelDescription: 'Pengingat dan rutinitas pribadi',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(
          'done',
          alarm.doneLabel,
          showsUserInterface: true,
        ),
        if (alarm.payload.startsWith('reminder:'))
          const AndroidNotificationAction(
            'snooze',
            'Ingatkan lagi 10 menit',
            showsUserInterface: true,
          ),
        const AndroidNotificationAction(
          'skip',
          'Lewati',
          showsUserInterface: true,
        ),
      ],
    );
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final at = tz.TZDateTime.from(alarm.at, tz.local);
    if (alarm.daily || alarm.weekly) {
      await scheduleAndroidRecurrence(
        id: alarm.id,
        title: alarm.title,
        body: alarm.body,
        payload: alarm.payload,
        at: at,
        weekly: alarm.weekly,
        details: details,
        mode: mode,
      );
      return;
    }
    await plugin.zonedSchedule(
      id: alarm.id,
      title: alarm.title,
      body: alarm.body,
      scheduledDate: at,
      notificationDetails: NotificationDetails(android: details),
      androidScheduleMode: mode,
      payload: alarm.payload,
    );
  }
}
