import 'dart:math' as math;

/// Wi-Fi frequency band.
enum WifiBand {
  ghz24('2.4 GHz'),
  ghz5('5 GHz'),
  ghz6('6 GHz');

  const WifiBand(this.label);
  final String label;
}

/// Band of a center frequency in MHz, or null when it is not a Wi-Fi frequency.
WifiBand? bandOf(int freqMhz) {
  if (freqMhz >= 2400 && freqMhz <= 2500) return WifiBand.ghz24;
  if (freqMhz >= 4900 && freqMhz < 5925) return WifiBand.ghz5;
  if (freqMhz >= 5925 && freqMhz <= 7125) return WifiBand.ghz6;
  return null;
}

/// 802.11 channel number of a center frequency in MHz, or null when unknown.
int? channelOf(int freqMhz) {
  switch (bandOf(freqMhz)) {
    case WifiBand.ghz24:
      if (freqMhz == 2484) return 14;
      if (freqMhz >= 2412 && freqMhz <= 2472) return (freqMhz - 2407) ~/ 5;
      return null;
    case WifiBand.ghz5:
      return (freqMhz - 5000) ~/ 5;
    case WifiBand.ghz6:
      if (freqMhz == 5935) return 2;
      return (freqMhz - 5950) ~/ 5;
    case null:
      return null;
  }
}

/// Center frequency of a 20 MHz channel in a band.
int centerFreqOf(WifiBand band, int channel) {
  switch (band) {
    case WifiBand.ghz24:
      return channel == 14 ? 2484 : 2407 + channel * 5;
    case WifiBand.ghz5:
      return 5000 + channel * 5;
    case WifiBand.ghz6:
      return channel == 2 ? 5935 : 5950 + channel * 5;
  }
}

/// Channel width in MHz from `ScanResult.channelWidth` (0=20, 1=40, 2=80, 3=160, 4=80+80).
int widthMhzOf(int channelWidthCode) {
  return switch (channelWidthCode) {
    1 => 40,
    2 => 80,
    3 => 160,
    4 => 160,
    5 => 320,
    _ => 20,
  };
}

/// Signal quality 0..1 from RSSI in dBm (-100 dBm or lower is 0, -50 dBm or higher is 1).
double qualityOf(int rssi) => ((rssi + 100) / 50).clamp(0.0, 1.0);

enum SignalLevel {
  excellent('Excellent'),
  good('Good'),
  fair('Fair'),
  weak('Weak');

  const SignalLevel(this.label);
  final String label;
}

SignalLevel signalLevelOf(int rssi) {
  if (rssi >= -55) return SignalLevel.excellent;
  if (rssi >= -67) return SignalLevel.good;
  if (rssi >= -78) return SignalLevel.fair;
  return SignalLevel.weak;
}

/// Name of the Wi-Fi generation from `ScanResult.getWifiStandard` (API 30+).
String? wifiStandardName(int? code, int freqMhz) {
  switch (code) {
    case 1:
      return 'Legacy (a/b/g)';
    case 4:
      return 'Wi-Fi 4';
    case 5:
      return 'Wi-Fi 5';
    case 6:
      return bandOf(freqMhz) == WifiBand.ghz6 ? 'Wi-Fi 6E' : 'Wi-Fi 6';
    case 7:
      return '802.11ad';
    case 8:
      return 'Wi-Fi 7';
    default:
      return null;
  }
}

/// Frequency range in MHz an access point occupies, [low, high].
///
/// A 20 MHz network on 2.4 GHz occupies 22 MHz (DSSS mask).
(double, double) occupiedRange(int centerMhz, int widthMhz) {
  final span = (widthMhz == 20 && bandOf(centerMhz) == WifiBand.ghz24) ? 22 : widthMhz;
  return (centerMhz - span / 2, centerMhz + span / 2);
}

/// Overlap of two ranges in MHz (0 when they do not overlap).
double overlapMhz((double, double) a, (double, double) b) {
  final lo = math.max(a.$1, b.$1);
  final hi = math.min(a.$2, b.$2);
  return math.max(0, hi - lo);
}

/// One access point reduced to what channel planning needs.
class ChannelLoad {
  const ChannelLoad({required this.centerMhz, required this.widthMhz, required this.rssi});

  final int centerMhz;
  final int widthMhz;
  final int rssi;
}

/// Interference weight of a signal: 0 at -100 dBm, 1 at -30 dBm or stronger, squared
/// so strong neighbours count far more than faint ones.
double signalWeight(int rssi) {
  final w = ((rssi + 100) / 70).clamp(0.0, 1.0);
  return w * w;
}

/// Congestion score of a 20 MHz candidate channel: sum over the other access points
/// of the share of the candidate they overlap, times their signal weight. Lower is better.
double congestionScore(int candidateCenterMhz, Iterable<ChannelLoad> aps, {int candidateWidthMhz = 20}) {
  final cand = occupiedRange(candidateCenterMhz, candidateWidthMhz);
  final candSpan = cand.$2 - cand.$1;
  var score = 0.0;
  for (final ap in aps) {
    final range = occupiedRange(ap.centerMhz, ap.widthMhz);
    final share = overlapMhz(cand, range) / candSpan;
    if (share > 0) score += share * signalWeight(ap.rssi);
  }
  return score;
}

/// Number of access points whose range overlaps the candidate at all.
int overlappingCount(int candidateCenterMhz, Iterable<ChannelLoad> aps, {int candidateWidthMhz = 20}) {
  final cand = occupiedRange(candidateCenterMhz, candidateWidthMhz);
  return aps.where((ap) => overlapMhz(cand, occupiedRange(ap.centerMhz, ap.widthMhz)) > 0).length;
}

/// 2.4 GHz channels worth recommending: the three non-overlapping ones.
const channels24Recommended = [1, 6, 11];

/// 20 MHz channels of the 5 GHz band (UNII-1/2/2e/3).
const channels5 = [36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140, 144, 149, 153, 157, 161, 165];

/// 5 GHz channels 52-144 need radar detection (DFS); some routers pause for a minute on them.
bool isDfs5(int channel) => channel >= 52 && channel <= 144;

class ChannelScore {
  const ChannelScore({required this.channel, required this.score, required this.networks});

  final int channel;
  final double score;
  final int networks;
}

class ChannelRecommendation {
  const ChannelRecommendation({required this.best, required this.ranked});

  /// Lowest congestion; ties go to non-DFS, then the lower channel.
  final ChannelScore best;

  /// All candidates, best first.
  final List<ChannelScore> ranked;
}

/// Best channel among [candidates] for [band] given the other access points.
ChannelRecommendation recommendChannel(WifiBand band, List<int> candidates, Iterable<ChannelLoad> aps) {
  final scores = [
    for (final ch in candidates)
      ChannelScore(
        channel: ch,
        score: congestionScore(centerFreqOf(band, ch), aps),
        networks: overlappingCount(centerFreqOf(band, ch), aps),
      ),
  ];
  scores.sort((a, b) {
    final bySize = (a.score - b.score);
    if (bySize.abs() > 1e-9) return bySize < 0 ? -1 : 1;
    if (band == WifiBand.ghz5) {
      final dfs = (isDfs5(a.channel) ? 1 : 0) - (isDfs5(b.channel) ? 1 : 0);
      if (dfs != 0) return dfs;
    }
    return a.channel.compareTo(b.channel);
  });
  return ChannelRecommendation(best: scores.first, ranked: scores);
}

/// Height of the channel-graph curve at [freqMhz] for an AP: a parabola over its width,
/// peaking at [peak] (0..1) in the middle and 0 at the edges.
double parabola(double freqMhz, int centerMhz, int widthMhz, double peak) {
  final range = occupiedRange(centerMhz, widthMhz);
  final half = (range.$2 - range.$1) / 2;
  final d = (freqMhz - centerMhz) / half;
  if (d.abs() >= 1) return 0;
  return peak * (1 - d * d);
}
