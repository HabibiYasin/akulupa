import 'package:aku_lupa/app.dart';
import 'package:aku_lupa/core/app_services.dart';
import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/notifications/notification_gateway.dart';
import 'package:aku_lupa/core/speech/speech_service.dart';
import 'package:aku_lupa/shared/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'voice_input_test.dart' show FakeSpeech;

Future<AppServices> setup(
  WidgetTester tester, {
  Future<void> Function(AppServices)? seed,
  SpeechService? speech,
}) async {
  await initializeDateFormatting('id_ID');
  tester.view.physicalSize = const Size(420, 940);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(db.close);
  });
  final services = AppServices(
    db,
    AndroidNotificationGateway(),
    speech: speech,
  );
  await tester.runAsync(services.settings.get);
  if (seed != null) await tester.runAsync(() => seed(services));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const AkuLupaApp(),
    ),
  );
  await tester.pumpAndSettle();
  return services;
}

Future<void> submit(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.ensureVisible(find.text('Bantu aku ingat'));
  await tester.tap(find.text('Bantu aku ingat'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('voice stop opens command preview directly and can be reused', (
    tester,
  ) async {
    final speech = FakeSpeech();
    final services = await setup(tester, speech: speech);
    for (final command in ['gelas di atas meja', 'kunci di laci']) {
      await tester.tap(find.byTooltip('Ucapkan perintah'));
      await tester.pumpAndSettle();
      speech.text!(command);
      await tester.tap(find.text('Selesai & proses'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Ingat lokasi ini?'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    }
    expect(await tester.runAsync(() => services.items.find('gelas')), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'gelas diatas meja opens populated preview without manual fallback',
    (tester) async {
      final services = await setup(tester);
      await submit(tester, 'gelas diatas meja');
      expect(find.text('Mau dicatat sebagai apa?'), findsNothing);
      expect(find.text('Ingat lokasi ini?'), findsOneWidget);
      expect(find.text('gelas'), findsOneWidget);
      expect(find.text('atas meja'), findsOneWidget);
      expect(
        await tester.runAsync(() => services.items.find('gelas')),
        isEmpty,
      );
      await tester.ensureVisible(find.text('Batal'));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('weekly preview saves Sunday and suggested time', (tester) async {
    final services = await setup(tester);
    await submit(tester, 'aku ingin olahraga tiap minggu pagi');
    expect(find.text('Rutinitas baru'), findsOneWidget);
    expect(find.text('06:30'), findsOneWidget);
    expect(find.text('Setiap Minggu'), findsWidgets);
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    final habits = (await tester.runAsync(services.habits.all))!;
    expect(habits.single.weekday, 7);
    expect(habits.single.scheduleTime, 390);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('quantitative preview persists edited target and day window', (
    tester,
  ) async {
    final services = await setup(tester);
    await submit(tester, 'minum air setiap hari minimal 10 gelas');
    final target = find.widgetWithText(TextFormField, 'Target gelas per hari');
    await tester.ensureVisible(target);
    await tester.enterText(target, '8');
    expect(find.text('Jam akhir 22:00'), findsOneWidget);
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    final habit = (await tester.runAsync(services.habits.all))!.single;
    expect(habit.targetCount, 8);
    expect(habit.scheduleTime, 360);
    expect(habit.endTime, 1320);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'ambiguous progress asks which routine and cancel changes nothing',
    (tester) async {
      final services = await setup(
        tester,
        seed: (services) async {
          await services.habits.create(
            'Minum air',
            360,
            targetCount: 10,
            unit: 'gelas',
            endMinutes: 1320,
          );
          await services.habits.create(
            'Minum air kantor',
            480,
            targetCount: 3,
            unit: 'gelas',
            endMinutes: 1020,
          );
        },
      );
      await tester.pumpAndSettle();
      await submit(tester, 'sudah minum segelas');
      expect(find.text('Catat +1 gelas?'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Konfirmasi'),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(
          () => services.db.select(services.db.habitLogs).get(),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('unknown command opens manual type selection without writing', (
    tester,
  ) async {
    final services = await setup(tester);
    await submit(tester, 'tolong bantu catat sesuatu');
    expect(find.text('Mau dicatat sebagai apa?'), findsOneWidget);
    await tester.tap(find.text('Pengingat').last);
    await tester.pumpAndSettle();
    expect(find.text('Periksa pengingat'), findsOneWidget);
    expect(find.text('Pilih tanggal'), findsOneWidget);
    expect(find.text('Pilih jam'), findsOneWidget);
    await tester.ensureVisible(find.text('Batal'));
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(services.reminders.all), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
