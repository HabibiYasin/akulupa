import '../../core/database/app_database.dart';
import '../../core/platform/android_integrations.dart';
import 'place_repository.dart';

class PlaceService {
  PlaceService(this.repository, this.platform);
  final PlaceRepository repository;
  final AndroidIntegrations platform;
  Future<void> _queue = Future.value();
  Future<void> _serial(Future<void> Function() work) {
    final next = _queue.then((_) => work());
    _queue = next.catchError((Object _) {});
    return next;
  }

  Map<String, dynamic> _payload(PlaceReminder p) => {
    'id': p.id,
    'title': p.title,
    'placeName': p.placeName,
    'latitude': p.latitude,
    'longitude': p.longitude,
    'radius': p.radius,
  };
  Future<void> refresh() => _serial(_refresh);
  Future<void> replaceData(Future<void> Function() work) => _serial(() async {
    await platform.clearPlaces();
    try {
      await work();
    } finally {
      await _refresh();
    }
  });
  Future<void> _refresh() async {
    final events = await platform.placeEvents();
    for (final e in events.entries) {
      await repository.triggered(
        int.parse(e.key),
        DateTime.fromMillisecondsSinceEpoch(e.value as int),
      );
    }
    for (final p in await repository.all()) {
      if (p.isActive) {
        await platform.registerPlace(_payload(p));
      } else {
        await platform.removePlace(p.id);
      }
    }
  }

  Future<void> toggle(PlaceReminder p, bool active) => _serial(() async {
    if (active) {
      if ((await repository.all()).where((p) => p.isActive).length >= 100) {
        throw StateError('Maksimal 100 pengingat lokasi aktif.');
      }
      await platform.removePlace(p.id);
      await platform.registerPlace(_payload(p));
      try {
        await repository.setActive(p.id, true);
      } catch (_) {
        await platform.removePlace(p.id);
        rethrow;
      }
    } else {
      await platform.removePlace(p.id);
      await repository.setActive(p.id, false);
    }
  });
}
