import 'package:aku_lupa/core/parser/command_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = IndonesianCommandParser();
  ParsedCommand parse(String text) =>
      parser.parse(text, now: DateTime(2026, 9, 22, 11));
  final locations = <String, (String, String)>{
    'gelas diatas meja': ('gelas', 'atas meja'),
    'Gelas di atas meja': ('gelas', 'atas meja'),
    'Gelas ada diatas meja': ('gelas', 'atas meja'),
    'Taruh gelas diatas meja': ('gelas', 'atas meja'),
    'Gelas disimpan diatas meja': ('gelas', 'atas meja'),
    'Sepatu dibawah tempat tidur': ('sepatu', 'bawah tempat tidur'),
    'Kunci didalam tas': ('kunci', 'dalam tas'),
    'Payung diluar rumah': ('payung', 'luar rumah'),
    'Tas didepan lemari': ('tas', 'depan lemari'),
    'Sapu dibelakang pintu': ('sapu', 'belakang pintu'),
    'Charger disamping laptop': ('charger', 'samping laptop'),
    'Buku disebelah monitor': ('buku', 'sebelah monitor'),
    'Vas ditengah meja': ('vas', 'tengah meja'),
    'Gelas diatas meja didalam kamar': ('gelas', 'atas meja di dalam kamar'),
    'Dispenser di dapur': ('dispenser', 'dapur'),
    'Kunci rumah ada di laci': ('kunci rumah', 'laci'),
    'Kunci rumah di laci': ('kunci rumah', 'laci'),
    'Kunci rumah berada di laci meja': ('kunci rumah', 'laci meja'),
    'Kunci rumah terletak di laci': ('kunci rumah', 'laci'),
    'Kunci rumah disimpan di laci': ('kunci rumah', 'laci'),
    'Kunci rumah aku taruh di laci': ('kunci rumah', 'laci'),
    'Dompet aku simpan di tas': ('dompet', 'tas'),
    'Aku simpan dompet di tas hitam': ('dompet', 'tas hitam'),
    'Saya sudah meletakkan dompet di atas meja': ('dompet', 'atas meja'),
    'Gue naruh charger di tas hitam': ('charger', 'tas hitam'),
    'Tadi aku taruh dompet di laci': ('dompet', 'laci'),
    'Barusan simpan dompet di laci': ('dompet', 'laci'),
    'Dompet saya sekarang ada di tas': ('dompet', 'tas'),
    'Dompet saya ada di tas': ('dompet', 'tas'),
    'Dompetku ada di tas': ('dompet', 'tas'),
    'Kuncinya ada di laci': ('kunci', 'laci'),
    'Buku di rak': ('buku', 'rak'),
    'Bukuku di rak': ('buku', 'rak'),
    'Jam tangan di laci': ('jam tangan', 'laci'),
    'Catat kunci rumah ada di laci': ('kunci rumah', 'laci'),
    'Tolong catat lokasi paspor di brankas': ('paspor', 'brankas'),
    'Obeng kecil di kotak perkakas': ('obeng kecil', 'kotak perkakas'),
    'Kunci rumah ada di laci meja di kamar': (
      'kunci rumah',
      'laci meja di kamar',
    ),
    'Kunci rumah ada di laci ya': ('kunci rumah', 'laci'),
    '  KUNCI   rumah ada di laci. ': ('kunci rumah', 'laci'),
  };
  for (final entry in locations.entries) {
    test('simpan: ${entry.key}', () {
      final result = parse(entry.key);
      expect(result.intent, CommandIntent.saveItemLocation);
      expect(result.title, entry.value.$1);
      expect(result.location, entry.value.$2);
    });
  }
  final queries = <String, String>{
    'Gelas diatas meja?': 'gelas',
    'Apakah gelas diatas meja': 'gelas',
    'Kunci rumah di mana?': 'kunci rumah',
    'Kunci rumah ada dimana ya?': 'kunci rumah',
    'Di mana kunci rumah?': 'kunci rumah',
    'Dimanakah kunci rumah?': 'kunci rumah',
    'Di mana aku simpan kunci rumah?': 'kunci rumah',
    'Aku lupa taruh kunci rumah di mana': 'kunci rumah',
    'Kunci rumah aku taruh di mana?': 'kunci rumah',
    'Tolong carikan kunci rumah dong': 'kunci rumah',
    'Cariin dompet saya': 'dompet',
    'Lokasi kunci rumah?': 'kunci rumah',
    'Letak kunci rumah di mana?': 'kunci rumah',
    'Kunciku dimana?': 'kunci',
    'Kunci rumah ada di laci?': 'kunci rumah',
    'Apakah kunci rumah ada di laci': 'kunci rumah',
  };
  for (final entry in queries.entries) {
    test('cari, jangan simpan: ${entry.key}', () {
      final result = parse(entry.key);
      expect(result.intent, CommandIntent.findItem);
      expect(result.title, entry.value);
    });
  }
  for (final text in [
    'Gelas bukan diatas meja',
    'Jangan taruh gelas diatas meja',
    'Gelas mungkin diatas meja',
    'Gelas diatas meja dan kunci didalam tas',
    'Kunci bukan di laci',
    'Jangan simpan kunci di laci',
    'Kunci tidak ada di laci',
    'Kayaknya kunci ada di laci',
    'Kunci di laci dan dompet di tas',
    'Kunci di laci atau di tas',
    'Taruh kunci di',
    'Ada di laci',
    'Aku di rumah',
    'Rapat di kantor',
  ]) {
    test('tidak menebak lokasi: $text', () {
      expect(parse(text).intent, isNot(CommandIntent.saveItemLocation));
    });
  }
  test('rencana penempatan tetap menjadi reminder', () {
    for (final text in [
      'Besok taruh kunci di laci jam 9',
      'Besok taruh gelas diatas meja jam 9',
      'Ingatkan besok taruh kunci di laci jam 9',
      'Jangan lupa taruh kunci di laci besok jam 9',
    ]) {
      expect(parse(text).intent, CommandIntent.createReminder);
    }
  });
  test('kegiatan yang sudah dilakukan tetap aktivitas', () {
    expect(
      parse('Tadi sudah olahraga di taman').intent,
      CommandIntent.logActivity,
    );
  });
}
