import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/models.dart';

class ItemMemory {
  const ItemMemory(this.item, this.locations);
  final Item item;
  final List<ItemLocation> locations;
  ItemLocation get latest => locations.first;
}

class ItemRepository {
  ItemRepository(this.db);
  final AppDatabase db;

  Future<void> save(
    String name,
    String location, {
    String? photoPath,
    DateTime? at,
  }) async {
    if (name.trim().isEmpty || location.trim().isEmpty) {
      throw ArgumentError('Barang dan lokasi wajib diisi.');
    }
    final now = at ?? DateTime.now();
    await db.transaction(() async {
      final existing =
          await (db.select(db.items)
                ..where((t) => t.normalizedName.equals(normalize(name))))
              .getSingleOrNull();
      final id =
          existing?.id ??
          await db
              .into(db.items)
              .insert(
                ItemsCompanion.insert(
                  name: name.trim(),
                  normalizedName: normalize(name),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
      await db
          .into(db.itemLocations)
          .insert(
            ItemLocationsCompanion.insert(
              itemId: id,
              location: location.trim(),
              photoPath: Value(photoPath),
              createdAt: now,
            ),
          );
      await (db.update(db.items)..where((t) => t.id.equals(id))).write(
        ItemsCompanion(updatedAt: Value(now)),
      );
    });
  }

  Stream<List<ItemMemory>> watchSearch([String query = '']) {
    final joined =
        db.select(db.items).join([
          innerJoin(
            db.itemLocations,
            db.itemLocations.itemId.equalsExp(db.items.id),
          ),
        ])..orderBy([
          OrderingTerm.desc(db.itemLocations.createdAt),
          OrderingTerm.desc(db.itemLocations.id),
        ]);
    return joined.watch().map((rows) {
      final grouped = <int, ItemMemory>{};
      for (final row in rows) {
        final item = row.readTable(db.items);
        final memory = grouped.putIfAbsent(item.id, () => ItemMemory(item, []));
        memory.locations.add(row.readTable(db.itemLocations));
      }
      final term = normalize(query);
      return grouped.values
          .where(
            (m) =>
                normalize(m.item.name).contains(term) ||
                m.locations.any((l) => normalize(l.location).contains(term)),
          )
          .toList();
    });
  }

  Future<List<ItemMemory>> find(String query) => watchSearch(query).first;
}
