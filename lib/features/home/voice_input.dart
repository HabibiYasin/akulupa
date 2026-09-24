import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/speech/speech_service.dart';

class VoiceInput extends StatefulWidget {
  const VoiceInput({super.key, required this.speech});
  final SpeechService speech;
  @override
  State<VoiceInput> createState() => _VoiceInputState();
}

class _VoiceInputState extends State<VoiceInput> with WidgetsBindingObserver {
  final text = TextEditingController();
  bool listening = false;
  bool starting = false;
  bool edited = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> start() async {
    setState(() {
      starting = true;
      edited = false;
      error = null;
    });
    try {
      await widget.speech.listen(
        onText: (value) {
          if (mounted && !edited) setState(() => text.text = value);
        },
        onListening: (value) {
          if (mounted) setState(() => listening = value);
        },
        onError: (value) {
          if (mounted) {
            setState(() {
              error = value;
              listening = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Mikrofon belum bisa digunakan. Coba lagi atau gunakan teks.',
        );
      }
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  Future<void> stop() async {
    try {
      await widget.speech.stop();
    } catch (_) {
      /* Text already received remains editable. */
    }
    if (mounted) setState(() => listening = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && listening) unawaited(stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.speech.cancel().catchError((Object _) {}));
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ucapkan yang mau diingat'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Gunakan kalimat pendek dalam bahasa Indonesia. Mode offline memerlukan dukungan bahasa dari HP.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: starting
                ? null
                : listening
                ? stop
                : start,
            icon: Icon(listening ? Icons.stop : Icons.mic),
            label: Text(
              starting
                  ? 'Menyiapkan mikrofon…'
                  : listening
                  ? 'Selesai bicara'
                  : 'Mulai bicara',
            ),
          ),
          if (listening)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Mendengarkan…'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: text,
            enabled: !listening && !starting,
            minLines: 2,
            maxLines: 5,
            onChanged: (_) => setState(() => edited = true),
            decoration: const InputDecoration(
              labelText: 'Hasil suara · boleh diedit',
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          const Text('Belum ada catatan yang disimpan.'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: listening || starting || text.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, text.text.trim()),
        child: const Text('Gunakan teks'),
      ),
    ],
  );
}
