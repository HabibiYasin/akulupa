import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models.dart';

class SettingsRepository {
  SettingsRepository(this.db);
  final AppDatabase db;
  Stream<Personality> watch() =>
      db.select(db.userSettings).watchSingle().map((row) => row.personality);
  Future<Personality> get() async =>
      (await db.select(db.userSettings).getSingle()).personality;
  Future<void> set(Personality personality) async {
    await (db.update(db.userSettings)..where((t) => t.id.equals(1))).write(
      UserSettingsCompanion(personality: Value(personality)),
    );
  }
}
