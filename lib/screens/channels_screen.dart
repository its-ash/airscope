import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/models.dart';
import '../core/wifi_math.dart';
import '../state/wifi_controller.dart';
import '../widgets/channel_chart.dart';
import '../widgets/common.dart';

/// Recommendation for a band from the scan, leaving out the network we are connected to
/// (it is the one being moved, so it should not count against its own channel).
ChannelRecommendation? recommendFor(WifiBand band, List<AccessPoint> aps, {String ownBssid = ''}) {
  final loads = [
    for (final ap in aps)
      if (ap.band == band && (ownBssid.isEmpty || ap.bssid.toLowerCase() != ownBssid.toLowerCase())) ap.load,
  ];
  return switch (band) {
    WifiBand.ghz24 => recommendChannel(band, channels24Recommended, loads),
    WifiBand.ghz5 => recommendChannel(band, channels5, loads),
    WifiBand.ghz6 => null,
  };
}

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key, required this.controller});

  final WifiController controller;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  WifiBand _band = WifiBand.ghz24;
  bool _picked = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        // Start on the band of the connected network the first time.
        if (!_picked && c.connection.connected && c.connection.band != null) {
          _band = c.connection.band!;
          _picked = true;
        }
        final aps = (c.points.where((a) => a.band == _band).toList())..sort((a, b) => b.rssi.compareTo(a.rssi));
        final shown = aps.take(10).toList();
        final rec = recommendFor(_band, c.points, ownBssid: c.connection.connected ? c.connection.bssid : '');
        return ListView(
          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.xl),
          children: [
            ScanBar(controller: c),
            UiSegmentedControl<WifiBand>(
              [for (final b in WifiBand.values) UiSegment(b, label: b.label)],
              value: _band,
              expand: true,
              size: UiSize.sm,
              onChanged: (v) => setState(() {
                _band = v;
                _picked = true;
              }),
            ),
            const UiGap(UiSpace.md),
            UiCard(
              padding: const EdgeInsets.fromLTRB(UiSpace.sm, UiSpace.md, UiSpace.md, UiSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: UiSpace.sm),
                    child: Text('Signal (dBm) by channel', style: context.text.labelMedium),
                  ),
                  const UiGap(UiSpace.sm),
                  ChannelChart(band: _band, aps: shown),
                  const UiGap(UiSpace.sm),
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: UiSpace.sm),
                      child: Text('No ${_band.label} networks in range.', style: context.text.bodySmall),
                    )
                  else
                    UiChartLegend([
                      for (var i = 0; i < shown.length; i++)
                        UiLegendItem(shown[i].name, color: context.colors.chartColor(i), value: 'ch ${shown[i].channel ?? '?'}'),
                    ]),
                ],
              ),
            ),
            if (aps.length > shown.length)
              Padding(
                padding: const EdgeInsets.only(top: UiSpace.xs),
                child: Text('Showing the ${shown.length} strongest of ${aps.length}.', style: context.text.bodySmall),
              ),
            const UiGap(UiSpace.md),
            _Recommendation(band: _band, rec: rec, bandCount: aps.length),
          ],
        );
      },
    );
  }
}

class _Recommendation extends StatelessWidget {
  const _Recommendation({required this.band, required this.rec, required this.bandCount});

  final WifiBand band;
  final ChannelRecommendation? rec;
  final int bandCount;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final r = rec;
    if (r == null) {
      return const UiAlert(
        '6 GHz is new and mostly empty, so interference is rarely a problem. '
        'Leave your router on automatic channel selection.',
        title: '6 GHz',
        status: UiStatus.info,
      );
    }
    final best = r.best;
    final others = r.ranked.skip(1).take(band == WifiBand.ghz24 ? 2 : 3).toList();
    final free = best.networks == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UiIconBox(Icons.auto_awesome_rounded, status: free ? UiStatus.success : UiStatus.accent),
                  const UiGap(UiSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Best ${band.label} channel', style: text.bodySmall),
                        Text('Channel ${best.channel}', style: text.headlineSmall),
                      ],
                    ),
                  ),
                ],
              ),
              const UiGap(UiSpace.md),
              Text(
                free
                    ? 'No other network overlaps channel ${best.channel}. It is the clearest choice.'
                    : '${best.networks} other network${best.networks == 1 ? '' : 's'} overlap channel ${best.channel}, '
                        'the least interference of the options.',
                style: text.bodyMedium,
              ),
              if (band == WifiBand.ghz24)
                Padding(
                  padding: const EdgeInsets.only(top: UiSpace.xs),
                  child: Text(
                    'On 2.4 GHz only channels 1, 6 and 11 do not overlap each other, so those are the ones to use.',
                    style: text.bodySmall,
                  ),
                ),
              if (band == WifiBand.ghz5 && isDfs5(best.channel))
                Padding(
                  padding: const EdgeInsets.only(top: UiSpace.xs),
                  child: Text(
                    'Channels 52 to 144 share spectrum with weather radar (DFS). The router may pause for a minute '
                    'to check for radar, and some devices avoid them.',
                    style: text.bodySmall,
                  ),
                ),
              if (others.isNotEmpty) ...[
                const UiGap(UiSpace.md),
                const UiDivider(),
                const UiGap(UiSpace.sm),
                for (final o in others)
                  UiKeyValue('Channel ${o.channel}', '${o.networks} overlapping network${o.networks == 1 ? '' : 's'}'),
              ],
            ],
          ),
        ),
        const UiGap(UiSpace.md),
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to change the channel', style: text.titleMedium),
              const UiGap(UiSpace.sm),
              Text(
                '1. Join your Wi-Fi and open the router page, usually 192.168.0.1 or 192.168.1.1 '
                '(it is your gateway on the Connection tab).\n'
                '2. Sign in with the admin password printed on the router.\n'
                '3. Open Wireless or Wi-Fi settings and pick the ${band.label} band.\n'
                '4. Change Channel from Auto to ${best.channel}, and save. Keep the width at 20 MHz on 2.4 GHz.\n'
                '5. Reconnect and scan again to check the result.',
                style: text.bodyMedium,
              ),
              const UiGap(UiSpace.sm),
              Text(
                'The score uses the scan of other networks only. Your own router is ignored, '
                'and neighbours change over the day, so scan a few times.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
