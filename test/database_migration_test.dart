import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/models.dart';
import 'package:aku_lupa/features/habits/habit_repository.dart';
import 'package:aku_lupa/features/memory/item_repository.dart';
import 'package:aku_lupa/features/settings/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1 data survives v2 upgrade and defaults remain daily', () async {
    // Original Phase 1 table definitions, before the five new v2 columns.
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (sqlite) {
          sqlite.execute('''
CREATE TABLE items (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, normalized_name TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE item_locations (id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE, location TEXT NOT NULL, photo_path TEXT, created_at INTEGER NOT NULL);
CREATE TABLE reminders (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, scheduled_at INTEGER NOT NULL, snoozed_until INTEGER, status TEXT NOT NULL DEFAULT 'pending', is_important INTEGER NOT NULL DEFAULT 0, calendar_event_id TEXT, created_at INTEGER NOT NULL);
CREATE TABLE habits (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, schedule_time INTEGER NOT NULL CHECK (schedule_time BETWEEN 0 AND 1439), repeat_pattern TEXT NOT NULL DEFAULT 'daily', is_active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL);
CREATE TABLE habit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE, date TEXT NOT NULL, status TEXT NOT NULL, completed_at INTEGER, UNIQUE(habit_id, date));
CREATE TABLE activity_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT, event_time INTEGER NOT NULL, created_at INTEGER NOT NULL);
CREATE TABLE user_settings (id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY, personality TEXT NOT NULL DEFAULT 'relaxed', CHECK (id = 1));
INSERT INTO items VALUES (1, 'Kunci', 'kunci', 1, 1);
INSERT INTO item_locations VALUES (1, 1, 'Laci', NULL, 1);
INSERT INTO habits VALUES (1, 'Sarapan', 480, 'daily', 1, 1);
INSERT INTO habit_logs VALUES (1, 1, '2026-09-22', 'completed', 1);
INSERT INTO habit_logs VALUES (2, 1, '2026-09-21', 'skipped', NULL);
INSERT INTO user_settings VALUES (1, 'strict');
PRAGMA user_version = 1;
''');
        },
      ),
    );
    addTearDown(db.close);
    final repo = HabitRepository(db);
    final old = (await repo.get(1))!;
    expect(old.weekday, isNull);
    expect(old.repeatPattern, RepeatPattern.daily);
    expect(old.targetCount, 1);
    expect((await repo.logFor(1, DateTime(2026, 9, 22)))!.progress, 1);
    expect((await repo.logFor(1, DateTime(2026, 9, 21)))!.progress, 0);
    expect(
      (await ItemRepository(db).find('kunci')).single.latest.location,
      'Laci',
    );
    expect(await SettingsRepository(db).get(), Personality.strict);
    final newHabit = await repo.create(
      'Air',
      360,
      targetCount: 10,
      unit: 'gelas',
      endMinutes: 1320,
    );
    await repo.increment(newHabit.id, DateTime(2026, 9, 22), 1);
    expect(
      (await repo.logFor(newHabit.id, DateTime(2026, 9, 22)))!.progress,
      1,
    );
  });
}
