import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

class PlaceRepository {
  PlaceRepository(this.db);
  final AppDatabase db;
  Stream<List<PlaceReminder>> watch() => (db.select(
    db.placeReminders,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  Future<List<PlaceReminder>> all() => db.select(db.placeReminders).get();
  Future<PlaceReminder?> get(int id) => (db.select(
    db.placeReminders,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
  Future<PlaceReminder> create(
    String title,
    String name,
    double latitude,
    double longitude,
    int radius,
  ) {
    if (title.trim().isEmpty ||
        name.trim().isEmpty ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        radius < 100 ||
        radius > 2000) {
      throw ArgumentError(
        'Periksa kegiatan, nama tempat, dan radius 100–2000 meter.',
      );
    }
    return db
        .into(db.placeReminders)
        .insertReturning(
          PlaceRemindersCompanion.insert(
            title: title.trim(),
            placeName: name.trim(),
            latitude: latitude,
            longitude: longitude,
            radius: Value(radius),
            isActive: const Value(false),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> setActive(int id, bool active) =>
      (db.update(db.placeReminders)..where((t) => t.id.equals(id))).write(
        PlaceRemindersCompanion(
          isActive: Value(active),
          triggeredAt: active ? const Value(null) : const Value.absent(),
        ),
      );
  Future<void> triggered(int id, DateTime at) =>
      (db.update(
        db.placeReminders,
      )..where((t) => t.id.equals(id) & t.isActive.equals(true))).write(
        PlaceRemindersCompanion(
          isActive: const Value(false),
          triggeredAt: Value(at),
        ),
      );
}
