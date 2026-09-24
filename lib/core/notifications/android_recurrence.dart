import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Pinned 22.3.1 adapter: the public date-component API discards a future
// start date on Android. Its native calendar-repeat field preserves that date.
// Keep this isolated and verify the native contract before upgrading the plugin.
// ignore: implementation_imports
import 'package:flutter_local_notifications/src/platform_specifics/android/method_channel_mappers.dart';
import 'package:timezone/timezone.dart' as tz;

Future<void> scheduleAndroidRecurrence({
  required int id,
  required String title,
  required String body,
  required String payload,
  required tz.TZDateTime at,
  required bool weekly,
  required AndroidNotificationDetails details,
  required AndroidScheduleMode mode,
}) {
  final civil = DateTime(
    at.year,
    at.month,
    at.day,
    at.hour,
    at.minute,
    at.second,
  );
  return const MethodChannel('dexterous.com/flutter/local_notifications')
      .invokeMethod<void>('zonedSchedule', {
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        'timeZoneName': at.location.name,
        'scheduledDateTime': civil.toIso8601String(),
        'scheduledNotificationRepeatFrequency': weekly ? 1 : 0,
        'platformSpecifics': {...details.toMap(), 'scheduleMode': mode.name},
      });
}
