import 'dart:io';
import 'dart:typed_data';

import 'package:aku_lupa/core/app_services.dart';
import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/notifications/notification_gateway.dart';
import 'package:aku_lupa/core/parser/command_parser.dart';
import 'package:aku_lupa/core/photos/photo_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () async => directory = await Directory.systemTemp.createTemp(
      'aku_lupa_photo_test_',
    ),
  );
  tearDown(() async => directory.delete(recursive: true));
  test(
    'compression reduces quality until under limit without persisting preview',
    () async {
      final attempts = <int>[];
      final service = LocalPhotoService(
        directory: () async => directory,
        encoder: (_, size, quality) async {
          attempts.add(quality);
          return Uint8List(quality > 60 ? 600 * 1024 : 200 * 1024);
        },
      );
      final photo = await service.prepare('source.jpg');
      expect(attempts, [82, 72, 60]);
      expect(photo.kilobytes, 200);
      expect(await directory.list().toList(), isEmpty);
      final path = await service.store(photo);
      expect(await File(path).length(), 200 * 1024);
      await service.discard(path);
      expect(await File(path).exists(), isFalse);
    },
  );
  test(
    'unsupported or oversized image fails instead of saving original',
    () async {
      final service = LocalPhotoService(
        directory: () async => directory,
        encoder: (_, _, _) async => Uint8List(600 * 1024),
      );
      await expectLater(service.prepare('bad.jpg'), throwsFormatException);
      expect(await directory.list().toList(), isEmpty);
    },
  );
  test('saving attaches permanent photo to correct location, preserving earlier photo history', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = LocalPhotoService(directory: () async => directory);
    final app = AppServices(db, AndroidNotificationGateway(), photos: service);
    final photo = PreparedPhoto(Uint8List.fromList([1, 2, 3]));
    await app.save(
      CommandDraft(
        intent: CommandIntent.saveItemLocation,
        title: 'Kunci',
        location: 'Laci',
        photo: photo,
      ),
    );
    await app.save(
      const CommandDraft(
        intent: CommandIntent.saveItemLocation,
        title: 'Kunci',
        location: 'Tas',
      ),
    );
    final memory = (await app.items.find('Kunci')).single;
    expect(memory.locations.length, 2);
    expect(memory.latest.photoPath, isNull);
    final path = memory.locations.last.photoPath!;
    expect(await File(path).readAsBytes(), photo.bytes);
  });
  test('failed DB write removes newly stored photo', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final app = AppServices(
      db,
      AndroidNotificationGateway(),
      photos: LocalPhotoService(directory: () async => directory),
    );
    await expectLater(
      app.save(
        CommandDraft(
          intent: CommandIntent.saveItemLocation,
          title: '',
          location: 'Laci',
          photo: PreparedPhoto(Uint8List(10)),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      await Directory('${directory.path}/photos').list().toList(),
      isEmpty,
    );
  });
  test('cleanup rejects paths outside managed photo directory', () async {
    final original = File('${directory.path}/original.jpg');
    await original.writeAsString('original');
    final service = LocalPhotoService(directory: () async => directory);
    await expectLater(service.discard(original.path), throwsArgumentError);
    expect(await original.exists(), isTrue);
  });
}
