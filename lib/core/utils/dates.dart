import 'package:intl/intl.dart';

String dayKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String clockText(DateTime value) => DateFormat('HH:mm').format(value);
String fullDate(DateTime value) =>
    DateFormat('d MMMM yyyy', 'id_ID').format(value);
String dateTimeText(DateTime value) =>
    '${fullDate(value)}, ${clockText(value)}';
String minutesText(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String relativeTime(DateTime value, DateTime now) {
  final difference = now.difference(value);
  if (difference.isNegative) return dateTimeText(value);
  if (difference.inMinutes < 1) return 'Baru saja';
  if (difference.inHours < 1) return '${difference.inMinutes} menit lalu';
  if (difference.inDays < 1) return '${difference.inHours} jam lalu';
  if (difference.inDays == 1) return 'Kemarin';
  return fullDate(value);
}
