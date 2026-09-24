import 'dart:convert';

import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/models.dart';
import 'package:aku_lupa/core/platform/android_integrations.dart';
import 'package:aku_lupa/core/platform/widget_service.dart';
import 'package:aku_lupa/features/habits/habit_repository.dart';
import 'package:aku_lupa/features/places/place_repository.dart';
import 'package:aku_lupa/features/places/place_service.dart';
import 'package:aku_lupa/features/reminders/reminder_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeIntegrations extends AndroidIntegrations {
  bool deny = false;
  final active = <int>{};
  final events = <String, dynamic>{};
  String? snapshot;
  @override
  Future<void> registerPlace(Map<String, dynamic> place) async {
    if (deny) throw PlatformException(code: 'permission');
    active.add(place['id'] as int);
  }

  @override
  Future<void> removePlace(int id) async {
    active.remove(id);
    events.remove('$id');
  }

  @override
  Future<Map<String, dynamic>> placeEvents() async => Map.of(events);
  @override
  Future<void> clearPlaces() async {
    active.clear();
    events.clear();
  }

  @override
  Future<void> updateWidget(String value) async {
    snapshot = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late PlaceRepository places;
  late FakeIntegrations platform;
  late PlaceService service;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    places = PlaceRepository(db);
    platform = FakeIntegrations();
    service = PlaceService(places, platform);
  });
  tearDown(() => db.close());
  test('a permission failure leaves saved location paused', () async {
    final p = await places.create('Sabun', 'Toko', -6, 106, 200);
    expect(p.isActive, false);
    platform.deny = true;
    await expectLater(
      service.toggle(p, true),
      throwsA(isA<PlatformException>()),
    );
    expect((await places.get(p.id))!.isActive, false);
    expect(platform.active, isEmpty);
  });
  test(
    'background entry persists single completion and can be rearmed',
    () async {
      final p = await places.create('Sabun', 'Toko', -6, 106, 200);
      await service.toggle(p, true);
      final when = DateTime(2026, 9, 24, 12);
      platform.events['${p.id}'] = when.millisecondsSinceEpoch;
      await service.refresh();
      final fired = (await places.get(p.id))!;
      expect(fired.isActive, false);
      expect(fired.triggeredAt, when);
      expect(platform.active, isEmpty);
      await service.toggle(fired, true);
      expect((await places.get(p.id))!.triggeredAt, isNull);
      expect(platform.active, {p.id});
    },
  );
  test(
    'failed replacement reestablishes surviving location registrations',
    () async {
      final p = await places.create('Sabun', 'Toko', 0, 0, 200);
      await service.toggle(p, true);
      await expectLater(
        service.replaceData(() async => throw StateError('fail')),
        throwsStateError,
      );
      expect(platform.active, {p.id});
    },
  );
  test(
    'widget includes snooze, recurring weekdays and completion logs',
    () async {
      final repo = ReminderRepository(db);
      final reminder = await repo.create('Kontrol', DateTime(2027, 1, 2, 9));
      await repo.snooze(reminder.id, DateTime(2027, 1, 2, 10));
      final done = await repo.create('Selesai', DateTime(2027));
      await repo.setStatus(done.id, EntryStatus.completed);
      final habits = HabitRepository(db);
      final habit = await habits.create('Olahraga', 390, weekday: 7);
      await habits.mark(habit.id, DateTime(2027, 1, 3), EntryStatus.skipped);
      final widget = WidgetService(db, platform);
      await widget.refresh();
      final snapshot = jsonDecode(platform.snapshot!);
      expect(snapshot['reminders'].length, 1);
      expect(
        snapshot['reminders'][0]['at'],
        DateTime(2027, 1, 2, 10).millisecondsSinceEpoch,
      );
      expect(snapshot['habits'][0]['weekday'], 7);
      expect(snapshot['logs'][0]['status'], 'skipped');
      await widget.dispose();
    },
  );
  test(
    'calendar bridge transfers exact title and epoch times without persisting',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidIntegrations.channel, (call) async {
            received = call;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(AndroidIntegrations.channel, null),
      );
      final at = DateTime(2027, 1, 2, 9);
      await const AndroidIntegrations().openCalendar('Kontrol psikiater', at);
      expect(received!.method, 'openCalendar');
      expect(received!.arguments, {
        'title': 'Kontrol psikiater',
        'start': at.millisecondsSinceEpoch,
        'end': at.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      });
    },
  );
}
