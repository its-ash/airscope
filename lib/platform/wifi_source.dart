import '../core/models.dart';

/// Why the app can or cannot read Wi-Fi data right now.
enum Access {
  checking,
  needPermission,
  permissionBlocked,
  locationOff,
  wifiOff,
  ready,
}

/// Scan results with how old they are.
class ScanSnapshot {
  const ScanSnapshot(this.points, {this.success = true, this.age});

  final List<AccessPoint> points;

  /// False when the system re-sent cached results (the scan itself failed or was throttled).
  final bool success;

  /// Age of the newest result, when known.
  final Duration? age;
}

/// Everything the app needs from the phone. The real one talks to Kotlin; tests use a fake.
abstract class WifiSource {
  /// Current access state, without any prompt.
  Future<Access> checkAccess();

  /// Asks for the permissions, then returns the access state.
  Future<Access> requestAccess();

  /// Asks Android for a scan. False when Android refused (throttled or Wi-Fi off).
  Future<bool> startScan();

  /// Cached results of the last scan.
  Future<ScanSnapshot> scanResults();

  /// Emits after every finished scan.
  Stream<ScanSnapshot> get scans;

  /// Emits the connected network about once a second while listened to.
  Stream<ConnectionInfo> get connection;

  Future<void> openLocationSettings();
  Future<void> openWifiSettings();
  Future<void> openAppSettings();
  Future<void> keepScreenOn(bool on);
}
