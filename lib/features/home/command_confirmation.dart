import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_services.dart';
import '../../core/parser/command_parser.dart';
import '../../core/utils/dates.dart';
import '../../core/photos/photo_service.dart';
import '../../shared/providers.dart';
import '../../shared/widgets.dart';

class CommandConfirmation extends ConsumerStatefulWidget {
  const CommandConfirmation({
    super.key,
    required this.command,
    this.initialPhoto,
  });
  final ParsedCommand command;
  final PreparedPhoto? initialPhoto;
  @override
  ConsumerState<CommandConfirmation> createState() =>
      _CommandConfirmationState();
}

class _CommandConfirmationState extends ConsumerState<CommandConfirmation> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title = TextEditingController(
    text: widget.command.title,
  );
  late final TextEditingController location = TextEditingController(
    text: widget.command.location,
  );
  late DateTime? date = widget.command.date;
  late int? weekday = widget.command.weekday;
  late final target = TextEditingController(
    text: '${widget.command.targetCount}',
  );
  late int endMinutes = widget.command.endMinutes ?? 1320;
  bool get isCounted => isHabit && widget.command.targetCount > 1;
  late TimeOfDay? time = widget.command.timeMinutes == null
      ? null
      : TimeOfDay(
          hour: widget.command.timeMinutes! ~/ 60,
          minute: widget.command.timeMinutes! % 60,
        );
  bool important = false;
  bool saving = false;
  bool picking = false;
  late PreparedPhoto? photo = widget.initialPhoto;
  Future<void> pickPhoto(PhotoSource source) async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final selected = await ref.read(servicesProvider).photos.pick(source);
      if (selected != null && mounted) setState(() => photo = selected);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException ? e.message : 'Foto belum bisa dibuka. Periksa izin kamera atau pilih foto lain dari galeri.',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  String? error;
  bool get isLocation =>
      widget.command.intent == CommandIntent.saveItemLocation;
  bool get isHabit => widget.command.intent == CommandIntent.createHabit;
  bool get isReminder => widget.command.intent == CommandIntent.createReminder;
  @override
  void dispose() {
    title.dispose();
    location.dispose();
    target.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (picking || saving) return;
    if (!formKey.currentState!.validate()) return;
    DateTime? at;
    if (!isLocation) {
      if (time == null || (!isHabit && date == null)) {
        setState(() => error = 'Pilih tanggal dan waktu terlebih dahulu.');
        return;
      }
      final day = date ?? DateTime.now();
      at = DateTime(day.year, day.month, day.day, time!.hour, time!.minute);
      if (isCounted && endMinutes <= time!.hour * 60 + time!.minute) {
        setState(() => error = 'Jam akhir harus sesudah jam mulai.');
        return;
      }
      if (isReminder && !at.isAfter(DateTime.now())) {
        setState(
          () => error = 'Waktu pengingat sudah lewat. Pilih waktu berikutnya.',
        );
        return;
      }
      if (widget.command.intent == CommandIntent.logActivity &&
          at.isAfter(DateTime.now())) {
        setState(
          () => error = 'Aktivitas harus sudah terjadi. Periksa waktunya.',
        );
        return;
      }
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final result = await ref
          .read(servicesProvider)
          .save(
            CommandDraft(
              intent: widget.command.intent,
              title: title.text.trim(),
              location: location.text.trim(),
              at: at,
              minutes: time == null ? null : time!.hour * 60 + time!.minute,
              important: important,
              weekday: weekday,
              targetCount: isCounted ? int.parse(target.text) : 1,
              unit: isCounted ? widget.command.unit : null,
              endMinutes: isCounted ? endMinutes : null,
              photo: photo,
            ),
          );
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Belum berhasil disimpan. Coba lagi; periksa isian Anda.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && !picking,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: SizedBox(width: 36, child: Divider(thickness: 4)),
              ),
              const SizedBox(height: 16),
              Text(
                isLocation
                    ? 'Ingat lokasi ini?'
                    : isHabit
                    ? 'Rutinitas baru'
                    : isReminder
                    ? 'Periksa pengingat'
                    : 'Catat aktivitas',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '“${widget.command.original}”',
                style: const TextStyle(color: muted, height: 1.5),
              ),
              if (widget.command.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.command.notes.join('\n'),
                    style: const TextStyle(
                      color: Color(0xFF865B18),
                      height: 1.5,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              TextFormField(
                controller: title,
                enabled: !saving,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: isLocation ? 'Nama barang' : 'Nama kegiatan',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              if (isLocation)
                TextFormField(
                  controller: location,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'Lokasi barang'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Lokasi wajib diisi'
                      : null,
                ),
              if (isLocation) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving || picking
                          ? null
                          : () => pickPhoto(PhotoSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Kamera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving || picking
                          ? null
                          : () => pickPhoto(PhotoSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeri'),
                    ),
                  ],
                ),
                if (picking)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                if (photo != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      photo!.bytes,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'Pratinjau foto tidak tersedia. Pilih ulang foto.',
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Foto ${photo!.kilobytes} KB · siap disimpan',
                        ),
                      ),
                      TextButton(
                        onPressed: saving || picking
                            ? null
                            : () => setState(() => photo = null),
                        child: const Text('Hapus foto'),
                      ),
                    ],
                  ),
                ],
              ],
              if (!isLocation)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!isHabit)
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: date ?? now,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2200),
                                );
                                if (selected != null && mounted) {
                                  setState(() => date = selected);
                                }
                              },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text(
                          date == null ? 'Pilih tanggal' : fullDate(date!),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: time ?? TimeOfDay.now(),
                                builder: (context, child) => MediaQuery(
                                  data: MediaQuery.of(context)
                                      .copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                ),
                              );
                              if (selected != null && mounted) {
                                setState(() => time = selected);
                              }
                            },
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(
                        time == null
                            ? 'Pilih jam'
                            : minutesText(time!.hour * 60 + time!.minute),
                      ),
                    ),
                  ],
                ),
              if (isHabit) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: weekday ?? 0,
                  decoration: const InputDecoration(labelText: 'Ulangi'),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Setiap hari'),
                    ),
                    for (var i = 0; i < 7; i++)
                      DropdownMenuItem(
                        value: i + 1,
                        child: Text(
                          'Setiap ${const ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][i]}',
                        ),
                      ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) =>
                            setState(() => weekday = value == 0 ? null : value),
                ),
                if (isCounted) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: target,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target ${widget.command.unit} per hari',
                    ),
                    validator: (value) {
                      final count = int.tryParse(value ?? '');
                      return count == null || count < 2 || count > 24
                          ? 'Isi target 2–24'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Jam di atas adalah awal pengingat. Pengingat dibagi rata hingga jam akhir dan berhenti hari ini setelah target selesai.',
                    style: TextStyle(color: muted),
                  ),
                  OutlinedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final value = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: endMinutes ~/ 60,
                                minute: endMinutes % 60,
                              ),
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child!,
                              ),
                            );
                            if (value != null && mounted) {
                              setState(
                                () =>
                                    endMinutes = value.hour * 60 + value.minute,
                              );
                            }
                          },
                    child: Text('Jam akhir ${minutesText(endMinutes)}'),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Mulai pada jadwal berikutnya.',
                    style: TextStyle(color: muted),
                  ),
                ),
              ],
              if (isReminder)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pengingat penting'),
                  subtitle: const Text(
                    'Mode Galak: maksimal 5 kali sampai diselesaikan.',
                  ),
                  value: important,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => important = v),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving || picking
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: saving || picking ? null : save,
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 20),
                      label: Text(saving ? 'Menyimpan…' : 'Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
