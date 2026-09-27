import 'dart:async';

import 'package:flutter/foundation.dart';
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
  AndroidSpeechService({SpeechToText? recognizer})
    : _speech = recognizer ?? SpeechToText();
  final SpeechToText _speech;
  void Function(String)? _onError;
  void Function(bool)? _onListening;
  int _generation = 0;
  bool _sessionOpen = false;
  bool _needsCleanup = false;
  bool _heardListening = false;
  Completer<void>? _finalResult;
  void _completeSession() {
    _sessionOpen = false;
    if (_finalResult?.isCompleted == false) _finalResult!.complete();
  }

  void _status(String status) {
    if (!_sessionOpen) return;
    if (status == SpeechToText.listeningStatus) {
      _heardListening = true;
      _onListening?.call(true);
    } else if (status == SpeechToText.doneStatus && _heardListening) {
      _completeSession();
      _onListening?.call(false);
    }
    // notListening only closes the microphone. Android may still be
    // recognizing the final words; do not stop/cancel the recognizer here.
  }

  Future<void> _queue = Future.value();
  Future<void> _serial(Future<void> Function() operation) {
    final next = _queue.then((_) => operation());
    _queue = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> listen({
    required void Function(String) onText,
    required void Function(bool) onListening,
    required void Function(String) onError,
  }) {
    final generation = ++_generation;
    return _serial(() async {
      if (generation != _generation) return;
      _onError = onError;
      _onListening = onListening;
      final available = await _speech.initialize(
        options: [SpeechToText.androidNoBluetooth],
        onStatus: _status,
        onError: (error) {
          // Android can report doneNoResult before the queued error callback.
          if (_onError == null || !_needsCleanup) return;
          debugPrint('Speech recognition error: ${error.errorMsg}');
          _completeSession();
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
      _sessionOpen = true;
      _needsCleanup = true;
      _heardListening = false;
      _finalResult = Completer<void>();
      try {
        await _speech.listen(
          onResult: (result) {
            if (generation == _generation) {
              onText(result.recognizedWords);
              if (result.finalResult) {
                _completeSession();
                _onListening?.call(false);
              }
            }
          },
          listenOptions: SpeechListenOptions(
            onDevice: true,
            localeId: indonesian.localeId,
            listenFor: const Duration(seconds: 30),
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.dictation,
          ),
        );
      } catch (_) {
        _completeSession();
        rethrow;
      }
    });
  }

  @override
  Future<void> stop() => _serial(() async {
    if (!_sessionOpen) return;
    await _speech.stop();
    await _finalResult!.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    if (_sessionOpen) await _speech.cancel();
    _completeSession();
  });
  @override
  Future<void> cancel() {
    _generation++;
    _onError = null;
    _onListening = null;
    return _serial(() async {
      if (!_needsCleanup) return;
      await _speech.cancel();
      _completeSession();
      _needsCleanup = false;
      // The plugin acknowledges cancel before its Android main-thread work.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
  }
}

String speechErrorMessage(String code) => switch (code) {
  'error_permission' || 'error_insufficient_permissions' => 'Izin mikrofon ditolak. Aktifkan izin Mikrofon di pengaturan aplikasi atau gunakan teks.',
  'error_no_match' || 'error_speech_timeout' =>
    'Suara belum terbaca. Coba bicara lebih dekat atau ketik perintah.',
  'error_busy' => 'Pengenal suara HP masih sibuk (error_busy). Tunggu sebentar lalu coba lagi.',
  'error_client' => 'Sesi pengenal suara HP terputus (error_client). Coba lagi; jika berulang, tutup lalu buka kembali aplikasi.',
  'error_audio_error' => 'Mikrofon tidak dapat merekam (error_audio_error). Pastikan tidak sedang digunakan aplikasi lain.',
  'error_server' || 'error_server_disconnected' =>
    'Layanan pengenal suara HP gagal ($code). Periksa layanan suara dan paket bahasa Indonesia di HP.',
  'error_too_many_requests' => 'Pengenal suara menerima terlalu banyak permintaan. Tunggu sebentar sebelum mencoba lagi.',
  'error_language_not_supported' ||
  'error_language_unavailable' ||
  'error_network' ||
  'error_network_timeout' => 'Pengenalan suara offline bahasa Indonesia belum tersedia. Periksa paket bahasa suara di HP atau gunakan teks.',
  _ => 'Input suara terhenti ($code). Coba lagi atau ketik perintah.',
};
