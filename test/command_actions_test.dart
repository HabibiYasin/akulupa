import 'package:aku_lupa/core/command_actions.dart';
import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/models.dart';
import 'package:aku_lupa/core/notifications/habit_alarm_planner.dart';
import 'package:aku_lupa/core/parser/command_parser.dart';
import 'package:aku_lupa/features/habits/habit_repository.dart';
import 'package:aku_lupa/features/reminders/reminder_repository.dart';
import 'package:aku_lupa/features/memory/item_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  late AppDatabase db;
  late CommandActions actions;
  late HabitRepository habits;
  late ReminderRepository reminders;
  final now = DateTime.utc(2030, 1, 1, 5);
  ParsedCommand parse(String value) =>
      IndonesianCommandParser().parse(value, now: now);
  setUp(() async {
    await initializeDateFormatting('id_ID');
    data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    actions = CommandActions(db, clock: () => now);
    habits = HabitRepository(db);
    reminders = ReminderRepository(db);
  });
  tearDown(() => db.close());
  test('item status uses keyword selection and appends history without creating a duplicate', () async {
    final repo = ItemRepository(db);
    await repo.save('Charger laptop Lenovo', 'dipinjam budi');
    await repo.save('Charger laptop Asus', 'tas');
    final command = parse('charger laptop udah diambil');
    final matches = await actions.candidates(command);
    expect(matches, hasLength(2));
    final selected = matches.singleWhere((m) => m.title.contains('Lenovo'));
    await actions.apply(command, {selected.id});
    final updated = (await repo.find('Lenovo')).single;
    expect(updated.latest.location, 'sudah diambil');
    expect(updated.locations, hasLength(2));
    expect((await repo.find('Asus')).single.latest.location, 'tas');
    expect(await actions.candidates(parse('dompet udah diambil')), isEmpty);
    expect(await repo.find(''), hasLength(2));
  });
  test('cancel bangun besok matches all hours but no other date/title; preview does not write', () async {
    final first = await reminders.create('Bangun', DateTime(2030, 1, 2, 6));
    final second = await reminders.create(
      'Bangun tidur',
      DateTime(2030, 1, 2, 15),
    );
    final otherDay = await reminders.create('Bangun', DateTime(2030, 1, 3, 6));
    final other = await reminders.create('Sarapan', DateTime(2030, 1, 2, 6));
    final command = parse('jangan bangunkan aku besok pagi');
    final matches = await actions.candidates(command);
    expect(matches.map((m) => m.id), unorderedEquals([first.id, second.id]));
    expect(
      (await reminders.all()).every((r) => r.status == EntryStatus.pending),
      isTrue,
    );
    await actions.apply(command, matches.map((m) => m.id).toSet());
    expect((await reminders.get(first.id))!.status, EntryStatus.skipped);
    expect((await reminders.get(second.id))!.status, EntryStatus.skipped);
    expect((await reminders.get(otherDay.id))!.status, EntryStatus.pending);
    expect((await reminders.get(other.id))!.status, EntryStatus.pending);
  });
  test(
    'keyword cancellation permits selected subset and rechecks stale selection',
    () async {
      final first = await reminders.create('Mie ayam', DateTime(2030, 1, 2, 8));
      final second = await reminders.create(
        'Makan mie ayam bareng Budi',
        DateTime(2030, 1, 3, 8),
      );
      final command = parse('ga jadi makan mie ayam');
      expect(await actions.candidates(command), hasLength(2));
      await actions.apply(command, {first.id});
      expect((await reminders.get(second.id))!.status, EntryStatus.pending);
      await expectLater(
        actions.apply(command, {first.id, second.id}),
        throwsStateError,
      );
      expect((await reminders.get(second.id))!.status, EntryStatus.pending);
    },
  );
  test(
    'skip nearest Sunday preserves routine and resumes following Sunday',
    () async {
      final habit = await habits.create('Olahraga', 390, weekday: 7);
      final command = parse('minggu pagi ini skip olahraga dulu');
      expect(command.date, DateTime(2030, 1, 6));
      await actions.apply(command, {habit.id});
      expect((await habits.get(habit.id))!.isActive, isTrue);
      final alarms = HabitAlarmPlanner().plan(
        habit,
        await habits.logsFor(habit.id),
        now,
        Personality.relaxed,
      );
      expect(alarms, hasLength(1));
      expect(alarms.single.weekly, isTrue);
      expect(alarms.single.at, tz.TZDateTime(tz.UTC, 2030, 1, 13, 6, 30));
    },
  );
  test('future exception on daily habit schedules intervening days and resumes native repeat', () async {
    final habit = await habits.create('Olahraga', 390);
    await habits.mark(habit.id, DateTime(2030, 1, 6), EntryStatus.skipped);
    final alarms = HabitAlarmPlanner().plan(
      habit,
      await habits.logsFor(habit.id),
      now,
      Personality.relaxed,
    );
    expect(alarms.where((a) => !a.daily).map((a) => a.at.day), [1, 2, 3, 4, 5]);
    expect(alarms.last.at, tz.TZDateTime(tz.UTC, 2030, 1, 7, 6, 30));
    expect(alarms.last.daily, isTrue);
    expect(alarms.map((a) => a.id).toSet().length, alarms.length);
  });
  test('10 glasses persists progress, stops today on completion, resets on next day', () async {
    final habit = await habits.create(
      'Minum air',
      360,
      targetCount: 10,
      unit: 'gelas',
      endMinutes: 1320,
    );
    var alarms = HabitAlarmPlanner().plan(habit, [], now, Personality.relaxed);
    expect(alarms, hasLength(10));
    expect(alarms.first.at.hour, 6);
    expect(alarms.last.at.hour, 22);
    final command = parse('sudah minum segelas');
    await actions.apply(command, {habit.id});
    expect((await HabitRepository(db).logFor(habit.id, now))!.progress, 1);
    expect((await habits.logFor(habit.id, now))!.status, EntryStatus.pending);
    await habits.increment(habit.id, now, 20);
    expect((await habits.logFor(habit.id, now))!.progress, 10);
    expect((await habits.logFor(habit.id, now))!.status, EntryStatus.completed);
    alarms = HabitAlarmPlanner().plan(
      habit,
      await habits.logsFor(habit.id),
      now,
      Personality.relaxed,
    );
    expect(alarms.every((a) => a.at.day == 2 && a.daily), isTrue);
    expect(await habits.logFor(habit.id, DateTime(2030, 1, 2)), isNull);
    await habits.increment(habit.id, DateTime(2030, 1, 2), 1);
    expect((await habits.logFor(habit.id, DateTime(2030, 1, 2)))!.progress, 1);
  });
  test(
    'ambiguous minum returns choices, only chosen routine changes',
    () async {
      final first = await habits.create(
        'Minum air',
        360,
        targetCount: 10,
        unit: 'gelas',
        endMinutes: 1320,
      );
      final second = await habits.create(
        'Minum air kantor',
        480,
        targetCount: 3,
        unit: 'gelas',
        endMinutes: 1020,
      );
      await habits.create('Minum obat', 480);
      final command = parse('sudah minum segelas');
      expect(await actions.candidates(command), hasLength(2));
      await expectLater(
        actions.apply(command, {first.id, second.id}),
        throwsArgumentError,
      );
      await actions.apply(command, {second.id});
      expect(await habits.logFor(first.id, now), isNull);
      expect((await habits.logFor(second.id, now))!.progress, 1);
    },
  );
  test(
    'reject invalid target, wrong weekday, and ambiguous skip date',
    () async {
      expect(
        () => habits.create(
          'Minum',
          1320,
          targetCount: 10,
          unit: 'gelas',
          endMinutes: 360,
        ),
        throwsArgumentError,
      );
      final habit = await habits.create('Olahraga', 390, weekday: 7);
      await expectLater(
        habits.mark(habit.id, now, EntryStatus.skipped),
        throwsArgumentError,
      );
      await expectLater(
        actions.candidates(parse('minggu depan skip olahraga')),
        throwsArgumentError,
      );
    },
  );
}
