import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/models.dart';
import 'package:aku_lupa/features/activity/activity_repository.dart';
import 'package:aku_lupa/features/habits/habit_repository.dart';
import 'package:aku_lupa/features/memory/item_repository.dart';
import 'package:aku_lupa/features/settings/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test('nama sama mempertahankan satu barang dan seluruh riwayat', () async {
    final repo = ItemRepository(db);
    await repo.save('Kunci Motor', 'Tas hitam', at: DateTime(2026, 9, 10, 8));
    await repo.save(
      ' kunci   motor ',
      'Laci meja',
      at: DateTime(2026, 9, 10, 9),
    );
    final items = await repo.find('KUNCI');
    expect(items, hasLength(1));
    expect(items.single.locations, hasLength(2));
    expect(items.single.latest.location, 'Laci meja');
    expect((await repo.find('tas hitam')).single.latest.location, 'Laci meja');
  });
  test('riwayat pada detik sama tetap terbaru berdasarkan ID', () async {
    final repo = ItemRepository(db);
    final time = DateTime(2026);
    await repo.save('Dompet', 'Meja', at: time);
    await repo.save('Dompet', 'Tas', at: time);
    expect((await repo.find('dompet')).single.latest.location, 'Tas');
  });
  test('LIKE wildcard diperlakukan sebagai teks pencarian literal', () async {
    final repo = ItemRepository(db);
    await repo.save('Kunci', 'Laci');
    expect(await repo.find('%'), isEmpty);
  });
  test('habit completion upsert satu baris per hari', () async {
    final repo = HabitRepository(db);
    final habit = await repo.create('Minum obat', 480);
    final today = DateTime(2026, 9, 10);
    await repo.mark(habit.id, today, EntryStatus.completed);
    await repo.mark(habit.id, today, EntryStatus.skipped);
    await repo.mark(habit.id, DateTime(2026, 9, 11), EntryStatus.completed);
    expect(await repo.watchLogs().first, hasLength(2));
    expect((await repo.logFor(habit.id, today))!.status, EntryStatus.skipped);
    expect((await repo.logFor(habit.id, today))!.completedAt, isNull);
  });
  test('query aktivitas memakai eventTime, bukan urutan insert', () async {
    final repo = ActivityRepository(db);
    await repo.create('Minum obat', DateTime(2025, 1, 2, 8));
    await repo.create('minum obat', DateTime(2025, 1, 1, 8));
    expect(
      (await repo.latest('MINUM OBAT'))!.eventTime,
      DateTime(2025, 1, 2, 8),
    );
    expect(await repo.latest('lari'), isNull);
  });
  test('personality default Santai, perubahan tersimpan', () async {
    final repo = SettingsRepository(db);
    expect(await repo.get(), Personality.relaxed);
    await repo.set(Personality.strict);
    expect(await SettingsRepository(db).get(), Personality.strict);
  });
}
