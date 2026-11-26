import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/scan_throttle.dart';
import '../platform/wifi_source.dart';

/// Holds everything the four tabs show: access state, scan results, the live
/// connection with its history, and the walk-test spots.
class WifiController extends ChangeNotifier {
  WifiController(
    this.source, {
    this.prefs,
    DateTime Function()? clock,
    this.walkDuration = const Duration(seconds: 8),
    this.autoScanEvery = const Duration(seconds: 40),
    this.scanTimeout = const Duration(seconds: 12),
  }) : _clock = clock ?? DateTime.now;

  static const historyLength = 120;
  static const _spotsKey = 'walk_spots';

  final WifiSource source;
  final SharedPreferences? prefs;
  final DateTime Function() _clock;
  final Duration walkDuration;
  final Duration autoScanEvery;
  final Duration scanTimeout;

  final ScanThrottle throttle = ScanThrottle();

  Access access = Access.checking;
  List<AccessPoint> points = const [];
  DateTime? lastScanAt;
  bool scanning = false;

  /// Set when we hold a scan back to stay inside Android's limit.
  Duration? throttleWait;

  /// Set when Android refused or failed the last scan.
  bool systemRefused = false;

  ConnectionInfo connection = ConnectionInfo.disconnected;

  /// RSSI of the connected network, one value per second, oldest first.
  final List<int> history = [];

  List<WalkSpot> spots = [];

  String? walkName;
  DateTime? walkStart;
  String? walkError;
  final List<int> _walkSamples = [];

  StreamSubscription<ScanSnapshot>? _scanSub;
  StreamSubscription<ConnectionInfo>? _connSub;
  Timer? _autoTimer;
  Timer? _scanTimeoutTimer;
  Timer? _walkTimer;
  bool _foreground = true;
  bool _disposed = false;

  bool get walking => walkName != null;

  /// 0..1 progress of the running walk sample.
  double get walkProgress {
    final start = walkStart;
    if (start == null) return 0;
    return (_clock().difference(start).inMilliseconds / walkDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  Future<void> init() async {
    _loadSpots();
    await refreshAccess();
  }

  void _loadSpots() {
    final raw = prefs?.getString(_spotsKey);
    if (raw == null) return;
    try {
      spots = [
        for (final j in jsonDecode(raw) as List<Object?>) WalkSpot.fromJson((j as Map).cast<String, Object?>()),
      ];
    } on Object {
      spots = [];
    }
  }

  Future<void> _saveSpots() async {
    await prefs?.setString(_spotsKey, jsonEncode([for (final s in spots) s.toJson()]));
  }

  Future<void> refreshAccess() async => _apply(await source.checkAccess());

  Future<void> requestAccess() async => _apply(await source.requestAccess());

  void _apply(Access next) {
    if (_disposed) return;
    final wasReady = access == Access.ready;
    access = next;
    if (next == Access.ready && !wasReady) {
      unawaited(_enterReady());
    } else if (next != Access.ready && wasReady) {
      _leaveReady();
    }
    _notify();
  }

  Future<void> _enterReady() async {
    _scanSub?.cancel();
    _scanSub = source.scans.listen(_onScan, onError: (_) {});
    if (_foreground) _listenConnection();
    final cached = await source.scanResults();
    if (_disposed || access != Access.ready) return;
    _onScan(cached, fromCache: true);
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(autoScanEvery, (_) {
      // Keep one scan of the budget for the refresh button.
      if (_foreground && throttle.remaining(_clock()) > 1) unawaited(scan());
    });
    unawaited(scan());
  }

  void _leaveReady() {
    _scanSub?.cancel();
    _scanSub = null;
    _connSub?.cancel();
    _connSub = null;
    _autoTimer?.cancel();
    _autoTimer = null;
    _scanTimeoutTimer?.cancel();
    scanning = false;
    cancelWalk();
  }

  void _listenConnection() {
    _connSub ??= source.connection.listen(_onConnection, onError: (_) {});
  }

  /// Call with false when the app goes to the background to stop polling.
  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (value) {
      unawaited(refreshAccess().then((_) {
        if (!_disposed && _foreground && access == Access.ready) _listenConnection();
      }));
    } else {
      _connSub?.cancel();
      _connSub = null;
    }
  }

  void _onScan(ScanSnapshot snap, {bool fromCache = false}) {
    points = snap.points;
    final now = _clock();
    if (!fromCache) {
      if (snap.success) {
        lastScanAt = now;
        systemRefused = false;
      } else if (scanning) {
        systemRefused = true;
      }
      scanning = false;
      _scanTimeoutTimer?.cancel();
    } else if (snap.age != null && snap.points.isNotEmpty) {
      lastScanAt = now.subtract(snap.age!);
    }
    _notify();
  }

  void _onConnection(ConnectionInfo info) {
    connection = info;
    if (info.connected) {
      history.add(info.rssi);
      if (history.length > historyLength) history.removeAt(0);
      if (walking) _walkSamples.add(info.rssi);
    }
    _notify();
  }

  /// Starts a scan, unless Android's 4-per-2-minutes limit would refuse it.
  Future<void> scan() async {
    if (access != Access.ready || scanning) return;
    final now = _clock();
    final wait = throttle.waitTime(now);
    if (wait != null) {
      throttleWait = wait;
      _notify();
      return;
    }
    throttleWait = null;
    systemRefused = false;
    throttle.record(now);
    scanning = true;
    _notify();
    final ok = await source.startScan();
    if (_disposed || access != Access.ready) return;
    if (!ok) {
      scanning = false;
      systemRefused = true;
      _notify();
      return;
    }
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(scanTimeout, () {
      if (!_disposed && scanning) {
        scanning = false;
        systemRefused = true;
        _notify();
      }
    });
  }

  /// Seconds since the last finished scan, or null when none yet.
  int? get secondsSinceScan {
    final t = lastScanAt;
    if (t == null) return null;
    final s = _clock().difference(t).inSeconds;
    return s < 0 ? 0 : s;
  }

  /// Remaining scan budget, for the UI hint.
  int get scansLeft => throttle.remaining(_clock());

  // Walk test.

  /// Records the connected network's RSSI for [walkDuration]. False when not connected.
  bool startWalk(String name) {
    if (walking || !connection.connected) return false;
    walkError = null;
    walkName = name.trim().isEmpty ? 'Spot ${spots.length + 1}' : name.trim();
    walkStart = _clock();
    _walkSamples
      ..clear()
      ..add(connection.rssi);
    _walkTimer = Timer(walkDuration, _finishWalk);
    _notify();
    return true;
  }

  void _finishWalk() {
    final name = walkName;
    if (name == null) return;
    if (_walkSamples.isEmpty) {
      walkError = 'No signal samples were collected.';
    } else {
      spots = [
        WalkSpot.fromSamples(name, List.of(_walkSamples), _clock(), ssid: connection.ssid),
        ...spots,
      ];
      unawaited(_saveSpots());
    }
    _resetWalk();
    _notify();
  }

  void cancelWalk() {
    if (!walking) return;
    _resetWalk();
    _notify();
  }

  void _resetWalk() {
    _walkTimer?.cancel();
    _walkTimer = null;
    walkName = null;
    walkStart = null;
    _walkSamples.clear();
  }

  void deleteSpot(WalkSpot spot) {
    spots = spots.where((s) => s != spot).toList();
    unawaited(_saveSpots());
    _notify();
  }

  void clearSpots() {
    spots = [];
    unawaited(_saveSpots());
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _leaveReady();
    super.dispose();
  }
}
