import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

class ActivityPage extends ConsumerWidget {
  const ActivityPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const PageHeader(
        'Jejak ingatan.',
        'Lokasi barang dan aktivitas yang sudah kamu catat, dalam satu alur.',
      ),
      AsyncSection(
        value: ref.watch(memoriesProvider),
        builder: (memories) => AsyncSection(
          value: ref.watch(activitiesProvider),
          builder: (activities) {
            final rows =
                <({DateTime at, String title, String detail, IconData icon})>[
                  for (final memory in memories)
                    for (final location in memory.locations)
                      (
                        at: location.createdAt,
                        title: memory.item.name,
                        detail: 'Ditaruh di ${location.location}',
                        icon: Icons.inventory_2_outlined,
                      ),
                  for (final activity in activities)
                    (
                      at: activity.eventTime,
                      title: activity.title,
                      detail: activity.description ?? 'Aktivitas dicatat',
                      icon: Icons.check_circle_outline,
                    ),
                ]..sort((a, b) => b.at.compareTo(a.at));
            if (rows.isEmpty) {
              return const EmptyCard(
                icon: Icons.history,
                title: 'Ingatanmu mulai dari sini',
                subtitle:
                    'Catat lokasi barang atau ketik “Tadi sudah olahraga”.',
              );
            }
            return Column(
              children: [
                for (final row in rows)
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: mint,
                        child: Icon(row.icon, color: ink, size: 20),
                      ),
                      title: Text(
                        row.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${row.detail}\n${dateTimeText(row.at)}',
                        style: const TextStyle(height: 1.6, color: muted),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ],
  );
}
