import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import 'backup_page.dart';
import '../places/places_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const PageHeader(
            'Mau diingatkan\ndengan cara apa?',
            'Pilih teman pengingat yang cocok untukmu.',
          ),
          AsyncSection(
            value: ref.watch(personalityProvider),
            builder: (personality) => Column(
              children: [
                for (final mode in Personality.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: personality == mode ? mint : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => runAction(
                          context,
                          () => services.changePersonality(mode),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                mode == Personality.relaxed
                                    ? Icons.spa_outlined
                                    : Icons.local_fire_department_outlined,
                                color: ink,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      mode == Personality.relaxed
                                          ? 'Santai'
                                          : 'Galak',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      ResponseTemplates(mode)
                                          .reminder('Minum obat'),
                                      style: const TextStyle(
                                        color: muted,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (personality == mode)
                                const Icon(Icons.check_circle, color: ink),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Text(
            'Mode Galak mengulang pengingat penting pada menit 0, 5, 15, 30, dan 60. “Sudah” atau “Lewati” menghentikan semuanya. Tunda menggantinya dengan satu pengingat 10 menit lagi.',
            style: TextStyle(color: muted, height: 1.6),
          ),
          const SectionTitle('Notifikasi'),
          ValueListenableBuilder(
            valueListenable: services.notificationWarning,
            builder: (_, warning, _) => Text(
              warning ?? 'Notifikasi dan alarm presisi aktif.',
              style: const TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => runAction(context, services.requestPermissions),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Izinkan notifikasi & alarm presisi'),
          ),
          TextButton.icon(
            onPressed: () => runAction(context, services.refreshNotifications),
            icon: const Icon(Icons.sync),
            label: const Text('Sinkronkan ulang jadwal'),
          ),
          const Text(
            'Jika pengingat terlambat, periksa pengaturan baterai ponsel dan izinkan Aku Lupa berjalan di latar belakang. Buka aplikasi kembali setelah mengganti zona waktu atau menghentikan paksa aplikasi.',
            style: TextStyle(color: muted, height: 1.6),
          ),
          const SectionTitle('Tentang ingatanmu'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Cadangan & pemulihan'),
            subtitle: const Text('File lokal atau Google Drive'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const BackupPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.widgets_outlined),
            title: const Text('Tambahkan widget jadwal'),
            onTap: () => runAction(context, () async {
              await services.widget.refresh();
              await services.integrations.pinWidget();
            }),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Pengingat lokasi'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const PlacesPage()),
            ),
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Catatan dan foto disimpan di perangkat ini. Input suara meminta mode offline bahasa Indonesia; ketersediaannya mengikuti pengenal suara HP. Hasil suara selalu dapat diperiksa sebelum disimpan.\n\nCadangan manual tersedia lewat pemilih file Android, termasuk Drive bila tersedia. Pengingat bisa dibuka di aplikasi Kalender untuk disimpan ke akun pilihanmu. Menghapus data aplikasi atau mencopot aplikasi akan menghapus catatan dan foto.',
                style: TextStyle(height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Aku Lupa · 0.3.0\nSedikit lupa, tetap tenang.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, height: 1.8),
            ),
          ),
        ],
      ),
    );
  }
}
