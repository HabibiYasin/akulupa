import 'package:aku_lupa/core/parser/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = IndonesianCommandParser();
  ParsedCommand parse(String text) =>
      parser.parse(text, now: DateTime(2026, 9, 23, 10));
  for (final entry in {
    'besok ke psikiater jam sembilan pagi': 540,
    'besok rapat pukul dua puluh satu': 1260,
    'besok kontrol jam setengah sembilan pagi': 510,
    'besok rapat jam sembilan lewat lima belas pagi': 555,
    'besok rapat jam sembilan kurang seperempat pagi': 525,
    'besok rapat jam dua lewat seperempat siang': 855,
    'besok rapat jam dua belas siang': 720,
    'besok rapat jam setengah satu siang': 750,
  }.entries) {
    test(entry.key, () {
      final result = parse(entry.key);
      expect(result.intent, CommandIntent.createReminder);
      expect(result.timeMinutes, entry.value);
      expect(result.title, isNot(contains('jam')));
      expect(result.original, entry.key);
    });
  }
  test('spoken counts use existing habit and progress commands', () {
    expect(
      parse('minum air setiap hari minimal sepuluh gelas').targetCount,
      10,
    );
    expect(parse('sudah minum dua gelas').amount, 2);
    expect(parse('sudah minum satu gelas').amount, 1);
  });
  test('does not replace numbers in item names or locations', () {
    final result = parse('buku dua ada di laci satu');
    expect(result.title, 'buku dua');
    expect(result.location, 'laci satu');
  });
  test('invalid spoken hour requires manual correction', () {
    expect(parse('besok rapat jam dua puluh lima').timeMinutes, isNull);
  });
}
