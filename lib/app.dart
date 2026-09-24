import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/activity/activity_page.dart';
import 'features/home/home_page.dart';
import 'features/memory/memory_page.dart';
import 'features/reminders/schedule_page.dart';
import 'features/settings/settings_page.dart';
import 'shared/providers.dart';
import 'shared/widgets.dart';
import 'core/platform/android_integrations.dart';

class AkuLupaApp extends StatelessWidget {
  const AkuLupaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Aku Lupa',
    debugShowCheckedModeBanner: false,
    locale: const Locale('id', 'ID'),
    supportedLocales: const [Locale('id', 'ID')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        surface: paper,
      ),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E0D5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD9E0D5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: mint,
      ),
    ),
    home: const AppShell(),
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AndroidIntegrations.channel.setMethodCallHandler((call) async {
      if (call.method == 'documentRecovered') await recoverDocument();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => recoverDocument());
  }

  Future<void> recoverDocument() async {
    try {
      final message = await ref
          .read(servicesProvider)
          .integrations
          .recoverDocument();
      if (mounted && message != null) showMessage(context, message);
    } catch (_) {
      /* Native integrations are unavailable in host widget tests. */
    }
  }

  @override
  void dispose() {
    AndroidIntegrations.channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(servicesProvider).refreshNotifications();
      ref.read(servicesProvider).refreshIntegrations();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.bubble_chart_outlined, size: 28),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Aku Lupa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Pengaturan',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
          ),
          icon: const Icon(Icons.tune),
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: IndexedStack(
            index: index,
            children: [
              HomePage(onNavigate: (value) => setState(() => index = value)),
              const MemoryPage(),
              const SchedulePage(),
              const ActivityPage(),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Barang',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Jadwal',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'Jejak'),
      ],
    ),
  );
}
