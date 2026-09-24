import 'package:aku_lupa/core/parser/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = IndonesianCommandParser();
  final now = DateTime(2026, 9, 10, 10, 30);
  ParsedCommand parse(String input) => parser.parse(input, now: now);

  group('Intent bahasa Indonesia', () {
    test('menyimpan barang multi-kata dan lokasi lengkap', () {
      final result = parse('Taruh kunci motor di laci meja komputer.');
      expect(result.intent, CommandIntent.saveItemLocation);
      expect(result.title, 'kunci motor');
      expect(result.location, 'laci meja komputer');
    });
    test('case dan whitespace dinormalisasi', () {
      final result = parse('  SIMPAN   Charger  di   Tas hitam  ');
      expect(result.title, 'charger');
      expect(result.location, 'tas hitam');
    });
    for (final query in [
      'Kunci motor di mana?',
      'Di mana kunci motor?',
      'Cari kunci motor',
      'Kunci motor dimana?',
    ]) {
      test(query, () {
        final result = parse(query);
        expect(result.intent, CommandIntent.findItem);
        expect(result.title, 'kunci motor');
      });
    }
    test('tanggal, judul, jam siang diekstrak', () {
      final result = parse(
        'Ingatkan tanggal 13 September ada meeting jam 2 siang.',
      );
      expect(result.intent, CommandIntent.createReminder);
      expect(result.title, 'meeting');
      expect(result.date, DateTime(2026, 9, 13));
      expect(result.timeMinutes, 14 * 60);
    });
    test('besok dan waktu sebelum judul', () {
      final result = parse('Ingatkan besok jam 8 meeting');
      expect(result.title, 'meeting');
      expect(result.date, DateTime(2026, 9, 11));
      expect(result.timeMinutes, 480);
      expect(result.notes, isNotEmpty);
    });
    test('habit didahulukan atas reminder', () {
      final result = parse('Ingatkan minum obat setiap hari jam 7');
      expect(result.intent, CommandIntent.createHabit);
      expect(result.title, 'minum obat');
      expect(result.timeMinutes, 420);
    });
    test('setiap malam jam 9 berarti 21:00', () {
      final result = parse('Ingatkan sikat gigi setiap malam jam 9.');
      expect(result.title, 'sikat gigi');
      expect(result.timeMinutes, 1260);
    });
    test('habit tanpa kata ingatkan', () {
      final result = parse('Minum obat setiap hari jam 8 pagi.');
      expect(result.intent, CommandIntent.createHabit);
      expect(result.timeMinutes, 480);
    });
    test('aktivitas tanpa waktu memakai sekarang', () {
      final result = parse('Tadi sudah olahraga');
      expect(result.intent, CommandIntent.logActivity);
      expect(result.title, 'olahraga');
      expect(result.timeMinutes, 630);
    });
    test('aktivitas dengan jam', () {
      final result = parse('Tadi jam 1 sudah minum obat.');
      expect(result.intent, CommandIntent.logActivity);
      expect(result.title, 'minum obat');
      expect(result.timeMinutes, 60);
    });
    test('query aktivitas', () {
      final result = parse('Kapan terakhir minum obat?');
      expect(result.intent, CommandIntent.queryActivity);
      expect(result.title, 'minum obat');
    });
  });
  group('Ambiguitas dan batas waktu', () {
    test('format menit yang terpotong tidak ditebak', () {
      expect(parse('Ingatkan jam 8:7 meeting').timeMinutes, isNull);
      expect(parse('Ingatkan jam 8:300 meeting').timeMinutes, isNull);
    });
    test('tanggal lampau tanpa tahun bergulir dengan catatan', () {
      final result = parse('Ingatkan tanggal 1 Januari jam 14:30 meeting');
      expect(result.date, DateTime(2027, 1, 1));
      expect(result.notes.join(), contains('2027'));
    });
    test('tahun eksplisit tidak diganti', () {
      final result = parse('Ingatkan 1 Januari 2025 jam 14 rapat');
      expect(result.date, DateTime(2025, 1, 1));
    });
    test('tanggal tidak valid membutuhkan pemilihan manual', () {
      final result = parse('Ingatkan 31 Februari jam 8 rapat');
      expect(result.date, isNull);
      expect(result.notes.join(), contains('Tanggal tidak valid'));
    });
    test('tanggal numerik tidak ditebak', () {
      expect(parse('Ingatkan tanggal 13/10 jam 8 rapat').date, isNull);
    });
    test('jam tidak valid membutuhkan pemilihan manual', () {
      expect(parse('Ingatkan jam 25:61 rapat').timeMinutes, isNull);
    });
    test('waktu hilang tidak diisi diam-diam', () {
      expect(parse('Ingatkan besok meeting').timeMinutes, isNull);
    });
    test('12 siang dan 12 pagi', () {
      expect(parse('Ingatkan besok jam 12 siang makan').timeMinutes, 720);
      expect(parse('Ingatkan besok jam 12 pagi makan').timeMinutes, 0);
    });
    test('aktivitas masa depan dianggap kemarin dan ditandai', () {
      final result = parse('Tadi jam 11 malam sudah olahraga');
      expect(result.date, DateTime(2026, 9, 9));
      expect(result.notes.join(), contains('kemarin'));
    });
    test('pengulangan mingguan dikenali', () {
      expect(
        parse('Ingatkan rapat setiap senin jam 8').intent,
        CommandIntent.createHabit,
      );
      expect(
        parse('Ingatkan rapat setiap senin jam 8').weekday,
        DateTime.monday,
      );
    });
    for (final input in [
      '',
      'halo',
      'Taruh kunci di',
      'Ingatkan besok jam 8',
    ]) {
      test(
        'unknown: $input',
        () => expect(parse(input).intent, CommandIntent.unknown),
      );
    }
  });
  group('Kalimat pengingat sehari-hari', () {
    final tuesday = DateTime(2026, 9, 22, 11, 25);
    ParsedCommand natural(String text) => parser.parse(text, now: tuesday);

    test('regresi kalimat dari HP pengguna', () {
      final result = natural('Jumat ini aku ke psikiater jam 9');
      expect(result.intent, CommandIntent.createReminder);
      expect(result.title, 'ke psikiater');
      expect(result.date, DateTime(2026, 9, 25));
      expect(result.timeMinutes, 540);
      expect(result.notes.join(), contains('24 jam'));
    });
    for (final text in [
      'Aku ke psikiater Jumat ini jam 9',
      'Hari Jumat ini saya mau ke psikiater pukul 09.00',
      "Jum'at ini aku ke psikiater jam9 pagi",
      'Ke psikiater Jumat ini 09:00',
      'Tolong ingetin aku untuk ke psikiater Jumat ini jam 9 ya',
    ]) {
      test(text, () {
        final result = natural(text);
        expect(result.intent, CommandIntent.createReminder);
        expect(result.title, 'ke psikiater');
        expect(result.date, DateTime(2026, 9, 25));
        expect(result.timeMinutes, 540);
      });
    }
    test('besok tanpa awalan ingatkan', () {
      final result = natural('Besok aku kontrol ke dokter jam 2 siang');
      expect(result.title, 'kontrol ke dokter');
      expect(result.date, DateTime(2026, 9, 23));
      expect(result.timeMinutes, 840);
    });
    test('penanda sore sebelum jam', () {
      final result = natural('Besok sore jam 3 aku ke psikiater');
      expect(result.title, 'ke psikiater');
      expect(result.timeMinutes, 900);
    });
    test('tanggal dengan nama bulan tanpa awalan', () {
      final result = natural('Aku kontrol tanggal 2 Oktober 2026 jam 10');
      expect(result.title, 'kontrol');
      expect(result.date, DateTime(2026, 10, 2));
    });
    test('hari tanpa jam membuka preview dengan waktu kosong', () {
      final result = natural('Jumat ini aku ke psikiater');
      expect(result.intent, CommandIntent.createReminder);
      expect(result.timeMinutes, isNull);
    });
    test('rencana tanpa hari/jam meminta input manual', () {
      final result = natural('Aku mau ke psikiater');
      expect(result.intent, CommandIntent.createReminder);
      expect(result.title, 'ke psikiater');
      expect(result.date, isNull);
      expect(result.timeMinutes, isNull);
    });
    test('alias pengingat', () {
      for (final prefix in [
        'Jangan lupa',
        'Buat pengingat untuk',
        'Jadwalkan',
        'Tolong ingatkan saya',
      ]) {
        final result = natural('$prefix ke psikiater besok jam 9');
        expect(result.intent, CommandIntent.createReminder);
        expect(result.title, 'ke psikiater');
      }
    });
    test('ini berarti minggu ini, tidak diam-diam bergeser sepekan', () {
      final result = natural('Senin ini aku kontrol jam 9');
      expect(result.date, DateTime(2026, 9, 21));
      expect(result.notes.join(), contains('sudah lewat'));
    });
    test('hari tanpa ini berarti occurrence berikutnya', () {
      expect(natural('Senin aku kontrol jam 9').date, DateTime(2026, 9, 28));
    });
    test('pekan depan ditampilkan dengan catatan', () {
      final result = natural('Jumat depan aku kontrol jam 9');
      expect(result.date, DateTime(2026, 10, 2));
      expect(result.notes.join(), contains('pekan berikutnya'));
      expect(natural('Jumat minggu depan aku kontrol jam 9').date, result.date);
    });
    test('hari Minggu dibedakan dari minggu depan yang belum spesifik', () {
      expect(
        natural('Hari Minggu ini aku kontrol jam 9').date,
        DateTime(2026, 9, 27),
      );
      expect(natural('Minggu depan aku kontrol jam 9').date, isNull);
    });
    test('konflik hari dan tanggal meminta pilihan manual', () {
      expect(natural('Besok Jumat aku kontrol jam 9').date, isNull);
      expect(natural('Jumat 24 September 2026 aku kontrol jam 9').date, isNull);
      expect(
        natural('Jumat 2 Oktober 2026 aku kontrol jam 9').date,
        DateTime(2026, 10, 2),
      );
      expect(natural('Jumat atau Sabtu aku kontrol jam 9').date, isNull);
    });
    test('lintas tahun dan hari yang sama', () {
      expect(
        parser
            .parse('Jumat aku kontrol jam 9', now: DateTime(2026, 12, 31))
            .date,
        DateTime(2027, 1, 1),
      );
      expect(
        natural('Selasa ini aku kontrol jam 9').date,
        DateTime(2026, 9, 22),
      );
    });
    test('aktivitas yang sudah terjadi tidak dijadikan reminder', () {
      final result = natural('Hari ini aku sudah ke psikiater jam 9');
      expect(result.intent, CommandIntent.logActivity);
      expect(result.title, 'ke psikiater');
    });
    test('tiap hari tetap menjadi habit', () {
      final result = natural('Ingetin aku minum obat tiap hari jam 8 pagi');
      expect(result.intent, CommandIntent.createHabit);
      expect(result.title, 'minum obat');
    });
    for (final text in [
      'Apa besok aku ke psikiater jam 9?',
      'Batal ke psikiater Jumat ini jam 9',
      'Aku nggak jadi ke psikiater Jumat ini',
      'Besok jam 9',
    ]) {
      test(
        'tidak membuat reminder: $text',
        () => expect(natural(text).intent, CommandIntent.unknown),
      );
    }
  });
}
