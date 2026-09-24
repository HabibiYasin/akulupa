import 'dart:async';

import 'package:aku_lupa/core/speech/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ControlledRecognizer extends SpeechToText {
  ControlledRecognizer() : super.withMethodChannel();
  final cancelGate = Completer<void>();
  int initializations = 0;
  int cancellations = 0;
  @override
  Future<void> cancel() async {
    cancellations++;
    await cancelGate.future;
  }

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    initializations++;
    return false;
  }
}

void main() {
  test('new listen waits for previous native cancellation to finish', () async {
    final recognizer = ControlledRecognizer();
    final speech = AndroidSpeechService(recognizer: recognizer);
    final cancel = speech.cancel();
    final listen = speech.listen(
      onText: (_) {},
      onListening: (_) {},
      onError: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(recognizer.cancellations, 1);
    expect(recognizer.initializations, 0);
    recognizer.cancelGate.complete();
    await cancel;
    await listen;
    expect(recognizer.initializations, 1);
  });
  test(
    'cancel invalidates a queued start before opening the recognizer',
    () async {
      final recognizer = ControlledRecognizer();
      final speech = AndroidSpeechService(recognizer: recognizer);
      final oldCancel = speech.cancel();
      final listen = speech.listen(
        onText: (_) {},
        onListening: (_) {},
        onError: (_) {},
      );
      final newCancel = speech.cancel();
      recognizer.cancelGate.complete();
      await Future.wait([oldCancel, listen, newCancel]);
      expect(recognizer.initializations, 0);
    },
  );
}
