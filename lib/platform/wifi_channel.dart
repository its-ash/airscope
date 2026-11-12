import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../core/models.dart';
import 'wifi_source.dart';

/// [WifiSource] backed by the Kotlin side (`com.itsash.airscope/*`) and permission_handler.
class WifiChannel implements WifiSource {
  const WifiChannel();

  static const _method = MethodChannel('com.itsash.airscope/wifi');
  static const _scanEvents = EventChannel('com.itsash.airscope/scan');
  static const _connEvents = EventChannel('com.itsash.airscope/connection');

  @override
  Future<Access> checkAccess() => _evaluate(ask: false);

  @override
  Future<Access> requestAccess() => _evaluate(ask: true);

  Future<Access> _evaluate({required bool ask}) async {
    var status = await ph.Permission.location.status;
    if (!status.isGranted && ask) status = await ph.Permission.location.request();
    if (!status.isGranted) {
      return status.isPermanentlyDenied ? Access.permissionBlocked : Access.needPermission;
    }
    // Android 13+: the Wi-Fi scan permission. Older versions report it as granted.
    if (ask && !(await ph.Permission.nearbyWifiDevices.status).isGranted) {
      await ph.Permission.nearbyWifiDevices.request();
    }
    if (await _method.invokeMethod<bool>('isLocationEnabled') != true) return Access.locationOff;
    if (await _method.invokeMethod<bool>('isWifiEnabled') != true) return Access.wifiOff;
    return Access.ready;
  }

  @override
  Future<bool> startScan() async {
    try {
      return await _method.invokeMethod<bool>('startScan') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<ScanSnapshot> scanResults() async {
    final raw = await _method.invokeMethod<List<Object?>>('scanResults');
    return _snapshot(raw ?? const [], success: true);
  }

  @override
  Stream<ScanSnapshot> get scans => _scanEvents.receiveBroadcastStream().map((e) {
        final m = e as Map<Object?, Object?>;
        return _snapshot((m['results'] as List<Object?>?) ?? const [], success: m['success'] == true);
      });

  @override
  Stream<ConnectionInfo> get connection =>
      _connEvents.receiveBroadcastStream().map((e) => ConnectionInfo.fromMap(e as Map<Object?, Object?>));

  static ScanSnapshot _snapshot(List<Object?> raw, {required bool success}) {
    final maps = raw.cast<Map<Object?, Object?>>();
    final points = maps.map(AccessPoint.fromMap).toList();
    final ages = maps.map((m) => (m['ageMs'] as num?)?.toInt()).whereType<int>();
    final newest = ages.isEmpty ? null : ages.reduce((a, b) => a < b ? a : b);
    return ScanSnapshot(
      points,
      success: success,
      age: newest == null ? null : Duration(milliseconds: newest < 0 ? 0 : newest),
    );
  }

  @override
  Future<void> openLocationSettings() => _method.invokeMethod<void>('openLocationSettings');

  @override
  Future<void> openWifiSettings() => _method.invokeMethod<void>('openWifiSettings');

  @override
  Future<void> openAppSettings() => ph.openAppSettings();

  @override
  Future<void> keepScreenOn(bool on) => _method.invokeMethod<void>('keepScreenOn', on);
}
