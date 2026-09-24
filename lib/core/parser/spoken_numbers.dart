/// Convert spoken numbers only in clock and glass-count positions. Names such
/// as "buku dua" and "laci satu" must retain their original wording.
class IndonesianSpokenNumbers {
  static const _digits = {
    'nol': 0,
    'satu': 1,
    'dua': 2,
    'tiga': 3,
    'empat': 4,
    'lima': 5,
    'enam': 6,
    'tujuh': 7,
    'delapan': 8,
    'sembilan': 9,
    'sepuluh': 10,
    'sebelas': 11,
  };
  static const _word =
      r'(?:nol|satu|dua|tiga|empat|lima|enam|tujuh|delapan|sembilan|sepuluh|sebelas|belas|puluh)';
  static const _number = '(?:\\d{1,2}|$_word(?:\\s+$_word){0,2})';
  int? number(String text) {
    final numeric = int.tryParse(text);
    if (numeric != null) return numeric;
    final words = text.split(' ');
    if (words.length == 1) return _digits[text];
    final first = _digits[words.first];
    if (first == null || first < 1 || first > 9) return null;
    if (words.length == 2 && words[1] == 'belas') return 10 + first;
    if (words[1] == 'puluh') {
      if (words.length == 2) return first * 10;
      final last = _digits[words[2]];
      if (last != null && last >= 1 && last <= 9) return first * 10 + last;
    }
    return null;
  }

  String normalize(String text) {
    var result = text.replaceAllMapped(
      RegExp('\\b(jam|pukul) setengah ($_number)\\b'),
      (m) {
        final hour = number(m[2]!);
        if (hour == null || hour < 1 || hour > 12) return m[0]!;
        return '${m[1]} ${hour == 1 ? 12 : hour - 1}:30';
      },
    );
    result = result.replaceAllMapped(
      RegExp(
        '\\b(jam|pukul) ($_number) (lewat|lebih|kurang) ($_number|seperempat)(?: menit)?\\b',
      ),
      (m) {
        var hour = number(m[2]!);
        final minutes = m[4] == 'seperempat' ? 15 : number(m[4]!);
        if (hour == null || hour > 23 || minutes == null || minutes > 59) {
          return m[0]!;
        }
        var minute = minutes;
        if (m[3] == 'kurang' && minute > 0) {
          hour = (hour + 23) % 24;
          minute = 60 - minute;
        }
        return '${m[1]} $hour:${minute.toString().padLeft(2, '0')}';
      },
    );
    result = result.replaceAllMapped(RegExp('\\b(jam|pukul) ($_number)\\b'), (
      m,
    ) {
      final value = number(m[2]!);
      return value == null ? m[0]! : '${m[1]} $value';
    });
    return result.replaceAllMapped(RegExp('\\b($_number) gelas\\b'), (m) {
      final value = number(m[1]!);
      return value == null ? m[0]! : '$value gelas';
    });
  }
}
