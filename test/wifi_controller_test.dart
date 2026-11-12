import 'dart:async';

import 'package:airscope/core/models.dart';
import 'package:airscope/platform/wifi_source.dart';
import 'package:airscope/state/wifi_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSource implements WifiSource {
  Access access = Access.ready;
  bool startResult = true;
  int startCalls = 0;
  final scanCtl = StreamController<ScanSnapshot>.broadcast();
  final connCtl = StreamController<ConnectionInfo>.broadcast();

  @override
  Future<Access> checkAccess() async => access;
  @override
  Future<Access> requestAccess() async => access;
  @override
  Future<bool> startScan() async {
    startCalls++;
    return startResult;
  }

  @override
  Future<ScanSnapshot> scanResults() async => const ScanSnapshot([], age: null);
  @override
  Stream<ScanSnapshot> get scans => scanCtl.stream;
  @override
  Stream<ConnectionInfo> get connection => connCtl.stream;
  @override
  Future<void> openLocationSettings() async {}
  @override
  Future<void> openWifiSettings() async {}
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> keepScreenOn(bool on) async {}
}

ConnectionInfo conn(int rssi) => ConnectionInfo(connected: true, ssid: 'Home', bssid: 'aa', rssi: rssi, frequency: 2437);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeSource source;
  late WifiController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    source = FakeSource();
    c = WifiController(
      source,
      prefs: await SharedPreferences.getInstance(),
      walkDuration: const Duration(milliseconds: 50),
      autoScanEvery: const Duration(hours: 1),
    );
  });

  tearDown(() => c.dispose());

  test('ready: scans once and shows results of the scan broadcast', () async {
    await c.init();
    await settle();
    expect(source.startCalls, 1);
    expect(c.scanning, isTrue);
    source.scanCtl.add(ScanSnapshot([
      AccessPoint(ssid: 'A', bssid: '1', rssi: -50, frequency: 2412, widthMhz: 20, centerFreq0: 0, capabilities: ''),
    ]));
    await settle();
    expect(c.scanning, isFalse);
    expect(c.points, hasLength(1));
    expect(c.lastScanAt, isNotNull);
  });

  test('stops after 4 scans in 2 minutes and tells why', () async {
    await c.init();
    await settle();
    for (var i = 0; i < 3; i++) {
      source.scanCtl.add(const ScanSnapshot([]));
      await settle();
      await c.scan();
    }
    source.scanCtl.add(const ScanSnapshot([]));
    await settle();
    expect(source.startCalls, 4);
    await c.scan();
    expect(source.startCalls, 4);
    expect(c.throttleWait, isNotNull);
    expect(c.scansLeft, 0);
  });

  test('flags a refused scan', () async {
    source.startResult = false;
    await c.init();
    await settle();
    expect(c.systemRefused, isTrue);
    expect(c.scanning, isFalse);
  });

  test('blocked states do not scan', () async {
    source.access = Access.locationOff;
    await c.init();
    expect(c.access, Access.locationOff);
    expect(source.startCalls, 0);
  });

  test('connection history is capped', () async {
    await c.init();
    await settle();
    for (var i = 0; i < WifiController.historyLength + 10; i++) {
      source.connCtl.add(conn(-50 - (i % 5)));
    }
    await settle();
    expect(c.history, hasLength(WifiController.historyLength));
    expect(c.connection.connected, isTrue);
  });

  test('walk test records the average and persists the spot', () async {
    await c.init();
    await settle();
    expect(c.startWalk('Kitchen'), isFalse); // not connected yet
    source.connCtl.add(conn(-60));
    await settle();
    expect(c.startWalk('Kitchen'), isTrue);
    expect(c.walking, isTrue);
    source.connCtl.add(conn(-70));
    await settle();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(c.walking, isFalse);
    expect(c.spots, hasLength(1));
    expect(c.spots.first.name, 'Kitchen');
    expect(c.spots.first.avgRssi, closeTo(-65, 1e-9));
    expect(c.spots.first.verdict, SpotVerdict.ok);

    // A new controller reads the saved spot back.
    final again = WifiController(source, prefs: await SharedPreferences.getInstance());
    await again.init();
    expect(again.spots.map((s) => s.name), ['Kitchen']);
    again.dispose();
  });

  test('empty walk name gets a default', () async {
    await c.init();
    await settle();
    source.connCtl.add(conn(-55));
    await settle();
    c.startWalk('  ');
    expect(c.walkName, 'Spot 1');
    c.cancelWalk();
    expect(c.walking, isFalse);
  });
}
