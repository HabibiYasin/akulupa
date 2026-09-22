import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models.dart';

class ActivityRepository {
  ActivityRepository(this.db);
  final AppDatabase db;
  Stream<List<ActivityLog>> watchAll() =>
      (db.select(db.activityLogs)..orderBy([
            (t) => OrderingTerm.desc(t.eventTime),
            (t) => OrderingTerm.desc(t.id),
          ]))
          .watch();
  Future<void> create(
    String title,
    DateTime eventTime, {
    String? description,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Aktivitas wajib diisi.');
    if (eventTime.isAfter(DateTime.now())) {
      throw ArgumentError('Aktivitas tidak boleh berada di masa depan.');
    }
    await db
        .into(db.activityLogs)
        .insert(
          ActivityLogsCompanion.insert(
            title: title.trim(),
            eventTime: eventTime,
            createdAt: DateTime.now(),
            description: Value(description),
          ),
        );
  }

  Future<ActivityLog?> latest(String query) async {
    final entries = await watchAll().first;
    final matches = entries.where(
      (a) => normalize(a.title).contains(normalize(query)),
    );
    return matches.firstOrNull;
  }
}
