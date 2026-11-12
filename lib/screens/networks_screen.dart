import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/models.dart';
import '../core/security.dart';
import '../core/wifi_math.dart';
import '../state/wifi_controller.dart';
import '../widgets/common.dart';

enum NetworkSort { signal, name, channel }

/// Filters and sorts a scan. Pure so it can be tested.
List<AccessPoint> filterAndSort(List<AccessPoint> all, {WifiBand? band, NetworkSort sort = NetworkSort.signal}) {
  final list = all.where((a) => band == null || a.band == band).toList();
  switch (sort) {
    case NetworkSort.signal:
      list.sort((a, b) => b.rssi.compareTo(a.rssi));
    case NetworkSort.name:
      list.sort((a, b) {
        if (a.hidden != b.hidden) return a.hidden ? 1 : -1;
        final c = a.ssid.toLowerCase().compareTo(b.ssid.toLowerCase());
        return c != 0 ? c : b.rssi.compareTo(a.rssi);
      });
    case NetworkSort.channel:
      list.sort((a, b) {
        final c = a.frequency.compareTo(b.frequency);
        return c != 0 ? c : b.rssi.compareTo(a.rssi);
      });
  }
  return list;
}

class NetworksScreen extends StatefulWidget {
  const NetworksScreen({super.key, required this.controller});

  final WifiController controller;

  @override
  State<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends State<NetworksScreen> {
  WifiBand? _band;
  NetworkSort _sort = NetworkSort.signal;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final list = filterAndSort(c.points, band: _band, sort: _sort);
        return ListView(
          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.sm, UiSpace.page, UiSpace.xl),
          children: [
            ScanBar(controller: c),
            UiSegmentedControl<WifiBand?>(
              const [
                UiSegment(null, label: 'All'),
                UiSegment(WifiBand.ghz24, label: '2.4'),
                UiSegment(WifiBand.ghz5, label: '5'),
                UiSegment(WifiBand.ghz6, label: '6 GHz'),
              ],
              value: _band,
              expand: true,
              size: UiSize.sm,
              onChanged: (v) => setState(() => _band = v),
            ),
            const UiGap(UiSpace.sm),
            UiSegmentedControl<NetworkSort>(
              const [
                UiSegment(NetworkSort.signal, label: 'Strongest'),
                UiSegment(NetworkSort.name, label: 'Name'),
                UiSegment(NetworkSort.channel, label: 'Channel'),
              ],
              value: _sort,
              expand: true,
              size: UiSize.sm,
              onChanged: (v) => setState(() => _sort = v),
            ),
            const UiGap(UiSpace.md),
            if (list.isEmpty)
              UiEmptyState(
                title: c.scanning ? 'Scanning...' : 'No networks found',
                message: c.points.isEmpty
                    ? 'Nothing in range yet. Pull a scan with the refresh button.'
                    : 'No networks on this band.',
                icon: Icons.wifi_find_rounded,
                compact: true,
              )
            else
              for (final ap in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: UiSpace.sm),
                  child: NetworkCard(ap: ap, connected: ap.bssid.toLowerCase() == c.connection.bssid.toLowerCase()),
                ),
          ],
        );
      },
    );
  }
}

class NetworkCard extends StatelessWidget {
  const NetworkCard({super.key, required this.ap, this.connected = false});

  final AccessPoint ap;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final band = ap.band;
    return UiCard(
      selected: connected,
      padding: const EdgeInsets.all(UiSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ap.name,
                  style: text.titleMedium?.copyWith(
                    fontStyle: ap.hidden ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (connected) const UiStatusPill('Connected', status: UiStatus.success),
              const UiGap(UiSpace.sm),
              Text('${ap.rssi} dBm', style: text.titleSmall?.copyWith(color: colors.tone(statusOfLevel(ap.level)).color)),
            ],
          ),
          const UiGap(UiSpace.xs),
          Text(ap.bssid, style: text.bodySmall),
          const UiGap(UiSpace.sm),
          SignalBar(rssi: ap.rssi),
          const UiGap(UiSpace.sm),
          Wrap(
            spacing: UiSpace.xs,
            runSpacing: UiSpace.xs,
            children: [
              UiTag(band?.label ?? '${ap.frequency} MHz', status: UiStatus.accent),
              UiTag(ap.channelLabel),
              UiTag(
                ap.security.label,
                status: ap.security.weak ? UiStatus.danger : UiStatus.success,
                icon: ap.security == Security.open ? Icons.lock_open_rounded : Icons.lock_rounded,
              ),
              if (ap.standard != null) UiTag(ap.standard!, status: UiStatus.info),
              UiTag(ap.level.label, status: statusOfLevel(ap.level)),
            ],
          ),
        ],
      ),
    );
  }
}
