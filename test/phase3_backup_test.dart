import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aku_lupa/core/backup/backup_service.dart';
import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/models.dart';
import 'package:aku_lupa/core/photos/photo_service.dart';
import 'package:aku_lupa/features/activity/activity_repository.dart';
import 'package:aku_lupa/features/habits/habit_repository.dart';
import 'package:aku_lupa/features/memory/item_repository.dart';
import 'package:aku_lupa/features/places/place_repository.dart';
import 'package:aku_lupa/features/reminders/reminder_repository.dart';
import 'package:aku_lupa/features/settings/settings_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late AppDatabase db;
  late LocalPhotoService photos;
  late LocalBackupService backups;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('akulupa-backup-test-');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    photos = LocalPhotoService(directory: () async => directory);
    backups = LocalBackupService(db, photos, directory: () async => directory);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test('round trip includes every table, progress, photo bytes and paused locations', () async {
    final bytes = Uint8List.fromList([255, 216, 255, 217]);
    final path = await photos.store(PreparedPhoto(bytes));
    await ItemRepository(db).save('Kunci', 'Laci', photoPath: path);
    await ItemRepository(db).save('Kunci', 'Meja');
    final reminder = await ReminderRepository(db)
        .create('Psikiater', DateTime(2027, 1, 2, 9), important: true);
    await (db.update(db.reminders)..where((t) => t.id.equals(reminder.id)))
        .write(const RemindersCompanion(calendarEventId: Value('old-account')));
    final habit = await HabitRepository(db)
        .create('Air', 360, targetCount: 10, unit: 'gelas', endMinutes: 1320);
    await HabitRepository(db).increment(habit.id, DateTime(2026, 9, 24), 2);
    await ActivityRepository(db).create('Olahraga', DateTime(2026, 9, 24));
    await SettingsRepository(db).set(Personality.strict);
    final place = await PlaceRepository(db)
        .create('Beli sabun', 'Toko', -6.2, 106.8, 200);
    await PlaceRepository(db).setActive(place.id, true);
    final file = await backups.export();
    expect(
      await file.readAsString(),
      isNot(contains(path.replaceAll(r'\', r'\\'))),
    );
    final preview = await backups.inspect(file);
    expect(preview.photoCount, 1);
    await ItemRepository(db).save('Dompet', 'Tas');
    await backups.restore(preview);
    expect(await ItemRepository(db).find('Dompet'), isEmpty);
    expect(
      (await ItemRepository(db).find('Kunci')).single.latest.location,
      'Meja',
    );
    final restoredPhoto =
        (await db.select(db.itemLocations).get()).first.photoPath!;
    expect(restoredPhoto, isNot(path));
    expect(await File(restoredPhoto).readAsBytes(), bytes);
    expect(
      (await ReminderRepository(db).get(reminder.id))!.calendarEventId,
      isNull,
    );
    expect(
      (await HabitRepository(
        db,
      ).logFor(habit.id, DateTime(2026, 9, 24)))!.progress,
      2,
    );
    expect(await SettingsRepository(db).get(), Personality.strict);
    expect((await PlaceRepository(db).get(place.id))!.isActive, false);
    expect((await db.select(db.activityLogs).get()).single.title, 'Olahraga');
  });

  for (final corruption in [
    'missing-table',
    'foreign-key',
    'unknown-status',
    'bad-location',
    'missing-photo',
    'extra-column',
  ]) {
    test('rejects $corruption before replacing existing records', () async {
      await ItemRepository(db).save('Kunci', 'Laci');
      await ReminderRepository(db).create('Kontrol', DateTime(2027));
      await PlaceRepository(db).create('Sabun', 'Toko', 0, 0, 200);
      final file = await backups.export();
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final tables = data['tables'] as Map;
      switch (corruption) {
        case 'missing-table':
          tables.remove('habits');
        case 'foreign-key':
          tables['item_locations'][0]['item_id'] = 999;
        case 'unknown-status':
          tables['reminders'][0]['status'] = 'invalid';
        case 'bad-location':
          tables['place_reminders'][0]['latitude'] = 100;
        case 'missing-photo':
          tables['item_locations'][0]['photo_path'] = '../../secret';
        case 'extra-column':
          tables['items'][0]['injected'] = 'value';
      }
      await file.writeAsString(jsonEncode(data));
      await expectLater(backups.inspect(file), throwsA(anything));
      expect(
        (await ItemRepository(db).find('Kunci')).single.latest.location,
        'Laci',
      );
    });
  }
  test(
    'failed restore rolls back rows and cleans newly staged photos',
    () async {
      final path = await photos.store(
        PreparedPhoto(Uint8List.fromList([1, 2, 3])),
      );
      await ItemRepository(db).save('Kunci', 'Laci', photoPath: path);
      final preview = await backups.inspect(await backups.export());
      await ItemRepository(db).save('Dompet', 'Tas');
      await db.customStatement(
        "CREATE TRIGGER reject_restore BEFORE INSERT ON items BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      final before = await Directory('${directory.path}/photos').list().length;
      await expectLater(backups.restore(preview), throwsA(anything));
      expect(
        (await ItemRepository(db).find('Dompet')).single.latest.location,
        'Tas',
      );
      expect(await Directory('${directory.path}/photos').list().length, before);
    },
  );
  test('rejects oversized import', () async {
    final file = File('${directory.path}/large.json');
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(LocalBackupService.maxBytes + 1);
    await handle.close();
    await expectLater(backups.inspect(file), throwsFormatException);
  });
  test('v2 migration retains rows and creates locations table', () async {
    final file = File('${directory.path}/v2.sqlite');
    final original = AppDatabase.forTesting(NativeDatabase(file));
    await ItemRepository(original).save('Kunci', 'Laci');
    await original.customStatement('DROP TABLE place_reminders');
    await original.customStatement('PRAGMA user_version = 2');
    await original.close();
    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    try {
      expect(
        (await ItemRepository(upgraded).find('Kunci')).single.latest.location,
        'Laci',
      );
      expect(await PlaceRepository(upgraded).all(), isEmpty);
      await PlaceRepository(upgraded).create('Sabun', 'Toko', -6, 106, 200);
      expect((await PlaceRepository(upgraded).all()).length, 1);
    } finally {
      await upgraded.close();
    }
  });
}
