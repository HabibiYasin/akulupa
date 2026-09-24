import 'package:speech_to_text/speech_to_text.dart';

abstract interface class SpeechService {
  Future<void> listen({
    required void Function(String) onText,
    required void Function(bool) onListening,
    required void Function(String) onError,
  });
  Future<void> stop();
  Future<void> cancel();
}

/// One recognizer per app. A session only returns text; it never writes data.
class AndroidSpeechService implements SpeechService {
  final SpeechToText _speech = SpeechToText();
  void Function(String)? _onError;
  void Function(bool)? _onListening;
  int _generation = 0;
  @override
  Future<void> listen({
    required void Function(String) onText,
    required void Function(bool) onListening,
    required void Function(String) onError,
  }) async {
    final generation = ++_generation;
    _onError = onError;
    _onListening = onListening;
    final available = await _speech.initialize(
      options: [SpeechToText.androidNoBluetooth],
      onStatus: (status) => _onListening?.call(status == 'listening'),
      onError: (error) {
        _onListening?.call(false);
        _onError?.call(speechErrorMessage(error.errorMsg));
      },
    );
    if (generation != _generation) return;
    if (!available) {
      onError(
        'Input suara belum tersedia atau izin mikrofon ditolak. Aktifkan izin Mikrofon di pengaturan aplikasi, atau ketik perintah.',
      );
      return;
    }
    final locales = await _speech.locales().timeout(
      const Duration(seconds: 10),
    );
    if (generation != _generation) return;
    final indonesian = locales
        .where((l) => RegExp(r'^(id|in)([_-]|$)').hasMatch(l.localeId))
        .firstOrNull;
    if (indonesian == null) {
      onError(
        'Bahasa Indonesia belum tersedia pada pengenal suara HP. Tambahkan bahasa Indonesia di pengaturan suara, atau gunakan teks.',
      );
      return;
    }
    await _speech.listen(
      onResult: (result) {
        if (generation == _generation) onText(result.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        onDevice: true,
        localeId: indonesian.localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
    if (generation != _generation) await _speech.cancel();
  }

  @override
  Future<void> stop() => _speech.stop();
  @override
  Future<void> cancel() async {
    _generation++;
    _onError = null;
    _onListening = null;
    await _speech.cancel();
  }
}

String speechErrorMessage(String code) => switch (code) {
  'error_permission' || 'error_insufficient_permissions' => 'Izin mikrofon ditolak. Aktifkan izin Mikrofon di pengaturan aplikasi atau gunakan teks.',
  'error_no_match' || 'error_speech_timeout' =>
    'Suara belum terbaca. Coba bicara lebih dekat atau ketik perintah.',
  'error_language_not_supported' ||
  'error_language_unavailable' ||
  'error_network' ||
  'error_network_timeout' => 'Pengenalan suara offline bahasa Indonesia belum tersedia. Periksa paket bahasa suara di HP atau gunakan teks.',
  _ => 'Input suara terhenti. Coba lagi atau ketik perintah.',
};
