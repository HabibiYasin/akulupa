/// Resolves Indonesian weekday expressions using local calendar dates.
/// Explicit "ini" stays in the current Monday–Sunday week, even if past.
class WeekdayMatch {
  const WeekdayMatch(this.phrase, this.date, this.notes);
  final String phrase;
  final DateTime? date;
  final List<String> notes;
}

class IndonesianWeekdayParser {
  static const names = [
    'senin',
    'selasa',
    'rabu',
    'kamis',
    'jumat',
    'sabtu',
    'minggu',
  ];
  static final pattern = RegExp(
    r'\b(hari\s+)?(senin|selasa|rabu|kamis|jumat|sabtu|minggu)(?:\s+(minggu depan|pekan depan|ini|depan|besok|nanti|lalu|kemarin))?\b',
  );

  WeekdayMatch? parse(String text, DateTime now) {
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) return null;
    if (matches.length > 1) {
      return WeekdayMatch(matches.map((m) => m[0]!).join(' '), null, [
        'Ada lebih dari satu hari. Pilih satu tanggal pengingat.',
      ]);
    }
    final match = matches.single;
    final phrase = match[0]!;
    final qualifier = match[3];
    if (match[1] == null &&
        match[2] == 'minggu' &&
        ['ini', 'depan', 'lalu'].contains(qualifier)) {
      return WeekdayMatch(phrase, null, [
        '“$phrase” belum menyebut hari tertentu. Pilih tanggal.',
      ]);
    }
    final weekday = names.indexOf(match[2]!) + 1;
    final today = DateTime(now.year, now.month, now.day);
    final notes = <String>[];
    int offset;
    switch (qualifier) {
      case 'ini':
        offset = weekday - now.weekday;
      case 'depan' || 'minggu depan' || 'pekan depan':
        offset = weekday - now.weekday + 7;
        notes.add(
          '“$phrase” memakai pekan berikutnya (Senin–Minggu). Periksa tanggalnya.',
        );
      case 'lalu':
        offset = weekday - now.weekday - 7;
      case 'besok' || 'kemarin':
        offset = qualifier == 'besok' ? 1 : -1;
        if (DateTime(now.year, now.month, now.day + offset).weekday !=
            weekday) {
          return WeekdayMatch(phrase, null, [
            'Nama hari dan “$qualifier” tidak cocok. Pilih tanggal yang dimaksud.',
          ]);
        }
      default:
        offset = (weekday - now.weekday + 7) % 7;
    }
    final date = DateTime(now.year, now.month, now.day + offset);
    if (date.isBefore(today)) {
      notes.add(
        'Hari yang disebut sudah lewat. Periksa tanggal sebelum menyimpan.',
      );
    }
    return WeekdayMatch(phrase, date, notes);
  }
}
