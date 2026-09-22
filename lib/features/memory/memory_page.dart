import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import 'item_repository.dart';

class MemoryTile extends StatelessWidget {
  const MemoryTile({super.key, required this.memory, required this.now});
  final ItemMemory memory;
  final DateTime now;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.inventory_2_outlined, color: ink),
      ),
      title: Text(
        memory.item.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
          '${memory.latest.location}\n${relativeTime(memory.latest.createdAt, now)}',
          style: const TextStyle(color: muted, height: 1.5),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: muted),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .75,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              children: [
                PageHeader(
                  memory.item.name,
                  '${memory.locations.length} catatan lokasi · terbaru di atas',
                ),
                for (var i = 0; i < memory.locations.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      i == 0 ? Icons.location_on : Icons.history,
                      color: i == 0 ? ink : muted,
                    ),
                    title: Text(memory.locations[i].location),
                    subtitle: Text(
                      '${i == 0 ? 'Lokasi terbaru · ' : ''}${dateTimeText(memory.locations[i].createdAt)}',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});
  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          'Barangmu, ketemu.',
          'Cari nama barang, lokasi, atau tempat yang pernah dipakai.',
        ),
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Cari kunci, tas, laci…',
          ),
        ),
        const SizedBox(height: 20),
        AsyncSection(
          value: ref.watch(searchProvider(query)),
          builder: (items) => items.isEmpty
              ? EmptyCard(
                  icon: Icons.search,
                  title: query.isEmpty
                      ? 'Belum ada barang yang dicatat'
                      : 'Belum ketemu',
                  subtitle: query.isEmpty
                      ? 'Ketik “Taruh kunci di laci” di Beranda untuk mulai.'
                      : 'Coba nama barang atau lokasi lainnya.',
                )
              : Column(
                  children: [
                    for (final item in items)
                      MemoryTile(memory: item, now: now),
                  ],
                ),
        ),
      ],
    );
  }
}
