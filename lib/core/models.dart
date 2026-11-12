import 'security.dart';
import 'wifi_math.dart';

/// One access point from a scan.
class AccessPoint {
  AccessPoint({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
    required this.widthMhz,
    required this.centerFreq0,
    required this.capabilities,
    this.standardCode,
  }) : security = parseSecurity(capabilities);

  factory AccessPoint.fromMap(Map<Object?, Object?> m) => AccessPoint(
        ssid: (m['ssid'] as String?) ?? '',
        bssid: (m['bssid'] as String?) ?? '',
        rssi: (m['rssi'] as num?)?.toInt() ?? -100,
        frequency: (m['frequency'] as num?)?.toInt() ?? 0,
        widthMhz: widthMhzOf((m['channelWidth'] as num?)?.toInt() ?? 0),
        centerFreq0: (m['centerFreq0'] as num?)?.toInt() ?? 0,
        capabilities: (m['capabilities'] as String?) ?? '',
        standardCode: (m['standard'] as num?)?.toInt(),
      );

  final String ssid;
  final String bssid;
  final int rssi;
  final int frequency;
  final int widthMhz;

  /// Center frequency of the whole channel (differs from [frequency] for 40/80/160 MHz).
  final int centerFreq0;
  final String capabilities;
  final int? standardCode;
  final Security security;

  bool get hidden => ssid.isEmpty;
  String get name => hidden ? 'Hidden network' : ssid;
  WifiBand? get band => bandOf(frequency);
  int? get channel => channelOf(frequency);
  double get quality => qualityOf(rssi);
  SignalLevel get level => signalLevelOf(rssi);
  String? get standard => wifiStandardName(standardCode, frequency);

  /// Center of the occupied spectrum.
  int get centerMhz => centerFreq0 > 0 ? centerFreq0 : frequency;

  /// Primary channel plus the span, for example `36 (80 MHz)`.
  String get channelLabel {
    final ch = channel;
    final base = ch == null ? '$frequency MHz' : 'Ch $ch';
    return widthMhz > 20 ? '$base · $widthMhz MHz' : base;
  }

  ChannelLoad get load => ChannelLoad(centerMhz: centerMhz, widthMhz: widthMhz, rssi: rssi);
}

/// Live state of the connected network.
class ConnectionInfo {
  const ConnectionInfo({
    required this.connected,
    this.ssid = '',
    this.bssid = '',
    this.rssi = -127,
    this.linkSpeed = 0,
    this.txSpeed = 0,
    this.rxSpeed = 0,
    this.frequency = 0,
    this.ip = '',
    this.gateway = '',
  });

  factory ConnectionInfo.fromMap(Map<Object?, Object?> m) {
    int n(String k) => (m[k] as num?)?.toInt() ?? 0;
    String s(String k) => (m[k] as String?) ?? '';
    return ConnectionInfo(
      connected: m['connected'] == true,
      ssid: s('ssid'),
      bssid: s('bssid'),
      rssi: (m['rssi'] as num?)?.toInt() ?? -127,
      linkSpeed: n('linkSpeed'),
      txSpeed: n('txSpeed'),
      rxSpeed: n('rxSpeed'),
      frequency: n('frequency'),
      ip: s('ip'),
      gateway: s('gateway'),
    );
  }

  static const disconnected = ConnectionInfo(connected: false);

  final bool connected;
  final String ssid;
  final String bssid;
  final int rssi;
  final int linkSpeed;
  final int txSpeed;
  final int rxSpeed;
  final int frequency;
  final String ip;
  final String gateway;

  WifiBand? get band => bandOf(frequency);
  int? get channel => channelOf(frequency);
}

/// Verdict for a walk-test spot.
enum SpotVerdict {
  good('Good'),
  ok('OK'),
  weak('Weak');

  const SpotVerdict(this.label);
  final String label;
}

SpotVerdict verdictOf(double avgRssi) {
  if (avgRssi >= -60) return SpotVerdict.good;
  if (avgRssi >= -70) return SpotVerdict.ok;
  return SpotVerdict.weak;
}

/// One measured spot of the walk test.
class WalkSpot {
  const WalkSpot({
    required this.name,
    required this.avgRssi,
    required this.minRssi,
    required this.maxRssi,
    required this.samples,
    required this.time,
    this.ssid = '',
  });

  /// Average of [rssis]. Needs at least one sample.
  factory WalkSpot.fromSamples(String name, List<int> rssis, DateTime time, {String ssid = ''}) {
    assert(rssis.isNotEmpty);
    final sum = rssis.fold<int>(0, (a, b) => a + b);
    return WalkSpot(
      name: name,
      avgRssi: sum / rssis.length,
      minRssi: rssis.reduce((a, b) => a < b ? a : b),
      maxRssi: rssis.reduce((a, b) => a > b ? a : b),
      samples: rssis.length,
      time: time,
      ssid: ssid,
    );
  }

  factory WalkSpot.fromJson(Map<String, Object?> j) => WalkSpot(
        name: j['name'] as String,
        avgRssi: (j['avg'] as num).toDouble(),
        minRssi: (j['min'] as num).toInt(),
        maxRssi: (j['max'] as num).toInt(),
        samples: (j['n'] as num).toInt(),
        time: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        ssid: (j['ssid'] as String?) ?? '',
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'avg': avgRssi,
        'min': minRssi,
        'max': maxRssi,
        'n': samples,
        't': time.millisecondsSinceEpoch,
        'ssid': ssid,
      };

  final String name;
  final double avgRssi;
  final int minRssi;
  final int maxRssi;
  final int samples;
  final DateTime time;
  final String ssid;

  SpotVerdict get verdict => verdictOf(avgRssi);
}
