import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/app_services.dart';
import 'core/database/app_database.dart';
import 'core/notifications/notification_gateway.dart';
import 'shared/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final services = AppServices(AppDatabase(), AndroidNotificationGateway());
  try {
    await services.initialize();
    runApp(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const AkuLupaApp(),
      ),
    );
  } catch (e) {
    debugPrint('Database startup: $e');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Catatan belum dapat dibuka. Tutup lalu buka kembali aplikasi. Data Anda tidak dihapus.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
