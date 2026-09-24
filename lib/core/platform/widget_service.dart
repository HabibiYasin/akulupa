import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models.dart';
import 'android_integrations.dart';

class WidgetService {
  WidgetService(this.db, this.platform);
  final AppDatabase db;
  final AndroidIntegrations platform;
  StreamSubscription<dynamic>? _subscription;
  Timer? _timer;
  Future<void> _queue = Future.value();
  void start() {
    _subscription ??= db.tableUpdates().listen((_) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 300), refresh);
    });
    refresh();
  }

  Future<void> refresh() {
    _queue = _queue
        .then((_) async {
          final data = await db.transaction(
            () async => {
              'reminders': [
                for (final r in await db.select(db.reminders).get())
                  if (r.status == EntryStatus.pending)
                    {
                      'title': r.title,
                      'at': (r.snoozedUntil ?? r.scheduledAt)
                          .millisecondsSinceEpoch,
                    },
              ],
              'habits': [
                for (final h in await db.select(db.habits).get())
                  if (h.isActive)
                    {
                      'id': h.id,
                      'title': h.title,
                      'minutes': h.scheduleTime,
                      'weekday': h.weekday ?? 0,
                      'target': h.targetCount,
                    },
              ],
              'logs': [
                for (final l in await db.select(db.habitLogs).get())
                  {
                    'id': l.habitId,
                    'date': l.date,
                    'status': l.status.name,
                    'progress': l.progress,
                  },
              ],
            },
          );
          await platform.updateWidget(jsonEncode(data));
        })
        .catchError((Object e) {
          debugPrint('Widget update: $e');
        });
    return _queue;
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();
    await _queue;
  }
}
