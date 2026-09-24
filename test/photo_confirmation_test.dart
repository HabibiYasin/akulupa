import 'dart:convert';

import 'package:aku_lupa/core/app_services.dart';
import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/notifications/notification_gateway.dart';
import 'package:aku_lupa/core/parser/command_parser.dart';
import 'package:aku_lupa/core/photos/photo_service.dart';
import 'package:aku_lupa/features/home/command_confirmation.dart';
import 'package:aku_lupa/shared/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePhotos implements PhotoService {
  int writes = 0;
  final photo = PreparedPhoto(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
  @override
  Future<PreparedPhoto?> pick(PhotoSource source) async => photo;
  @override
  Future<PreparedPhoto?> recover() async => null;
  @override
  Future<String> store(PreparedPhoto photo) async {
    writes++;
    return '/test/photos/saved.jpg';
  }

  @override
  Future<void> discard(String path) async {}
}

void main() {
  for (final save in [false, true]) {
    testWidgets(
      'photo preview ${save ? 'save attaches to location' : 'cancel writes nothing'}',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final photos = FakePhotos();
        final services = AppServices(
          db,
          AndroidNotificationGateway(),
          photos: photos,
        );
        await tester.runAsync(services.settings.get);
        addTearDown(() async {
          await tester.runAsync(db.close);
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [servicesProvider.overrideWithValue(services)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CommandConfirmation(
                        command: ParsedCommand(
                          intent: CommandIntent.saveItemLocation,
                          original: 'Kunci ada di laci',
                          title: 'Kunci',
                          location: 'Laci',
                        ),
                      ),
                    ),
                    child: const Text('Buka'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Buka'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Galeri'));
        await tester.pumpAndSettle();
        expect(find.text('Hapus foto'), findsOneWidget);
        expect(photos.writes, 0);
        final action = find.text(save ? 'Simpan' : 'Batal');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        final memories = (await tester.runAsync(
          () => services.items.find('Kunci'),
        ))!;
        if (save) {
          expect(memories.single.latest.photoPath, '/test/photos/saved.jpg');
          expect(photos.writes, 1);
        } else {
          expect(memories, isEmpty);
          expect(photos.writes, 0);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
