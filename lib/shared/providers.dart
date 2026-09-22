import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_services.dart';
import '../core/database/app_database.dart';
import '../core/models.dart';
import '../features/memory/item_repository.dart';

final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('Override at app startup'),
);
final memoriesProvider = StreamProvider<List<ItemMemory>>(
  (ref) => ref.watch(servicesProvider).items.watchSearch(),
);
final searchProvider = StreamProvider.family<List<ItemMemory>, String>(
  (ref, query) => ref.watch(servicesProvider).items.watchSearch(query),
);
final remindersProvider = StreamProvider<List<Reminder>>(
  (ref) => ref.watch(servicesProvider).reminders.watchAll(),
);
final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(servicesProvider).habits.watchAll(),
);
final habitLogsProvider = StreamProvider<List<HabitLog>>(
  (ref) => ref.watch(servicesProvider).habits.watchLogs(),
);
final activitiesProvider = StreamProvider<List<ActivityLog>>(
  (ref) => ref.watch(servicesProvider).activities.watchAll(),
);
final personalityProvider = StreamProvider<Personality>(
  (ref) => ref.watch(servicesProvider).settings.watch(),
);
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});
