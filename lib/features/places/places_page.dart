import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/dates.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

final placesProvider = StreamProvider<List<PlaceReminder>>(
  (ref) => ref.watch(servicesProvider).places.watch(),
);

class PlacesPage extends ConsumerWidget {
  const PlacesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengingat lokasi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const AddPlacePage()),
        ),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Tambah lokasi'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
        children: [
          const Text(
            'Ingatkan sekali ketika kamu memasuki area tujuan. Setelah menyimpan lokasi saat ini, keluar dari area lalu masuk kembali untuk memicu pengingat. Pengiriman bisa terlambat beberapa menit, tergantung GPS dan pengaturan baterai HP.',
            style: TextStyle(height: 1.6),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                runAction(context, services.integrations.requestLocation),
            child: const Text('1. Izinkan lokasi presisi'),
          ),
          OutlinedButton(
            onPressed: () =>
                runAction(context, services.integrations.openLocationSettings),
            child: const Text('2. Lokasi → Izinkan sepanjang waktu'),
          ),
          OutlinedButton(
            onPressed: () => runAction(context, services.requestPermissions),
            child: const Text('3. Izinkan notifikasi'),
          ),
          TextButton(
            onPressed: () => runAction(context, services.refreshIntegrations),
            child: const Text('Periksa & sinkronkan lokasi'),
          ),
          ValueListenableBuilder(
            valueListenable: services.integrationWarning,
            builder: (_, warning, _) => warning == null
                ? const SizedBox.shrink()
                : Text(warning, style: const TextStyle(color: Colors.brown)),
          ),
          const SizedBox(height: 16),
          AsyncSection(
            value: ref.watch(placesProvider),
            builder: (rows) => Column(
              children: [
                if (rows.isEmpty)
                  const EmptyCard(
                    icon: Icons.location_on_outlined,
                    title: 'Ingat saat tiba',
                    subtitle: 'Contohnya, beli sabun saat tiba di toko.',
                  ),
                for (final p in rows)
                  Card(
                    child: SwitchListTile(
                      title: Text(p.title),
                      subtitle: Text(
                        '${p.placeName} · ${p.radius} m\n${p.triggeredAt != null
                            ? 'Sudah diingatkan ${dateTimeText(p.triggeredAt!)}'
                            : p.isActive
                            ? 'Menunggu masuk area · perlu izin & GPS'
                            : 'Dijeda'}',
                      ),
                      value: p.isActive,
                      onChanged: (active) => runAction(
                        context,
                        () => services.placeService.toggle(p, active),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddPlacePage extends ConsumerStatefulWidget {
  const AddPlacePage({super.key});
  @override
  ConsumerState<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends ConsumerState<AddPlacePage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final name = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  int radius = 200;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    name.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() => busy = true);
    await runAction(context, () async {
      final platform = ref.read(servicesProvider).integrations;
      await platform.requestLocation();
      final location = await platform.currentLocation();
      latitude.text = (location['latitude'] as num).toStringAsFixed(6);
      longitude.text = (location['longitude'] as num).toStringAsFixed(6);
    });
    if (mounted) setState(() => busy = false);
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    await runAction(context, () async {
      final services = ref.read(servicesProvider);
      await services.places.create(
        title.text.trim(),
        name.text.trim(),
        double.parse(latitude.text.trim()),
        double.parse(longitude.text.trim()),
        radius,
      );
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Ingat saat tiba di mana?')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Ingatkan apa?',
                hintText: 'Beli sabun',
              ),
              validator: (v) => v!.trim().isEmpty ? 'Isi pengingatnya.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nama tempat',
                hintText: 'Toko dekat rumah',
              ),
              validator: (v) => v!.trim().isEmpty ? 'Isi nama tempat.' : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: busy ? null : locate,
              icon: const Icon(Icons.my_location),
              label: const Text('Gunakan lokasi saya sekarang'),
            ),
            const Text(
              'Pastikan kamu berada di tempat tujuan, atau isi koordinat tujuan dari aplikasi peta. Nama tempat hanya sebagai label.',
            ),
            const SizedBox(height: 16),
            for (final entry in [
              (latitude, 'Lintang', 90),
              (longitude, 'Bujur', 180),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: entry.$1,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: InputDecoration(labelText: entry.$2),
                  validator: (v) {
                    final n = double.tryParse(v!.trim());
                    return n == null || !n.isFinite || n.abs() > entry.$3
                        ? 'Isi koordinat yang valid (gunakan titik desimal).'
                        : null;
                  },
                ),
              ),
            DropdownButtonFormField<int>(
              initialValue: radius,
              decoration: const InputDecoration(labelText: 'Radius area'),
              items: [100, 200, 500, 1000, 2000]
                  .map(
                    (n) => DropdownMenuItem(value: n, child: Text('$n meter')),
                  )
                  .toList(),
              onChanged: busy ? null : (v) => setState(() => radius = v!),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lokasi disimpan dalam keadaan dijeda. Aktifkan sakelar setelah izin lokasi sepanjang waktu dan notifikasi tersedia.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Sebentar…' : 'Simpan lokasi'),
            ),
          ],
        ),
      ),
    ),
  );
}
