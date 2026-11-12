import 'package:airscope/core/models.dart';
import 'package:airscope/core/scan_throttle.dart';
import 'package:airscope/core/security.dart';
import 'package:airscope/core/wifi_math.dart';
import 'package:airscope/screens/channels_screen.dart';
import 'package:airscope/screens/networks_screen.dart';
import 'package:flutter_test/flutter_test.dart';

AccessPoint ap(String ssid, int freq, int rssi, {int width = 0, int center = 0, String caps = '[WPA2-PSK-CCMP]', String bssid = ''}) =>
    AccessPoint(
      ssid: ssid,
      bssid: bssid.isEmpty ? 'aa:bb:cc:00:00:${freq % 100}' : bssid,
      rssi: rssi,
      frequency: freq,
      widthMhz: widthMhzOf(width),
      centerFreq0: center,
      capabilities: caps,
    );

void main() {
  group('bands and channels', () {
    test('2.4 GHz', () {
      expect(bandOf(2412), WifiBand.ghz24);
      expect(channelOf(2412), 1);
      expect(channelOf(2437), 6);
      expect(channelOf(2462), 11);
      expect(channelOf(2472), 13);
      expect(channelOf(2484), 14);
    });

    test('5 GHz', () {
      expect(bandOf(5180), WifiBand.ghz5);
      expect(channelOf(5180), 36);
      expect(channelOf(5745), 149);
      expect(channelOf(5825), 165);
    });

    test('6 GHz', () {
      expect(bandOf(5955), WifiBand.ghz6);
      expect(channelOf(5955), 1);
      expect(channelOf(5935), 2);
      expect(channelOf(6175), 45);
    });

    test('unknown frequency', () {
      expect(bandOf(900), isNull);
      expect(channelOf(900), isNull);
    });

    test('centerFreqOf inverts channelOf', () {
      for (final f in [2412, 2437, 2472, 5180, 5500, 5745, 5955, 6175]) {
        expect(centerFreqOf(bandOf(f)!, channelOf(f)!), f);
      }
    });

    test('channel width codes', () {
      expect([for (var i = 0; i <= 5; i++) widthMhzOf(i)], [20, 40, 80, 160, 160, 320]);
    });
  });

  group('signal', () {
    test('quality is clamped 0..1', () {
      expect(qualityOf(-100), 0);
      expect(qualityOf(-120), 0);
      expect(qualityOf(-75), closeTo(0.5, 1e-9));
      expect(qualityOf(-40), 1);
    });

    test('levels', () {
      expect(signalLevelOf(-50), SignalLevel.excellent);
      expect(signalLevelOf(-60), SignalLevel.good);
      expect(signalLevelOf(-70), SignalLevel.fair);
      expect(signalLevelOf(-85), SignalLevel.weak);
    });

    test('wifi standard names', () {
      expect(wifiStandardName(4, 2437), 'Wi-Fi 4');
      expect(wifiStandardName(5, 5180), 'Wi-Fi 5');
      expect(wifiStandardName(6, 5180), 'Wi-Fi 6');
      expect(wifiStandardName(6, 5955), 'Wi-Fi 6E');
      expect(wifiStandardName(8, 5955), 'Wi-Fi 7');
      expect(wifiStandardName(0, 2437), isNull);
      expect(wifiStandardName(null, 2437), isNull);
    });
  });

  group('security', () {
    test('parses capabilities', () {
      expect(parseSecurity('[ESS]'), Security.open);
      expect(parseSecurity('[WPA2-PSK-CCMP][RSN-PSK-CCMP][ESS]'), Security.wpa2);
      expect(parseSecurity('[RSN-PSK+SAE-CCMP][ESS]'), Security.wpa2wpa3);
      expect(parseSecurity('[RSN-SAE-CCMP][ESS]'), Security.wpa3);
      expect(parseSecurity('[RSN-OWE-CCMP][ESS]'), Security.owe);
      expect(parseSecurity('[WEP][ESS]'), Security.wep);
      expect(parseSecurity('[WPA-PSK-TKIP][ESS]'), Security.wpa);
      expect(parseSecurity('[WPA2-EAP/SHA1-CCMP][ESS]'), Security.wpa2Enterprise);
      expect(parseSecurity('[RSN-EAP_SUITE_B_192-GCMP-256][ESS]'), Security.wpa3Enterprise);
    });

    test('weak flags', () {
      expect(Security.open.weak, isTrue);
      expect(Security.wep.weak, isTrue);
      expect(Security.wpa2.weak, isFalse);
      expect(Security.wpa3.weak, isFalse);
    });
  });

  group('overlap and best channel', () {
    test('2.4 GHz channels 1, 6, 11 do not overlap, 1 and 3 do', () {
      expect(overlapMhz(occupiedRange(2412, 20), occupiedRange(2437, 20)), 0);
      expect(overlapMhz(occupiedRange(2412, 20), occupiedRange(2462, 20)), 0);
      expect(overlapMhz(occupiedRange(2412, 20), occupiedRange(2422, 20)), greaterThan(0));
    });

    test('score is lower on an empty channel', () {
      final aps = [
        const ChannelLoad(centerMhz: 2437, widthMhz: 20, rssi: -50),
        const ChannelLoad(centerMhz: 2437, widthMhz: 20, rssi: -60),
        const ChannelLoad(centerMhz: 2412, widthMhz: 20, rssi: -80),
      ];
      expect(congestionScore(2462, aps), 0);
      expect(congestionScore(2437, aps), greaterThan(congestionScore(2412, aps)));
    });

    test('stronger neighbour counts more than a weaker one', () {
      final strong = [const ChannelLoad(centerMhz: 2437, widthMhz: 20, rssi: -40)];
      final weak = [const ChannelLoad(centerMhz: 2437, widthMhz: 20, rssi: -85)];
      expect(congestionScore(2437, strong), greaterThan(congestionScore(2437, weak)));
    });

    test('recommends the empty 2.4 GHz channel', () {
      final aps = [
        const ChannelLoad(centerMhz: 2412, widthMhz: 20, rssi: -45),
        const ChannelLoad(centerMhz: 2437, widthMhz: 20, rssi: -55),
        const ChannelLoad(centerMhz: 2437, widthMhz: 20, rssi: -65),
      ];
      final r = recommendChannel(WifiBand.ghz24, channels24Recommended, aps);
      expect(r.best.channel, 11);
      expect(r.best.networks, 0);
      expect(r.ranked.map((s) => s.channel).toList(), [11, 1, 6]);
    });

    test('an AP between channels hurts both neighbours', () {
      // Channel 3 (2422) overlaps channels 1 and 6.
      final r = recommendChannel(WifiBand.ghz24, channels24Recommended, [
        const ChannelLoad(centerMhz: 2422, widthMhz: 20, rssi: -40),
      ]);
      expect(r.best.channel, 11);
    });

    test('empty scan: ties go to the lowest channel, 5 GHz prefers non-DFS', () {
      expect(recommendChannel(WifiBand.ghz24, channels24Recommended, const []).best.channel, 1);
      expect(recommendChannel(WifiBand.ghz5, channels5, const []).best.channel, 36);
    });

    test('5 GHz wide channel blocks every 20 MHz channel under it', () {
      // 80 MHz centered 5210 covers channels 36-48.
      final aps = [const ChannelLoad(centerMhz: 5210, widthMhz: 80, rssi: -45)];
      final r = recommendChannel(WifiBand.ghz5, channels5, aps);
      expect(r.best.channel, 149); // free and not DFS beats free DFS channels
      for (final ch in [36, 40, 44, 48]) {
        expect(r.ranked.firstWhere((s) => s.channel == ch).networks, 1);
      }
    });

    test('parabola peaks in the middle and is 0 outside', () {
      expect(parabola(2437, 2437, 20, 1), 1);
      expect(parabola(2437 + 11, 2437, 20, 1), 0);
      expect(parabola(2437 + 5.5, 2437, 20, 1), closeTo(0.75, 1e-9));
      expect(parabola(2500, 2437, 20, 1), 0);
    });
  });

  group('recommendFor', () {
    test('ignores the connected network', () {
      final own = ap('Home', 2437, -40, bssid: 'AA:AA:AA:AA:AA:AA');
      final other = ap('Neighbour', 2412, -60);
      final r = recommendFor(WifiBand.ghz24, [own, other], ownBssid: 'aa:aa:aa:aa:aa:aa')!;
      expect(r.ranked.firstWhere((s) => s.channel == 6).networks, 0);
      expect(r.ranked.firstWhere((s) => s.channel == 1).networks, 1);
    });

    test('6 GHz has no recommendation', () {
      expect(recommendFor(WifiBand.ghz6, []), isNull);
    });
  });

  group('AccessPoint', () {
    test('wide channel uses center frequency', () {
      final a = ap('Wide', 5180, -50, width: 2, center: 5210);
      expect(a.widthMhz, 80);
      expect(a.centerMhz, 5210);
      expect(a.channel, 36);
      expect(a.channelLabel, 'Ch 36 · 80 MHz');
    });

    test('hidden network', () {
      final a = ap('', 2437, -70);
      expect(a.hidden, isTrue);
      expect(a.name, 'Hidden network');
    });

    test('fromMap', () {
      final a = AccessPoint.fromMap({
        'ssid': 'Cafe',
        'bssid': '00:11:22:33:44:55',
        'rssi': -61,
        'frequency': 5745,
        'channelWidth': 1,
        'centerFreq0': 5755,
        'capabilities': '[RSN-SAE-CCMP][ESS]',
        'standard': 6,
      });
      expect(a.security, Security.wpa3);
      expect(a.widthMhz, 40);
      expect(a.standard, 'Wi-Fi 6');
      expect(a.band, WifiBand.ghz5);
    });
  });

  group('filter and sort', () {
    final list = [
      ap('Zed', 2437, -60),
      ap('alpha', 5180, -45),
      ap('', 2412, -50),
    ];

    test('by signal', () {
      expect(filterAndSort(list).map((a) => a.rssi).toList(), [-45, -50, -60]);
    });

    test('by name puts hidden last, ignores case', () {
      expect(filterAndSort(list, sort: NetworkSort.name).map((a) => a.ssid).toList(), ['alpha', 'Zed', '']);
    });

    test('by channel', () {
      expect(filterAndSort(list, sort: NetworkSort.channel).map((a) => a.frequency).toList(), [2412, 2437, 5180]);
    });

    test('band filter', () {
      expect(filterAndSort(list, band: WifiBand.ghz5).map((a) => a.ssid).toList(), ['alpha']);
    });
  });

  group('walk test', () {
    test('verdicts', () {
      expect(verdictOf(-55), SpotVerdict.good);
      expect(verdictOf(-60), SpotVerdict.good);
      expect(verdictOf(-65), SpotVerdict.ok);
      expect(verdictOf(-70), SpotVerdict.ok);
      expect(verdictOf(-71), SpotVerdict.weak);
    });

    test('average, min, max and json round trip', () {
      final spot = WalkSpot.fromSamples('Kitchen', [-60, -64, -68], DateTime.fromMillisecondsSinceEpoch(1000), ssid: 'Home');
      expect(spot.avgRssi, closeTo(-64, 1e-9));
      expect(spot.minRssi, -68);
      expect(spot.maxRssi, -60);
      expect(spot.verdict, SpotVerdict.ok);
      final back = WalkSpot.fromJson(spot.toJson());
      expect(back.name, 'Kitchen');
      expect(back.avgRssi, spot.avgRssi);
      expect(back.time, spot.time);
      expect(back.ssid, 'Home');
    });
  });

  group('ScanThrottle', () {
    test('allows 4 scans per 2 minutes, then waits', () {
      final t = ScanThrottle();
      final start = DateTime(2026, 1, 1, 12);
      for (var i = 0; i < 4; i++) {
        expect(t.waitTime(start.add(Duration(seconds: i * 10))), isNull);
        t.record(start.add(Duration(seconds: i * 10)));
      }
      final now = start.add(const Duration(seconds: 40));
      expect(t.remaining(now), 0);
      expect(t.waitTime(now), const Duration(seconds: 80));
    });

    test('frees a slot after the window passes', () {
      final t = ScanThrottle();
      final start = DateTime(2026, 1, 1, 12);
      for (var i = 0; i < 4; i++) {
        t.record(start);
      }
      expect(t.waitTime(start.add(const Duration(seconds: 119))), const Duration(seconds: 1));
      expect(t.waitTime(start.add(const Duration(seconds: 120))), isNull);
      expect(t.remaining(start.add(const Duration(seconds: 120))), 4);
    });
  });
}
