import 'dart:async';
import 'dart:convert';

import 'package:aku_lupa/core/speech/speech_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_to_text.dart';

// Exercise the actual Dart plugin, mocking only the Android method channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
  const codec = StandardMethodCodec();
  late AndroidSpeechService speech;
  late List<MethodCall> calls;
  late List<bool> statuses;
  late List<String> words;
  late List<String> errors;
  Completer<void>? cancelGate;
  Future<void> emit(String method, Object value) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(MethodCall(method, value)),
          (_) {},
        );
  }

  Future<void> start() async {
    await speech.listen(
      onText: words.add,
      onListening: statuses.add,
      onError: errors.add,
    );
    await emit('notifyStatus', 'listening');
  }

  setUp(() {
    calls = [];
    statuses = [];
    words = [];
    errors = [];
    cancelGate = null;
    speech = AndroidSpeechService(recognizer: SpeechToText.withMethodChannel());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'locales') return ['id_ID:Indonesia'];
          if (call.method == 'cancel' && cancelGate != null) {
            await cancelGate!.future;
          }
          return true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('waiting for first words does not auto-stop at two seconds', () async {
    await speech.cancel();
    expect(calls.where((c) => c.method == 'cancel'), isEmpty);
    await start();
    await Future<void>.delayed(const Duration(seconds: 3));
    expect(calls.where((c) => c.method == 'stop'), isEmpty);
    expect(statuses, [true]);
    final cancel = speech.cancel();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await cancel;
  });
  test(
    'notListening waits for final words without issuing another stop',
    () async {
      await start();
      await emit('notifyStatus', 'notListening');
      expect(statuses, [true]);
      await emit(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {'recognizedWords': 'kunci di laci', 'confidence': 1.0},
          ],
          'resultType': 2,
        }),
      );
      expect(words, ['kunci di laci']);
      expect(statuses, [true, false]);
      await speech.stop();
      await speech.cancel();
      expect(calls.where((c) => c.method == 'stop'), isEmpty);
      expect(calls.where((c) => c.method == 'cancel').length, 1);
    },
  );
  test(
    'manual stop waits for delayed final result before next session',
    () async {
      await start();
      var stopped = false;
      final stop = speech.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      await emit('notifyStatus', 'notListening');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(stopped, false);
      await emit(
        'textRecognition',
        jsonEncode({
          'alternates': [
            {
              'recognizedWords': 'besok kontrol jam sembilan',
              'confidence': 1.0,
            },
          ],
          'resultType': 2,
        }),
      );
      await stop;
      expect(words.single, 'besok kontrol jam sembilan');
      await speech.cancel();
      await start();
      expect(calls.where((c) => c.method == 'listen').length, 2);
      final cancel = speech.cancel();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await cancel;
    },
  );
  test('new session waits for active native cancellation', () async {
    await start();
    cancelGate = Completer<void>();
    final cancel = speech.cancel();
    final listen = speech.listen(
      onText: words.add,
      onListening: statuses.add,
      onError: errors.add,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'listen').length, 1);
    cancelGate!.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await cancel;
    await listen;
    expect(calls.where((c) => c.method == 'listen').length, 2);
    final cleanup = speech.cancel();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await cleanup;
  });
  test(
    'native error preserves its reason and does not trigger plugin auto-cancel',
    () async {
      await start();
      await emit('notifyStatus', 'notListening');
      await emit('notifyStatus', 'doneNoResult');
      await emit(
        'notifyError',
        jsonEncode({'errorMsg': 'error_busy', 'permanent': true}),
      );
      expect(errors.single, contains('error_busy'));
      expect(calls.where((c) => c.method == 'cancel'), isEmpty);
      // Native error ends this session; simulate its terminal status too.
      await emit('notifyStatus', 'notListening');
      await speech.cancel();
    },
  );
}
