import 'package:aku_lupa/app.dart';
import 'package:aku_lupa/core/app_services.dart';
import 'package:aku_lupa/core/database/app_database.dart';
import 'package:aku_lupa/core/notifications/notification_gateway.dart';
import 'package:aku_lupa/shared/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets(
    'kalimat pengingat bebas membuka preview dan batal tidak menyimpan',
    (tester) async {
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
      final services = AppServices(db, AndroidNotificationGateway());
      await tester.runAsync(services.settings.get);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [servicesProvider.overrideWithValue(services)],
          child: const AkuLupaApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Jumat ini aku ke psikiater jam 9',
      );
      await tester.ensureVisible(find.text('Bantu aku ingat'));
      await tester.tap(find.text('Bantu aku ingat'));
      await tester.pumpAndSettle();
      expect(find.text('Periksa pengingat'), findsOneWidget);
      expect(find.text('ke psikiater'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(await tester.runAsync(services.reminders.all), isEmpty);
      await tester.ensureVisible(find.text('Batal'));
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Periksa pengingat'), findsNothing);
      expect(await tester.runAsync(services.reminders.all), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('Home → konfirmasi → simpan → cari → riwayat barang', (
    tester,
  ) async {
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
    final services = AppServices(db, AndroidNotificationGateway());
    await tester.runAsync(services.settings.get);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const AkuLupaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Apa yang mau\nkamu ingat?'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Taruh kunci motor di laci meja',
    );
    await tester.ensureVisible(find.text('Bantu aku ingat'));
    await tester.tap(find.text('Bantu aku ingat'));
    await tester.pumpAndSettle();
    expect(find.text('Ingat lokasi ini?'), findsOneWidget);
    expect(
      await tester.runAsync(() => services.items.find('kunci motor')),
      isEmpty,
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(() => services.items.find('kunci motor')))!
          .single
          .latest
          .location,
      'laci meja',
    );
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'laci');
    await tester.pumpAndSettle();
    expect(find.text('kunci motor'), findsOneWidget);
    await tester.tap(find.text('kunci motor'));
    await tester.pumpAndSettle();
    expect(find.text('1 catatan lokasi · terbaru di atas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('layar kecil dengan teks besar tidak overflow', (tester) async {
    await initializeDateFormatting('id_ID');
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(db.close);
    });
    final services = AppServices(db, AndroidNotificationGateway());
    await tester.runAsync(services.settings.get);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const AkuLupaApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
