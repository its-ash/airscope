import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/wifi_math.dart';
import '../state/wifi_controller.dart';
import '../widgets/common.dart';

String _speed(int mbps) => mbps > 0 ? '$mbps Mbps' : 'Not reported';

class ConnectionScreen extends StatelessWidget {
  const ConnectionScreen({super.key, required this.controller});

  final WifiController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final conn = controller.connection;
        if (!conn.connected) {
          return const UiEmptyState(
            title: 'Not connected to Wi-Fi',
            message: 'Join a Wi-Fi network to see its live signal, speed and addresses here.',
            icon: Icons.wifi_off_rounded,
          );
        }
        final level = signalLevelOf(conn.rssi);
        final status = statusOfLevel(level);
        final text = context.text;
        final band = conn.band;
        final history = controller.history;
        return ListView(
          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.md, UiSpace.page, UiSpace.xl),
          children: [
            UiCard(
              child: Column(
                children: [
                  Text(conn.ssid.isEmpty ? 'Connected network' : conn.ssid, style: text.titleLarge),
                  const UiGap(UiSpace.md),
                  UiGauge(
                    value: qualityOf(conn.rssi),
                    status: status,
                    size: 220,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${conn.rssi}', style: text.displaySmall),
                        Text('dBm · ${level.label}', style: text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const UiGap(UiSpace.md),
            UiCard(
              child: Column(
                children: [
                  UiKeyValue('Band', band?.label ?? '${conn.frequency} MHz'),
                  UiKeyValue('Channel', conn.channel == null ? 'Unknown' : '${conn.channel} (${conn.frequency} MHz)'),
                  UiKeyValue('Link speed', _speed(conn.linkSpeed)),
                  UiKeyValue('Download link (rx)', _speed(conn.rxSpeed)),
                  UiKeyValue('Upload link (tx)', _speed(conn.txSpeed)),
                  UiKeyValue('IP address', conn.ip.isEmpty ? 'Unknown' : conn.ip, copyable: conn.ip.isNotEmpty),
                  UiKeyValue('Gateway', conn.gateway.isEmpty ? 'Unknown' : conn.gateway, copyable: conn.gateway.isNotEmpty),
                  UiKeyValue('BSSID', conn.bssid.isEmpty ? 'Unknown' : conn.bssid, copyable: conn.bssid.isNotEmpty),
                ],
              ),
            ),
            const UiGap(UiSpace.md),
            UiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signal history', style: text.titleMedium),
                  Text('Last ${history.length} s', style: text.bodySmall),
                  const UiGap(UiSpace.md),
                  if (history.length < 2)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: UiSpace.lg),
                      child: Center(child: UiSpinner()),
                    )
                  else
                    UiLineChart(
                      series: [UiChartSeries('Signal (dBm)', List.of(history))],
                      height: 160,
                      curved: false,
                      showLegend: false,
                      yFormat: (v) => '${v.round()}',
                    ),
                ],
              ),
            ),
            const UiGap(UiSpace.sm),
            Text(
              'Link speed is the rate the radio negotiated with the router, not an internet speed test.',
              style: text.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
