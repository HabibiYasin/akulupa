import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models.dart';

part 'app_database.g.dart';

class Items extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class ItemLocations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().references(Items, #id, onDelete: KeyAction.cascade)();
  TextColumn get location => text()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();
  TextColumn get status =>
      textEnum<EntryStatus>().withDefault(const Constant('pending'))();
  BoolColumn get isImportant => boolean().withDefault(const Constant(false))();
  TextColumn get calendarEventId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get scheduleTime => integer().customConstraint(
    'NOT NULL CHECK (schedule_time BETWEEN 0 AND 1439)',
  )();
  TextColumn get repeatPattern =>
      textEnum<RepeatPattern>().withDefault(const Constant('daily'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get weekday => integer().nullable()();
  IntColumn get targetCount => integer().withDefault(const Constant(1))();
  TextColumn get unit => text().nullable()();
  IntColumn get endTime => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class HabitLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  // Civil date, never UTC: one row per local calendar day.
  TextColumn get date => text()();
  TextColumn get status => textEnum<EntryStatus>()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  @override
  List<Set<Column>> get uniqueKeys => [
    {habitId, date},
  ];
}

class ActivityLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get eventTime => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class UserSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get personality =>
      textEnum<Personality>().withDefault(const Constant('relaxed'))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

class PlaceReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get placeName => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get radius => integer().withDefault(const Constant(200))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get triggeredAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(
  tables: [
    Items,
    ItemLocations,
    Reminders,
    Habits,
    HabitLogs,
    ActivityLogs,
    UserSettings,
    PlaceReminders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'aku_lupa'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(habits, habits.weekday);
        await m.addColumn(habits, habits.targetCount);
        await m.addColumn(habits, habits.unit);
        await m.addColumn(habits, habits.endTime);
        await m.addColumn(habitLogs, habitLogs.progress);
        await customStatement(
          "UPDATE habit_logs SET progress = 1 WHERE status = 'completed'",
        );
      }
      if (from < 3) await m.createTable(placeReminders);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await into(
        userSettings,
      ).insert(const UserSettingsCompanion(), mode: InsertMode.insertOrIgnore);
    },
  );
}
