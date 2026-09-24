import '../models.dart';
import 'memory_parser.dart';
import 'weekday_parser.dart';
import 'spoken_numbers.dart';

enum CommandIntent {
  saveItemLocation,
  findItem,
  createReminder,
  createHabit,
  logActivity,
  queryActivity,
  cancelReminder,
  skipHabit,
  incrementHabit,
  updateItemLocation,
  unknown,
}

class ParsedCommand {
  const ParsedCommand({
    required this.intent,
    required this.original,
    this.title = '',
    this.location = '',
    this.date,
    this.timeMinutes,
    this.notes = const [],
    this.weekday,
    this.targetCount = 1,
    this.unit,
    this.endMinutes,
    this.amount = 1,
  });
  final CommandIntent intent;
  final String original;
  final String title;
  final String location;
  final DateTime? date;
  final int? timeMinutes;
  final List<String> notes;
  final int? weekday;
  final int targetCount;
  final String? unit;
  final int? endMinutes;
  final int amount;
  bool get isMutation => [
    CommandIntent.cancelReminder,
    CommandIntent.skipHabit,
    CommandIntent.incrementHabit,
    CommandIntent.updateItemLocation,
  ].contains(intent);
  bool get isQuery =>
      intent == CommandIntent.findItem || intent == CommandIntent.queryActivity;
}

abstract interface class CommandParser {
  ParsedCommand parse(String input, {required DateTime now});
}

class IndonesianCommandParser implements CommandParser {
  static const months = [
    'januari',
    'februari',
    'maret',
    'april',
    'mei',
    'juni',
    'juli',
    'agustus',
    'september',
    'oktober',
    'november',
    'desember',
  ];
  static final timePattern = RegExp(
    r'\b(?:(?:jam|pukul)\s*(\d{1,2})(?:[:.](\d{2}))?|(\d{1,2})[:.](\d{2}))(?![:.\d])(?:\s*(pagi|siang|sore|malam))?\b',
  );
  static final reminderPrefix = RegExp(
    r'^(?:tolong\s+)?(?:ingatkan|ingetin|ingatin|pengingat|buat(?:kan)? pengingat|jadwalkan|jangan lupa)\b(?:\s+(?:aku|saya))?(?:\s+untuk)?\s*',
  );
  static final datePattern = RegExp(
    r'\b(?:tanggal\s+)?(\d{1,2})\s+(' +
        months.join('|') +
        r')(?:\s+(\d{4}))?\b',
  );

  @override
  ParsedCommand parse(String input, {required DateTime now}) {
    final text = IndonesianSpokenNumbers().normalize(
      normalize(input)
          .replaceAll(RegExp(r"jum['’]at"), 'jumat')
          .replaceAll(RegExp(r'\btiap\b'), 'setiap')
          .replaceAll(RegExp(r'[?!,;]+'), '')
          .replaceFirst(RegExp(r'\.$'), ''),
    );
    ParsedCommand result(
      CommandIntent intent, {
      String title = '',
      String location = '',
      DateTime? date,
      int? time,
      List<String> notes = const [],
    }) => ParsedCommand(
      intent: intent,
      original: input,
      title: title,
      location: location,
      date: date,
      timeMinutes: time,
      notes: notes,
    );
    if (text.isEmpty) return result(CommandIntent.unknown);
    // Mutation commands are parsed before negation guards. They only identify
    // candidates; the application requires a separate confirmation to apply.
    final skip = RegExp(r'\b(?:skip|lewati)\s+(.+)$').firstMatch(text);
    if (skip != null) {
      final dayText = text
          .replaceAll(
            RegExp(r'\bminggu\s+(?:pagi|siang|sore|malam)\s+ini\b'),
            'hari minggu',
          )
          .replaceAll(RegExp(r'\b(pagi|siang|sore|malam)\b'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final named = IndonesianWeekdayParser().parse(dayText, now);
      final date = named != null
          ? named.date
          : DateTime(
              now.year,
              now.month,
              now.day + (text.contains('besok') ? 1 : 0),
            );
      final title = skip[1]!
          .replaceAll(IndonesianWeekdayParser.pattern, '')
          .replaceAll(
            RegExp(r'\b(?:hari ini|besok|dulu|pagi|siang|sore|malam)\b'),
            '',
          )
          .trim();
      return ParsedCommand(
        intent: CommandIntent.skipHabit,
        original: input,
        title: title,
        date: date,
        notes: named?.notes ?? const [],
      );
    }
    final cancel = RegExp(
      r'^(?:ga|gak|nggak|tidak) jadi\s+(.+)$|^(?:batalkan|hapus)\s+(?:pengingat\s+)?(.+)$|^jangan\s+(bangunkan)\s+(?:aku|saya)\s*(.*)$',
    ).firstMatch(text);
    if (cancel != null) {
      var title = cancel[1] ?? cancel[2] ?? 'bangun';
      title = title
          .replaceAll(
            RegExp(r'\b(?:hari ini|besok|pagi|siang|sore|malam)\b'),
            '',
          )
          .trim();
      final date = RegExp(r'\b(?:besok|hari ini)\b').hasMatch(text)
          ? DateTime(
              now.year,
              now.month,
              now.day + (text.contains('besok') ? 1 : 0),
            )
          : null;
      return ParsedCommand(
        intent: CommandIntent.cancelReminder,
        original: input,
        title: title,
        date: date,
      );
    }
    final progress = RegExp(
      r'^(?:aku\s+|saya\s+)?(?:sudah|udah)\s+(?:minum(?: air)?\s+)(segelas|satu gelas|\d+ gelas)$',
    ).firstMatch(text);
    if (progress != null) {
      final amount = int.tryParse(progress[1]!.split(' ').first) ?? 1;
      return ParsedCommand(
        intent: CommandIntent.incrementHabit,
        original: input,
        title: 'minum',
        unit: 'gelas',
        amount: amount,
        date: DateTime(now.year, now.month, now.day),
      );
    }
    final activityQuery = RegExp(r'^kapan terakhir\s+(.+)$').firstMatch(text);
    if (activityQuery != null) {
      return result(CommandIntent.queryActivity, title: activityQuery[1]!);
    }
    final memory = IndonesianMemoryParser().parse(
      text,
      isQuestion: input.contains('?'),
    );
    if (memory != null) {
      return result(
        switch (memory.intent) {
          MemoryIntent.save => CommandIntent.saveItemLocation,
          MemoryIntent.update => CommandIntent.updateItemLocation,
          MemoryIntent.find => CommandIntent.findItem,
          MemoryIntent.unclear => CommandIntent.unknown,
        },
        title: memory.item,
        location: memory.location,
        notes: memory.notes,
      );
    }

    // Questions and cancellations must never turn into a new reminder.
    if (RegExp(r'^(?:kapan|apakah|apa|kenapa|mengapa|bagaimana|berapa)\b')
            .hasMatch(text) ||
        RegExp(
          r'\b(?:batal|batalkan|tidak jadi|nggak jadi|gak jadi|jangan ingatkan)\b',
        ).hasMatch(text)) {
      return result(
        CommandIntent.unknown,
        notes: [
          'Untuk membuat pengingat, tulis kegiatan dan waktunya. Untuk melewati pengingat, buka Jadwal.',
        ],
      );
    }
    final weekday = IndonesianWeekdayParser().parse(text, now);
    final isHabit = RegExp(r'\bsetiap\b').hasMatch(text);
    final explicitReminder = reminderPrefix.hasMatch(text);
    final isActivity =
        !explicitReminder &&
        RegExp(r'\b(?:tadi|sudah|udah|kemarin)\b').hasMatch(text);
    final hasDateCue =
        weekday != null ||
        datePattern.hasMatch(text) ||
        RegExp(r'\b(?:besok|lusa|hari ini|tanggal)\b').hasMatch(text);
    final isReminder =
        explicitReminder ||
        hasDateCue ||
        RegExp(r'\b(?:jam|pukul)\s*\d').hasMatch(text) ||
        timePattern.hasMatch(text) ||
        RegExp(r'^(?:aku|saya)\s+(?:mau|akan|ada)\b').hasMatch(text);
    if (!isHabit && !isReminder && !isActivity) {
      return result(CommandIntent.unknown);
    }
    final weeklyMatch = RegExp(
      r'\bsetiap (?:hari )?(senin|selasa|rabu|kamis|jumat|sabtu|minggu)\b',
    ).firstMatch(text);
    final habitWeekday = weeklyMatch == null
        ? null
        : IndonesianWeekdayParser.names.indexOf(weeklyMatch[1]!) + 1;
    if (isHabit &&
        habitWeekday == null &&
        !RegExp(r'\bsetiap (hari|pagi|siang|sore|malam)\b').hasMatch(text)) {
      return result(
        CommandIntent.unknown,
        notes: [
          'Pilih rutinitas harian atau satu hari dalam sepekan, misalnya setiap hari atau setiap Minggu.',
        ],
      );
    }
    final notes = <String>[];
    final match = timePattern.firstMatch(text);
    int? time;
    if (match != null) {
      var hour = int.parse(match[1] ?? match[3]!);
      final minute = int.parse(match[2] ?? match[4] ?? '0');
      final period =
          match[5] ??
          RegExp(r'\bsetiap (pagi|siang|sore|malam)\b').firstMatch(text)?[1] ??
          RegExp(r'\b(pagi|siang|sore|malam)\s+(?=jam|pukul)')
              .firstMatch(text)?[1];
      if (hour > 23 || minute > 59 || (period != null && hour > 12)) {
        notes.add('Jam tidak valid. Pilih waktu yang benar.');
      } else {
        if (period == 'pagi' && hour == 12) hour = 0;
        if (['siang', 'sore', 'malam'].contains(period) && hour < 12) {
          hour += 12;
        }
        time = hour * 60 + minute;
        if (period == null && hour >= 1 && hour <= 12) {
          notes.add(
            'Jam tanpa pagi/siang memakai format 24 jam. Periksa waktunya.',
          );
        }
      }
    } else if (!isActivity) {
      notes.add('Waktu belum disebutkan. Pilih jam terlebih dahulu.');
    }
    final periodOnly = RegExp(r'\b(pagi|siang|sore|malam)\b')
        .firstMatch(text)?[1];
    if (match == null && periodOnly != null && !isActivity) {
      time = switch (periodOnly) {
        'pagi' => 390,
        'siang' => 750,
        'sore' => 930,
        _ => 1110,
      };
      notes.remove('Waktu belum disebutkan. Pilih jam terlebih dahulu.');
      notes.add(
        'Jam untuk “$periodOnly” hanya usulan awal. Ubah sesuai kebutuhan sebelum menyimpan.',
      );
    }
    final target = isHabit
        ? RegExp(r'\b(?:minimal\s+)?(\d+)\s+gelas\b').firstMatch(text)
        : null;
    final targetCount = target == null ? 1 : int.parse(target[1]!);
    if (target != null && (targetCount < 2 || targetCount > 24)) {
      return result(
        CommandIntent.unknown,
        notes: ['Target bertahap mendukung 2–24 gelas per hari.'],
      );
    }
    if (target != null && time == null) {
      time = 360;
      notes.remove('Waktu belum disebutkan. Pilih jam terlebih dahulu.');
      notes.add(
        'Usulan rentang pengingat 06.00–22.00. Atur jam bangun/tidur pada konfirmasi.',
      );
    }
    DateTime? date = DateTime(now.year, now.month, now.day);
    if (text.contains('besok')) {
      date = DateTime(now.year, now.month, now.day + 1);
    }
    if (text.contains('lusa')) {
      date = DateTime(now.year, now.month, now.day + 2);
    }
    if (text.contains('kemarin')) {
      date = DateTime(now.year, now.month, now.day - 1);
    }
    if (weekday != null) {
      date = weekday.date;
      notes.addAll(weekday.notes);
      final relative = RegExp(r'\b(besok|lusa|hari ini|kemarin)\b')
          .firstMatch(text)?[1];
      if (relative != null && date != null) {
        final offset = switch (relative) {
          'besok' => 1,
          'lusa' => 2,
          'kemarin' => -1,
          _ => 0,
        };
        if (date != DateTime(now.year, now.month, now.day + offset)) {
          date = null;
          notes.add(
            'Nama hari dan “$relative” tidak cocok. Pilih tanggal yang dimaksud.',
          );
        }
      }
    }
    final dateMatch = datePattern.firstMatch(text);
    if (dateMatch != null) {
      final day = int.parse(dateMatch[1]!);
      final month = months.indexOf(dateMatch[2]!) + 1;
      var year = int.parse(dateMatch[3] ?? '${now.year}');
      date = DateTime(year, month, day);
      if (date.month != month || date.day != day) {
        date = null;
        notes.add('Tanggal tidak valid. Pilih tanggal yang benar.');
      } else if (dateMatch[3] == null &&
          !isActivity &&
          date.isBefore(DateTime(now.year, now.month, now.day))) {
        year++;
        date = DateTime(year, month, day);
        if (date.month != month || date.day != day) {
          date = null;
          notes.add(
            'Tanggal tidak valid untuk tahun berikutnya. Pilih tanggal.',
          );
        } else {
          notes.add('Tanggal sudah lewat tahun ini; digunakan tahun $year.');
        }
      }
      final namedDay = IndonesianWeekdayParser.pattern.firstMatch(text)?[2];
      if (namedDay != null &&
          date != null &&
          date.weekday != IndonesianWeekdayParser.names.indexOf(namedDay) + 1) {
        date = null;
        notes.add(
          'Nama hari dan tanggal tidak cocok. Pilih tanggal yang dimaksud.',
        );
      }
    } else if (weekday == null &&
        RegExp(r'\btanggal\b|\b\d{1,2}[/\-]\d{1,2}\b').hasMatch(text)) {
      date = null;
      notes.add('Tanggal belum dikenali. Pilih tanggal secara manual.');
    }
    if (!isActivity && !isHabit && !hasDateCue) {
      date = null;
      notes.add('Hari belum disebutkan. Pilih tanggal pengingat.');
    }
    var title = text
        .replaceFirst(reminderPrefix, '')
        .replaceFirst(
          RegExp(r'^(?:aku sudah|saya sudah|tadi|sudah|udah)\s*'),
          '',
        )
        .replaceAll(
          RegExp(
            r'\bsetiap (?:hari )?(?:senin|selasa|rabu|kamis|jumat|sabtu|minggu)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'\bsetiap (?:hari|pagi|siang|sore|malam)\b'), '')
        .replaceAll(RegExp(r'\b(?:pagi|siang|sore|malam)\s+(?=jam|pukul)'), '')
        .replaceAll(timePattern, '')
        .replaceAll(datePattern, '')
        .replaceAll(IndonesianWeekdayParser.pattern, '')
        .replaceAll(RegExp(r'\b(?:pagi|siang|sore|malam)\b'), '')
        .replaceAll(RegExp(r'\b(?:minimal\s+)?\d+\s+gelas\b'), '')
        .replaceAll(
          RegExp(r'\b(?:besok|lusa|hari ini|kemarin|tadi|sudah|udah)\b'),
          '',
        )
        .replaceFirst(RegExp(r'^\s*ada\s+'), '');
    title = normalize(title)
        .replaceFirst(
          RegExp(
            r'^(?:(?:aku|saya|mau|ingin|pengen|akan|ada|untuk|tolong|pada)\s+)+',
          ),
          '',
        )
        .replaceFirst(RegExp(r'\s+(?:ya|dong|deh)$'), '')
        .trim();
    if (title.isEmpty) {
      return result(
        CommandIntent.unknown,
        notes: ['Sebutkan nama kegiatan yang ingin dicatat.'],
      );
    }
    if (isActivity && time == null && match == null) {
      time = now.hour * 60 + now.minute;
    }
    if (isActivity &&
        date != null &&
        time != null &&
        weekday == null &&
        dateMatch == null &&
        !text.contains('kemarin')) {
      final event = DateTime(
        date.year,
        date.month,
        date.day,
        time ~/ 60,
        time % 60,
      );
      if (event.isAfter(now)) {
        date = DateTime(date.year, date.month, date.day - 1);
        notes.add(
          'Jam tersebut belum terjadi hari ini; digunakan kemarin. Periksa kembali.',
        );
      }
    }
    return ParsedCommand(
      original: input,
      intent: isHabit
          ? CommandIntent.createHabit
          : isActivity
          ? CommandIntent.logActivity
          : CommandIntent.createReminder,
      title: title,
      date: date,
      timeMinutes: time,
      notes: notes,
      weekday: habitWeekday,
      targetCount: targetCount,
      unit: target != null ? 'gelas' : null,
      endMinutes: target != null ? 1320 : null,
    );
  }
}
