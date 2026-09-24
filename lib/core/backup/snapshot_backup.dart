import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../photos/photo_service.dart';

/// Logical snapshots include committed rows and photos, never a live WAL file.
class LocalBackupService {
  LocalBackupService(
    this.db,
    this.photos, {
    Future<Directory> Function()? directory,
  }) : directory = directory ?? getTemporaryDirectory;
  final AppDatabase db;
  final PhotoService photos;
  final Future<Directory> Function() directory;
  static const maxBytes = 32 * 1024 * 1024;
  static const tables = [
    'items',
    'item_locations',
    'reminders',
    'habits',
    'habit_logs',
    'activity_logs',
    'user_settings',
    'place_reminders',
  ];

  Future<File> export() async {
    final data = await db.transaction(() async {
      final rows = <String, dynamic>{};
      final images = <String, String>{};
      var size = 0;
      for (final table in tables) {
        rows[table] = (await db.customSelect('SELECT * FROM $table').get())
            .map((r) => Map<String, dynamic>.from(r.data))
            .toList();
      }
      for (final row in rows['item_locations'] as List) {
        final path = row['photo_path'] as String?;
        if (path == null) continue;
        final file = File(path);
        size += await file.length();
        if (size > maxBytes * 3 ~/ 4) {
          throw const FormatException('Cadangan melebihi 32 MB.');
        }
        final key = '${row['id']}';
        images[key] = base64Encode(await file.readAsBytes());
        row['photo_path'] = key;
      }
      return {
        'format': 'akulupa-backup',
        'version': 1,
        'schema': db.schemaVersion,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'tables': rows,
        'photos': images,
      };
    });
    final bytes = utf8.encode(jsonEncode(data));
    if (bytes.length > maxBytes) {
      throw const FormatException('Cadangan melebihi 32 MB.');
    }
    return File(
      '${(await directory()).path}/akulupa-${DateTime.now().millisecondsSinceEpoch}.json',
    ).writeAsBytes(bytes, flush: true);
  }

  Future<BackupPreview> inspect(File file) async {
    if (await file.length() > maxBytes) {
      throw const FormatException('Cadangan melebihi 32 MB.');
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (data['format'] != 'akulupa-backup' ||
        data['version'] != 1 ||
        data['schema'] != 3) {
      throw const FormatException('Format atau versi cadangan tidak didukung.');
    }
    final rows = Map<String, dynamic>.from(data['tables'] as Map);
    if (rows.length != tables.length || !tables.every(rows.containsKey)) {
      throw const FormatException('Tabel cadangan tidak lengkap.');
    }
    final images = Map<String, dynamic>.from(data['photos'] as Map);
    for (final bytes in images.values) {
      final decoded = base64Decode(bytes as String);
      if (decoded.isEmpty || decoded.length > LocalPhotoService.maxBytes) {
        throw const FormatException('Foto cadangan tidak valid.');
      }
    }
    for (final row in rows['item_locations'] as List) {
      if (row['photo_path'] != null && !images.containsKey(row['photo_path'])) {
        throw const FormatException('Foto cadangan tidak lengkap.');
      }
    }
    // Validate constraints in a disposable database before changing user data.
    final scratch = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await scratch.customSelect('SELECT 1 FROM user_settings').get();
      await _replace(scratch, rows);
      await scratch.select(scratch.items).get();
      await scratch.select(scratch.itemLocations).get();
      await scratch.select(scratch.reminders).get();
      await scratch.select(scratch.habitLogs).get();
      await scratch.select(scratch.activityLogs).get();
      await scratch.select(scratch.userSettings).get();
      for (final h in await scratch.select(scratch.habits).get()) {
        if (h.targetCount < 1 ||
            (h.weekday != null && (h.weekday! < 1 || h.weekday! > 7)) ||
            (h.endTime != null &&
                (h.endTime! <= h.scheduleTime || h.endTime! > 1439))) {
          throw const FormatException('Jadwal rutinitas tidak valid.');
        }
      }
      for (final p in await scratch.select(scratch.placeReminders).get()) {
        if (!p.latitude.isFinite ||
            p.latitude.abs() > 90 ||
            !p.longitude.isFinite ||
            p.longitude.abs() > 180 ||
            p.radius < 100 ||
            p.radius > 2000) {
          throw const FormatException('Lokasi cadangan tidak valid.');
        }
      }
    } finally {
      await scratch.close();
    }
    return BackupPreview._(data, DateTime.parse(data['createdAt'] as String));
  }

  Future<void> restore(BackupPreview preview) async {
    final rows =
        jsonDecode(jsonEncode(preview._data['tables'])) as Map<String, dynamic>;
    final images = preview._data['photos'] as Map;
    final staged = <String>[];
    try {
      for (final row in rows['item_locations'] as List) {
        final key = row['photo_path'];
        if (key == null) continue;
        final path = await photos.store(
          PreparedPhoto(base64Decode(images[key] as String)),
        );
        staged.add(path);
        row['photo_path'] = path;
      }
      for (final row in rows['reminders'] as List) {
        row['calendar_event_id'] = null;
      }
      // Location consent must be renewed on the destination installation.
      for (final row in rows['place_reminders'] as List) {
        row['is_active'] = 0;
      }
      await _replace(db, rows);
    } catch (_) {
      for (final path in staged) {
        await photos.discard(path);
      }
      rethrow;
    }
  }

  static Future<void> _replace(
    AppDatabase target,
    Map<String, dynamic> rows,
  ) => target.transaction(() async {
    for (final table in tables.reversed) {
      await target.customStatement('DELETE FROM $table');
    }
    for (final name in tables) {
      final table = target.allTables.singleWhere(
        (t) => t.actualTableName == name,
      );
      final columns = table.$columns.map((c) => c.$name).toList();
      for (final raw in rows[name] as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        if (row.length != columns.length ||
            !columns.every(row.containsKey) ||
            row['id'] is! int ||
            (row['id'] as int) < 1) {
          throw const FormatException('Baris cadangan tidak valid.');
        }
        for (final key in ['status', 'repeat_pattern', 'personality']) {
          final allowed = switch (key) {
            'status' => ['pending', 'completed', 'skipped'],
            'repeat_pattern' => ['daily', 'weekly'],
            _ => ['relaxed', 'strict'],
          };
          if (row.containsKey(key) && !allowed.contains(row[key])) {
            throw const FormatException('Nilai cadangan tidak valid.');
          }
        }
        await target.customStatement(
          'INSERT INTO $name (${columns.join(',')}) VALUES (${columns.map((_) => '?').join(',')})',
          columns.map((c) => row[c]).toList(),
        );
      }
    }
    if ((await target.customSelect('PRAGMA foreign_key_check').get())
        .isNotEmpty) {
      throw const FormatException('Relasi cadangan tidak lengkap.');
    }
    target.notifyUpdates(
      target.allTables.map((t) => TableUpdate(t.actualTableName)).toSet(),
    );
  });
}

class BackupPreview {
  BackupPreview._(this._data, this.createdAt);
  final Map<String, dynamic> _data;
  final DateTime createdAt;
  int get records => (_data['tables'] as Map).entries
      .where((e) => e.key != 'user_settings')
      .fold(0, (n, e) => n + (e.value as List).length);
  int get photoCount => (_data['photos'] as Map).length;
}
