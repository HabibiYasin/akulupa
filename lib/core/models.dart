enum Personality { relaxed, strict }

enum EntryStatus { pending, completed, skipped }

enum RepeatPattern { daily }

String normalize(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class ResponseTemplates {
  const ResponseTemplates(this.personality);
  final Personality personality;
  String saved(String detail) => personality == Personality.strict
      ? 'Sudah dicatat. Jangan lupa lagi! $detail'
      : 'Tenang, aku ingatkan. $detail';
  String reminder(String title) => personality == Personality.strict
      ? '${title.toUpperCase()}. SEKARANG. Ayo diselesaikan!'
      : 'Hei, waktunya ${title.toLowerCase()} 👀';
  String found(String item, String location) =>
      personality == Personality.strict
      ? '$item ada di $location. Cek sana!'
      : '$item terakhir kamu taruh di $location.';
}
