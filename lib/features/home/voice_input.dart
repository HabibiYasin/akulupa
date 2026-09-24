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
  bool finishing = false;
  bool interrupted = false;
  bool ownsSession = false;
  int generation = 0;
  Timer? silence;
  Timer? ended;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(start());
    });
  }

  Future<void> start() async {
    final session = ++generation;
    silence?.cancel();
    ended?.cancel();
    setState(() {
      starting = true;
      finishing = false;
      interrupted = false;
      text.clear();
      error = null;
    });
    try {
      await widget.speech.cancel();
      if (!mounted || session != generation) return;
      ownsSession = true;
      await widget.speech.listen(
        onText: (value) {
          if (!mounted || interrupted || session != generation) return;
          setState(() => text.text = value);
          silence?.cancel();
          if (!finishing && value.trim().isNotEmpty) {
            silence = Timer(const Duration(seconds: 2), finish);
          }
        },
        onListening: (value) {
          if (!mounted || interrupted || session != generation) return;
          setState(() => listening = value);
          if (!value && !finishing) {
            ended?.cancel();
            ended = Timer(const Duration(milliseconds: 300), () {
              if (mounted && error == null && !interrupted) unawaited(finish());
            });
          }
        },
        onError: (value) {
          if (mounted && session == generation && !interrupted) {
            // Some recognizers report no-match while stopping even though a
            // usable partial transcript was already delivered.
            if (finishing && text.text.trim().isNotEmpty) return;
            silence?.cancel();
            ended?.cancel();
            interrupted = true;
            setState(() {
              error = value;
              listening = false;
              finishing = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted && session == generation) {
        silence?.cancel();
        ended?.cancel();
        setState(() {
          interrupted = true;
          listening = false;
          finishing = false;
          error = 'Mikrofon belum bisa digunakan. Coba lagi atau gunakan teks.';
        });
      }
    } finally {
      if (mounted && session == generation) setState(() => starting = false);
    }
  }

  Future<void> finish() async {
    if (!mounted || finishing || interrupted) return;
    final session = generation;
    silence?.cancel();
    ended?.cancel();
    setState(() => finishing = true);
    try {
      await widget.speech.stop().timeout(const Duration(seconds: 3));
    } catch (_) {
      // Keep the transcript already received if stopping fails.
    }
    // Android can deliver its final transcript just after stop completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || interrupted || session != generation) return;
    final command = text.text.trim();
    if (command.isNotEmpty) {
      interrupted = true;
      ownsSession = false;
      await widget.speech.cancel().catchError((Object _) {});
      if (!mounted || session != generation) return;
      Navigator.pop(context, command);
    } else {
      setState(() {
        interrupted = true;
        finishing = false;
        listening = false;
        error = 'Suara belum terbaca. Coba bicara lagi atau ketik di Beranda.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        (listening || finishing)) {
      interrupted = true;
      generation++;
      silence?.cancel();
      ended?.cancel();
      unawaited(widget.speech.cancel().catchError((Object _) {}));
      setState(() {
        listening = false;
        finishing = false;
        error = 'Input suara dijeda. Tekan mic untuk mencoba lagi.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    interrupted = true;
    generation++;
    silence?.cancel();
    ended?.cancel();
    if (ownsSession) {
      unawaited(widget.speech.cancel().catchError((Object _) {}));
    }
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
            'Bicara dalam bahasa Indonesia. Diam 2 detik atau tekan mic untuk langsung memproses perintah.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: starting || finishing
                ? null
                : listening
                ? finish
                : start,
            icon: Icon(listening ? Icons.mic : Icons.mic_none),
            label: Text(
              finishing
                  ? 'Memproses perintah…'
                  : starting
                  ? 'Menyiapkan mikrofon…'
                  : listening
                  ? 'Selesai & proses'
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
            readOnly: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Yang terdengar'),
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
    ],
  );
}
