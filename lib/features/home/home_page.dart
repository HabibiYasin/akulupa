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
import 'command_fallback.dart';
import 'command_action_confirmation.dart';
import 'voice_input.dart';
import '../../core/photos/photo_service.dart';

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
  String exampleHint = 'Taruh kunci motor di laci meja';
  PreparedPhoto? recoveredPhoto;
  String? recoveryError;
  @override
  void initState() {
    super.initState();
    recoverPhoto();
  }

  Future<void> recoverPhoto() async {
    try {
      final photo = await ref.read(servicesProvider).photos.recover();
      if (mounted && photo != null) setState(() => recoveredPhoto = photo);
    } catch (_) {
      // Missing plugin during widget tests is also harmless to text commands.
      if (mounted) {
        setState(
          () => recoveryError = 'Foto sebelumnya belum bisa dipulihkan. Kamu bisa memilih ulang saat mencatat barang.',
        );
      }
    }
  }

  Future<void> voice() async {
    focus.unfocus();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => VoiceInput(speech: ref.read(servicesProvider).speech),
    );
    if (result != null && mounted) setState(() => input.text = result);
  }

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
      var parsed = services.parser.parse(input.text, now: DateTime.now());
      if (parsed.intent == CommandIntent.unknown) {
        final selected = await chooseCommandType(context, parsed);
        if (selected == null || !mounted) return;
        parsed = selected;
      }
      if (parsed.isMutation) {
        final result = await confirmCommandAction(context, services, parsed);
        if (result != null && mounted) {
          input.clear();
          showMessage(context, result);
        }
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
    } on ArgumentError catch (e) {
      if (mounted) showMessage(context, '${e.message}');
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
        if (recoveredPhoto != null)
          Card(
            child: ListTile(
              title: const Text('Foto sebelumnya berhasil dipulihkan'),
              subtitle: const Text(
                'Lengkapi nama barang dan lokasi sebelum menyimpan.',
              ),
              trailing: IconButton(
                tooltip: 'Abaikan foto',
                onPressed: busy
                    ? null
                    : () => setState(() => recoveredPhoto = null),
                icon: const Icon(Icons.close),
              ),
              onTap: busy
                  ? null
                  : () async {
                      final result = await showModalBottomSheet<String>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        isDismissible: false,
                        enableDrag: false,
                        builder: (_) => CommandConfirmation(
                          command: const ParsedCommand(
                            intent: CommandIntent.saveItemLocation,
                            original: 'Foto yang dipulihkan',
                          ),
                          initialPhoto: recoveredPhoto,
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() => recoveredPhoto = null);
                        if (context.mounted) showMessage(context, result);
                      }
                    },
            ),
          ),
        if (recoveryError != null)
          Text(recoveryError!, style: const TextStyle(color: muted)),
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
                message: 'Ucapkan perintah',
                child: Semantics(
                  label: 'Input suara',
                  button: true,
                  child: InkWell(
                    onTap: busy ? null : voice,
                    customBorder: const CircleBorder(),
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
              ),
              const SizedBox(height: 9),
              const Text(
                'Tekan mic untuk bicara, atau tulis di bawah',
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
                decoration: InputDecoration(
                  hintText: 'Contoh: $exampleHint',
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
                        setState(() => exampleHint = example.$2);
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
