import 'package:aku_lupa/core/speech/speech_service.dart';
import 'package:aku_lupa/features/home/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeech implements SpeechService {
  bool cancelled = false;
  int stops = 0;
  bool denied = false;
  String? finalText;
  bool errorOnStop = false;
  void Function(String)? text;
  void Function(bool)? status;
  void Function(String)? error;
  @override
  Future<void> listen({
    required void Function(String) onText,
    required void Function(bool) onListening,
    required void Function(String) onError,
  }) async {
    text = onText;
    status = onListening;
    error = onError;
    if (denied) {
      onError(speechErrorMessage('error_permission'));
    } else {
      onListening(true);
    }
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    status?.call(false);
    if (errorOnStop) error?.call('Suara belum terbaca. Coba lagi.');
    if (finalText != null) text?.call(finalText!);
  }
}

Future<void> openVoice(
  WidgetTester tester,
  FakeSpeech speech,
  void Function(String?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              onResult(
                await showDialog<String>(
                  context: context,
                  builder: (_) => VoiceInput(speech: speech),
                ),
              );
            },
            child: const Text('Mic'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mic'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('stop error with no transcript allows retry immediately', (
    tester,
  ) async {
    final speech = FakeSpeech()..errorOnStop = true;
    String? result;
    await openVoice(tester, speech, (value) => result = value);
    await tester.tap(find.text('Selesai & proses'));
    await tester.pump();
    expect(find.text('Memproses perintah…'), findsNothing);
    speech.errorOnStop = false;
    await tester.tap(find.text('Mulai bicara'));
    await tester.pump();
    speech.text!('gelas di atas meja');
    // The previous stop completion must not submit this new session.
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, isNull);
    await tester.tap(find.text('Selesai & proses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(result, 'gelas di atas meja');
  });
  testWidgets('mic can be reopened after successfully using a command', (
    tester,
  ) async {
    final speech = FakeSpeech();
    final results = <String?>[];
    await openVoice(tester, speech, results.add);
    speech.text!('kunci di laci');
    await tester.tap(find.text('Selesai & proses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mic'));
    await tester.pumpAndSettle();
    speech.text!('dompet di tas');
    await tester.tap(find.text('Selesai & proses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(results, ['kunci di laci', 'dompet di tas']);
  });
  testWidgets(
    'starts immediately and submits after two seconds without new speech',
    (tester) async {
      final speech = FakeSpeech();
      String? result;
      await openVoice(tester, speech, (value) => result = value);
      expect(find.text('Mendengarkan…'), findsOneWidget);
      expect(find.text('Gunakan teks'), findsNothing);
      speech.text!('besok ke psikiater jam sembilan');
      await tester.pump(const Duration(milliseconds: 1900));
      expect(speech.stops, 0);
      expect(result, isNull);
      await tester.pump(const Duration(milliseconds: 100));
      expect(speech.stops, 1);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(result, 'besok ke psikiater jam sembilan');
      expect(speech.cancelled, isTrue);
    },
  );
  testWidgets('new speech resets the silence deadline', (tester) async {
    final speech = FakeSpeech();
    String? result;
    await openVoice(tester, speech, (value) => result = value);
    speech.text!('kunci');
    await tester.pump(const Duration(milliseconds: 1500));
    speech.text!('kunci di laci');
    await tester.pump(const Duration(milliseconds: 1500));
    expect(speech.stops, 0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(result, 'kunci di laci');
  });
  testWidgets('manual mic stop uses final transcript and submits only once', (
    tester,
  ) async {
    final speech = FakeSpeech()..finalText = 'kunci di laci';
    final results = <String?>[];
    await openVoice(tester, speech, results.add);
    speech.text!('kunci');
    await tester.tap(find.text('Selesai & proses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(results, ['kunci di laci']);
    expect(speech.stops, 1);
  });
  testWidgets('recognizer ending automatically processes final text', (
    tester,
  ) async {
    final speech = FakeSpeech();
    String? result;
    await openVoice(tester, speech, (value) => result = value);
    speech.status!(false);
    speech.text!('gelas di atas meja');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(result, 'gelas di atas meja');
  });
  testWidgets('empty recording stays open and offers retry', (tester) async {
    final speech = FakeSpeech();
    final results = <String?>[];
    await openVoice(tester, speech, results.add);
    await tester.tap(find.text('Selesai & proses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.textContaining('Suara belum terbaca'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'permission failure does not submit and cancellation releases speech',
    (tester) async {
      final speech = FakeSpeech()..denied = true;
      String? result;
      await openVoice(tester, speech, (value) => result = value);
      expect(find.textContaining('Izin mikrofon ditolak'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(speech.cancelled, isTrue);
    },
  );
  testWidgets('cancel prevents a pending silence timer from submitting', (
    tester,
  ) async {
    final speech = FakeSpeech();
    final results = <String?>[];
    await openVoice(tester, speech, results.add);
    speech.text!('kunci di laci');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(results, [null]);
    expect(speech.stops, 0);
  });
  testWidgets(
    'recognizer error after partial text cancels automatic processing',
    (tester) async {
      final speech = FakeSpeech();
      final results = <String?>[];
      await openVoice(tester, speech, results.add);
      speech.text!('kunci');
      speech.status!(false);
      speech.error!('Input suara terhenti. Coba lagi.');
      await tester.pump(const Duration(seconds: 3));
      expect(results, isEmpty);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    },
  );
}
