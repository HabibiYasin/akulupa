enum MemoryIntent { save, update, find, unclear }

class MemoryCommand {
  const MemoryCommand(
    this.intent, {
    this.item = '',
    this.location = '',
    this.notes = const [],
  });
  final MemoryIntent intent;
  final String item;
  final String location;
  final List<String> notes;
}

/// Item names are open-ended: no dictionary of allowed objects is required.
/// Specific questions/actions precede the permissive "item di location" form.
class IndonesianMemoryParser {
  static const _actor = r'(?:aku|saya|gue|gua)';
  static const _verb =
      r'(?:taruh|simpan|letakkan|letakin|menaruh|menyimpan|meletakkan|naruh|nyimpen|nyimpan)';
  static const _state =
      r'(?:ada|berada|terletak|ditaruh|disimpan|diletakkan|tersimpan|kesimpan|ketinggalan|letaknya|lokasinya)';
  static final _where = RegExp(r'\b(?:di\s*mana|di\s*manakah)\b');

  String _name(String value) {
    var name = value
        .trim()
        .replaceFirst(RegExp(r'\s+sekarang$'), '')
        .replaceFirst(RegExp(r'^(?:letak|lokasi|posisi)\s+'), '')
        .replaceFirst(RegExp(r'\s+(?:aku|saya|gue|gua|ku)$'), '')
        .replaceFirst(RegExp(r'\s+(?:itu|ini)$'), '')
        .trim();
    // Only known noun stems: blindly stripping "ku" would corrupt "buku".
    name = name.replaceFirstMapped(
      RegExp(
        r'\b(kunci|dompet|tas|hp|ponsel|buku|charger|headset|kacamata)(?:ku|nya)$',
      ),
      (match) => match[1]!,
    );
    return name;
  }

  MemoryCommand _find(String item) {
    final name = _name(item);
    return name.isEmpty
        ? const MemoryCommand(
            MemoryIntent.unclear,
            notes: ['Sebutkan barang yang ingin dicari.'],
          )
        : MemoryCommand(MemoryIntent.find, item: name);
  }

  MemoryCommand? parse(String text, {required bool isQuestion}) {
    var body = text
        // Common joined prepositions, not the passive-verb prefix "di-".
        // Normalize before question/negation guards as well as location parsing.
        .replaceAllMapped(
          RegExp(
            r'\bdi(atas|bawah|dalam|luar|depan|belakang|samping|sebelah|tengah)(nya)?\b',
          ),
          (match) => 'di ${match[1]}${match[2] ?? ''}',
        )
        .replaceFirst(RegExp(r'\s+(?:(?:ya|nih|dong|deh|sih)\s*)+$'), '')
        .trim();
    if (RegExp(
      r'^(?:tolong\s+)?(?:ingatkan|ingetin|ingatin|pengingat|buat(?:kan)? pengingat|jadwalkan|jangan lupa)\b',
    ).hasMatch(body)) {
      return null;
    }
    if (RegExp(
      r'\b(?:bukan|tidak|nggak|enggak|gak|jangan|batal|batalkan|mungkin|kayaknya|sepertinya)\b',
    ).hasMatch(body)) {
      // Let other intent parsers handle non-location commands.
      if (RegExp(r'\bdi\b|\bdimana\b').hasMatch(body)) {
        return const MemoryCommand(
          MemoryIntent.unclear,
          notes: [
            'Lokasi belum pasti atau kalimatnya menyangkal lokasi. Tulis lokasi yang benar, atau tanyakan “Kunci di mana?”.',
          ],
        );
      }
      return null;
    }
    final where = _where.firstMatch(body);
    if (where != null) {
      var item =
          '${body.substring(0, where.start)} ${body.substring(where.end)}'
              .trim();
      item = item
          .replaceFirst(
            RegExp(r'^(?:tolong\s+)?(?:(?:aku|saya|gue|gua)\s+)?lupa\s+'),
            '',
          )
          .replaceFirst(
            RegExp(r'^(?:tolong\s+)?(?:cari|carikan|cariin)\s+'),
            '',
          )
          .replaceFirst(
            RegExp('^(?:$_actor\\s+)?(?:sudah\\s+|udah\\s+)?$_verb\\s+'),
            '',
          )
          .replaceFirst(RegExp('\\s+(?:$_actor\\s+)?(?:$_verb|$_state)\$'), '')
          .trim();
      return _find(item);
    }
    final search = RegExp(
      r'^(?:tolong\s+)?(?:cari|carikan|cariin|letak|lokasi|posisi)\s+(.+)$',
    ).firstMatch(body);
    if (search != null) return _find(search[1]!);

    // A planned placement belongs to the reminder parser, not location history.
    if (RegExp(
      r'\b(?:ingatkan|ingetin|ingatin|pengingat|jadwalkan|besok|lusa|nanti|akan|mau|setiap|senin|selasa|rabu|kamis|jumat|sabtu|minggu|tanggal)\b|\b(?:jam|pukul)\s*\d|\bjangan lupa\b',
    ).hasMatch(body)) {
      return null;
    }
    if (RegExp(r'\b(?:dan|lalu|atau)\b.*\bdi\b').hasMatch(body)) {
      return const MemoryCommand(
        MemoryIntent.unclear,
        notes: [
          'Ada beberapa barang atau lokasi. Catat satu barang dan satu lokasi terlebih dahulu.',
        ],
      );
    }
    body = body
        .replaceFirst(
          RegExp(r'^(?:tolong\s+)?catat(?:\s+(?:bahwa|lokasi))?\s+'),
          '',
        )
        .replaceFirst(RegExp(r'^(?:tadi|barusan)\s+'), '');
    final loan = RegExp(r'^(.+?)\s+(?:sedang\s+)?dipinjam\s+(.+)$')
        .firstMatch(body);
    final taken = RegExp(
      r'^(.+?)\s+(?:sudah|udah|telah)\s+(diambil|dikembalikan)$',
    ).firstMatch(body);
    if (loan != null || taken != null) {
      final item = _name((loan ?? taken)![1]!);
      if (isQuestion) return _find(item);
      return MemoryCommand(
        loan != null ? MemoryIntent.save : MemoryIntent.update,
        item: item,
        location: loan != null ? 'dipinjam ${loan[2]}' : 'sudah ${taken![2]}',
      );
    }
    final prefix = RegExp(
      '^(?:$_actor\\s+)?(?:(?:sudah|udah)\\s+)?$_verb\\s+(.+?)\\s+di\\s+(.+)\$',
    );
    final suffix = RegExp(
      '^(.+?)\\s+(?:$_actor\\s+)?(?:(?:sudah|udah)\\s+)?(?:$_verb|$_state)(?:\\s+sekarang)?\\s+di\\s+(.+)\$',
    );
    final simple = RegExp(r'^(.+?)\s+di\s+(.+)$');
    final match =
        prefix.firstMatch(body) ??
        suffix.firstMatch(body) ??
        simple.firstMatch(body);
    if (match == null) return null;
    final item = _name(match[1]!);
    final location = match[2]!.trim();
    if (RegExp(
      r'^(?:aku|saya|gue|gua|dia|kami|kita|mereka|sudah|udah|ada|berada|taruh|simpan|rapat|meeting|makan|minum|olahraga|kerja|belajar|kontrol)\b',
    ).hasMatch(item)) {
      return null;
    }
    if (item.isEmpty || location.isEmpty) return null;
    // A yes/no location question returns the last saved location, never a write.
    if (isQuestion || RegExp(r'^(?:apa|apakah|benarkah)\b').hasMatch(item)) {
      return _find(
        item.replaceFirst(RegExp(r'^(?:apa|apakah|benarkah)\s+'), ''),
      );
    }
    return MemoryCommand(MemoryIntent.save, item: item, location: location);
  }
}
