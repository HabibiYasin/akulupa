import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class Alarm {
  const Alarm({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.payload,
    this.daily = false,
  });
  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String payload;
  final bool daily;
}

abstract interface class NotificationGateway {
  Future<void> schedule(Alarm alarm);
  Future<void> cancel(int id);
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
  Future<void> schedule(Alarm alarm) async {
    if (!initialized) throw StateError('Notifikasi belum siap.');
    await plugin.zonedSchedule(
      id: alarm.id,
      title: alarm.title,
      body: alarm.body,
      scheduledDate: tz.TZDateTime.from(alarm.at, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'aku_lupa_reminders',
          'Pengingat Aku Lupa',
          channelDescription: 'Pengingat dan rutinitas pribadi',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            const AndroidNotificationAction(
              'done',
              'Sudah',
              showsUserInterface: true,
            ),
            if (!alarm.daily)
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
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: alarm.daily ? DateTimeComponents.time : null,
      payload: alarm.payload,
    );
  }
}
