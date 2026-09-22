import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/parser/command_parser.dart';
import '../../core/utils/dates.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';
import '../memory/memory_page.dart';
import '../reminders/schedule_page.dart';
import 'command_confirmation.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final input = TextEditingController();
  final focus = FocusNode();
  bool busy = false;
  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || input.text.trim().isEmpty) return;
    focus.unfocus();
    setState(() => busy = true);
    try {
      final services = ref.read(servicesProvider);
      final parsed = services.parser.parse(input.text, now: DateTime.now());
      if (parsed.intent == CommandIntent.unknown) {
        showMessage(
          context,
          parsed.notes.isEmpty
              ? 'Belum paham. Coba tulis kegiatan dan waktunya, misalnya “Jumat ini aku ke dokter jam 9”, atau “Taruh kunci di laci”.'
              : parsed.notes.join('\n'),
        );
      } else if (parsed.isQuery) {
        final answer = await services.query(parsed);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.lightbulb_outline, color: ink),
            title: const Text('Aku ingat.'),
            content: SingleChildScrollView(
              child: Text(answer, style: const TextStyle(height: 1.6)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Oke, terima kasih'),
              ),
            ],
          ),
        );
      } else {
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          isDismissible: false,
          enableDrag: false,
          builder: (_) => CommandConfirmation(command: parsed),
        );
        if (result != null && mounted) {
          input.clear();
          showMessage(context, result);
        }
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Perintah belum dapat diproses. Silakan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).asData?.value ?? DateTime.now();
    final personality =
        ref.watch(personalityProvider).asData?.value ?? Personality.relaxed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, size: 17, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(fullDate(now), style: const TextStyle(color: muted)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mint,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                personality == Personality.relaxed ? '☘ Santai' : '⚡ Galak',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Text(
          'Apa yang mau\nkamu ingat?',
          style: TextStyle(
            fontSize: 37,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Taruh di sini. Biar pikiranmu lebih ringan.',
          style: TextStyle(color: muted, fontSize: 15),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ink,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              const Text(
                'SATU TEMPAT UNTUK MENGINGAT',
                style: TextStyle(
                  color: Color(0xFFB7CABB),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              Tooltip(
                message: 'Input suara hadir pada tahap berikutnya. Gunakan teks sekarang.',
                child: Semantics(
                  label: 'Input suara belum tersedia',
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3E5BC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF406052),
                        width: 7,
                      ),
                    ),
                    child: const Icon(
                      Icons.mic_none_rounded,
                      color: ink,
                      size: 33,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Voice segera hadir · tulis dulu, yuk',
                style: TextStyle(color: Color(0xFFC9D8CB), fontSize: 12),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: input,
                focusNode: focus,
                enabled: !busy,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Taruh kunci motor di laci meja',
                  filled: true,
                  fillColor: Color(0xFFFAFBF6),
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE4BA72),
                    foregroundColor: ink,
                  ),
                  onPressed: busy ? null : submit,
                  icon: Icon(
                    busy ? Icons.hourglass_empty : Icons.arrow_forward,
                    size: 18,
                  ),
                  label: Text(busy ? 'Sebentar…' : 'Bantu aku ingat'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final example in [
              ('Barang', 'Taruh kunci motor di laci meja'),
              ('Pengingat', 'Jumat ini aku ke dokter jam 9 pagi'),
              ('Rutinitas', 'Minum obat setiap hari jam 8 pagi'),
              ('Aktivitas', 'Tadi sudah olahraga'),
            ])
              ActionChip(
                label: Text(example.$1),
                onPressed: busy
                    ? null
                    : () {
                        input.text = example.$2;
                        focus.requestFocus();
                      },
              ),
          ],
        ),
        ValueListenableBuilder(
          valueListenable: ref.watch(servicesProvider).notificationWarning,
          builder: (_, warning, _) => warning == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    warning,
                    style: const TextStyle(
                      color: Color(0xFF865B18),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
        ),
        SectionTitle(
          'Hari Ini',
          action: 'Lihat jadwal',
          onTap: () => widget.onNavigate(2),
        ),
        const TodaySchedule(),
        SectionTitle(
          'Memory Terbaru',
          action: 'Semua barang',
          onTap: () => widget.onNavigate(1),
        ),
        AsyncSection(
          value: ref.watch(memoriesProvider),
          builder: (items) => items.isEmpty
              ? const EmptyCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'Tidak perlu mengingat semuanya',
                  subtitle: 'Catat tempat barangmu. Nanti cukup tanya “Kunci di mana?”',
                )
              : Column(
                  children: [
                    for (final item in items.take(4))
                      MemoryTile(memory: item, now: now),
                  ],
                ),
        ),
        const SizedBox(height: 28),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 13, color: muted),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Pribadi, tersimpan di perangkatmu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
