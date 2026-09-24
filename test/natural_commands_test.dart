import 'package:aku_lupa/core/parser/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = IndonesianCommandParser();
  ParsedCommand parse(String value) =>
      parser.parse(value, now: DateTime(2026, 9, 22, 11));
  test('pengen makan mie ayam hari minggu', () {
    final result = parse('pengen makan mie ayam hari minggu');
    expect(result.intent, CommandIntent.createReminder);
    expect(result.title, 'makan mie ayam');
    expect(result.date, DateTime(2026, 9, 27));
    expect(result.timeMinutes, isNull);
  });
  test('aku ingin olahraga tiap minggu pagi', () {
    final result = parse('aku ingin olahraga tiap minggu pagi');
    expect(result.intent, CommandIntent.createHabit);
    expect(result.title, 'olahraga');
    expect(result.weekday, DateTime.sunday);
    expect(result.timeMinutes, 390);
    expect(result.notes.join(), contains('usulan'));
  });
  test('charger laptop dipinjam budi', () {
    final result = parse('charger laptop dipinjam budi');
    expect(result.intent, CommandIntent.saveItemLocation);
    expect(result.title, 'charger laptop');
    expect(result.location, 'dipinjam budi');
  });
  test('minum obat tidur tiap malam', () {
    final result = parse('minum obat tidur tiap malam');
    expect(result.intent, CommandIntent.createHabit);
    expect(result.title, 'minum obat tidur');
    expect(result.weekday, isNull);
    expect(result.timeMinutes, 1110);
  });
  test('deadline tugas sabtu sore', () {
    final result = parse('deadline tugas sabtu sore');
    expect(result.intent, CommandIntent.createReminder);
    expect(result.title, 'deadline tugas');
    expect(result.date, DateTime(2026, 9, 26));
    expect(result.timeMinutes, 930);
  });
  test('jangan bangunkan aku besok pagi cancels the whole day', () {
    final result = parse('jangan bangunkan aku besok pagi');
    expect(result.intent, CommandIntent.cancelReminder);
    expect(result.title, 'bangun');
    expect(result.date, DateTime(2026, 9, 23));
    expect(result.timeMinutes, isNull);
  });
  test('ga jadi makan mie ayam', () {
    final result = parse('ga jadi makan mie ayam');
    expect(result.intent, CommandIntent.cancelReminder);
    expect(result.title, 'makan mie ayam');
    expect(result.date, isNull);
  });
  test('minggu pagi ini skip olahraga dulu', () {
    final result = parse('minggu pagi ini skip olahraga dulu');
    expect(result.intent, CommandIntent.skipHabit);
    expect(result.title, 'olahraga');
    expect(result.date, DateTime(2026, 9, 27));
  });
  test('charger laptop udah diambil', () {
    final result = parse('charger laptop udah diambil');
    expect(result.intent, CommandIntent.updateItemLocation);
    expect(result.title, 'charger laptop');
    expect(result.location, 'sudah diambil');
  });
  test('minum air setiap hari minimal 10 gelas', () {
    final result = parse('minum air setiap hari minimal 10 gelas');
    expect(result.intent, CommandIntent.createHabit);
    expect(result.title, 'minum air');
    expect(result.targetCount, 10);
    expect(result.unit, 'gelas');
    expect(result.timeMinutes, 360);
    expect(result.endMinutes, 1320);
  });
  test('sudah minum segelas', () {
    final result = parse('sudah minum segelas');
    expect(result.intent, CommandIntent.incrementHabit);
    expect(result.title, 'minum');
    expect(result.amount, 1);
    expect(result.unit, 'gelas');
  });
  test('jumlah progress eksplisit dan variasi kata', () {
    expect(parse('aku udah minum air 2 gelas').amount, 2);
    expect(parse('saya sudah minum satu gelas').amount, 1);
    expect(parse('kunci rumah berada di atas meja').location, 'atas meja');
    expect(
      parse('charger laptop sudah dikembalikan').location,
      'sudah dikembalikan',
    );
  });
}
