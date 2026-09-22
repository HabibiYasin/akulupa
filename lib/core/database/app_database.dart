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

@DriftDatabase(
  tables: [
    Items,
    ItemLocations,
    Reminders,
    Habits,
    HabitLogs,
    ActivityLogs,
    UserSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'aku_lupa'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Add explicit from/to migrations here when schemaVersion is increased.
    onUpgrade: (m, from, to) async {
      throw StateError('Migrasi database $from → $to belum tersedia.');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await into(
        userSettings,
      ).insert(const UserSettingsCompanion(), mode: InsertMode.insertOrIgnore);
    },
  );
}
