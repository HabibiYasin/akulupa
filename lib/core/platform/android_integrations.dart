import 'package:flutter/services.dart';

class AndroidIntegrations {
  const AndroidIntegrations();
  static const channel = MethodChannel('id.akulupa/integrations');
  Future<String?> recoverDocument() =>
      channel.invokeMethod<String>('recoverDocument');
  Future<bool> saveDocument(String path, String name) async =>
      await channel.invokeMethod<bool>('saveDocument', {
        'path': path,
        'name': name,
      }) ??
      false;
  Future<String?> openDocument() =>
      channel.invokeMethod<String>('openDocument');
  Future<void> openCalendar(String title, DateTime at) =>
      channel.invokeMethod<void>('openCalendar', {
        'title': title,
        'start': at.millisecondsSinceEpoch,
        'end': at.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      });
  Future<void> updateWidget(String snapshot) =>
      channel.invokeMethod<void>('updateWidget', {'snapshot': snapshot});
  Future<void> pinWidget() => channel.invokeMethod<void>('pinWidget');
  Future<Map<String, dynamic>> locationStatus() async =>
      Map<String, dynamic>.from(
        (await channel.invokeMapMethod<String, dynamic>('locationStatus'))!,
      );
  Future<void> requestLocation() =>
      channel.invokeMethod<void>('requestLocation');
  Future<void> openLocationSettings() =>
      channel.invokeMethod<void>('openLocationSettings');
  Future<Map<String, dynamic>> currentLocation() async =>
      Map<String, dynamic>.from(
        (await channel.invokeMapMethod<String, dynamic>('currentLocation'))!,
      );
  Future<void> registerPlace(Map<String, dynamic> place) =>
      channel.invokeMethod<void>('registerPlace', place);
  Future<void> removePlace(int id) =>
      channel.invokeMethod<void>('removePlace', {'id': id});
  Future<Map<String, dynamic>> placeEvents() async => Map<String, dynamic>.from(
    (await channel.invokeMapMethod<String, dynamic>('placeEvents')) ?? {},
  );
  Future<void> clearPlaces() => channel.invokeMethod<void>('clearPlaces');
}
