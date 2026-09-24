import 'package:aku_lupa/core/notifications/notification_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  setUp(() {
    data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  for (final weekly in [false, true]) {
    test(
      'native calendar repeat keeps exact deferred start, weekly=$weekly',
      () async {
        final gateway = AndroidNotificationGateway()..initialized = true;
        await gateway.schedule(
          Alarm(
            id: -1,
            title: 'Minum air',
            body: 'Target 10 gelas',
            at: tz.TZDateTime(tz.local, 2030, 1, 13, 6, 30),
            payload: 'habit:1:390',
            daily: !weekly,
            weekly: weekly,
            doneLabel: '+1 gelas',
          ),
        );
        final arguments = calls.single.arguments as Map;
        expect(calls.single.method, 'zonedSchedule');
        expect(arguments['scheduledDateTime'], '2030-01-13T06:30:00.000');
        expect(arguments['timeZoneName'], 'Asia/Jakarta');
        expect(
          arguments['scheduledNotificationRepeatFrequency'],
          weekly ? 1 : 0,
        );
        expect(arguments.containsKey('matchDateTimeComponents'), isFalse);
        final specifics = arguments['platformSpecifics'] as Map;
        expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
        final actions = specifics['actions'] as List;
        expect(actions.map((a) => a['id']), ['done', 'skip']);
        expect(actions.first['title'], '+1 gelas');
      },
    );
  }
}
