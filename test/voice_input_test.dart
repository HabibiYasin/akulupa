import 'package:aku_lupa/core/speech/speech_service.dart';
import 'package:aku_lupa/features/home/voice_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpeech implements SpeechService {
  bool cancelled = false;
  bool stopped = false;
  bool denied = false;
  void Function(String)? text;
  void Function(bool)? status;
  @override
  Future<void> listen({
    required void Function(String) onText,
    required void Function(bool) onListening,
    required void Function(String) onError,
  }) async {
    text = onText;
    status = onListening;
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
    stopped = true;
    status?.call(false);
  }
}

void main() {
  testWidgets(
    'transcript editable after stop and returned only after user chooses use text',
    (tester) async {
      final speech = FakeSpeech();
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => VoiceInput(speech: speech),
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
      await tester.tap(find.text('Mulai bicara'));
      await tester.pumpAndSettle();
      speech.text!('besok ke psikiater jam sembilan');
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gunakan teks'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Selesai bicara'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'besok ke psikiater jam sembilan pagi',
      );
      await tester.tap(find.text('Gunakan teks'));
      await tester.pumpAndSettle();
      expect(result, 'besok ke psikiater jam sembilan pagi');
      expect(speech.stopped, isTrue);
      expect(speech.cancelled, isTrue);
    },
  );
  testWidgets(
    'permission failure leaves text available and cancel releases speech',
    (tester) async {
      final speech = FakeSpeech()..denied = true;
      await tester.pumpWidget(MaterialApp(home: VoiceInput(speech: speech)));
      await tester.tap(find.text('Mulai bicara'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Izin mikrofon ditolak'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(speech.cancelled, isTrue);
    },
  );
}
