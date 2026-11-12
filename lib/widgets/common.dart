import 'dart:async';

import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/models.dart';
import '../core/wifi_math.dart';
import '../state/wifi_controller.dart';

UiStatus statusOfLevel(SignalLevel level) => switch (level) {
      SignalLevel.excellent || SignalLevel.good => UiStatus.success,
      SignalLevel.fair => UiStatus.warning,
      SignalLevel.weak => UiStatus.danger,
    };

UiStatus statusOfVerdict(SpotVerdict v) => switch (v) {
      SpotVerdict.good => UiStatus.success,
      SpotVerdict.ok => UiStatus.warning,
      SpotVerdict.weak => UiStatus.danger,
    };

/// "12 s ago", "3 min ago".
String agoText(int seconds) {
  if (seconds < 60) return '$seconds s ago';
  return '${seconds ~/ 60} min ago';
}

/// Signal-strength bar colored by level.
class SignalBar extends StatelessWidget {
  const SignalBar({super.key, required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    return UiProgressBar(qualityOf(rssi), status: statusOfLevel(signalLevelOf(rssi)), height: 6);
  }
}

/// "Last scan 12 s ago", the refresh button and why a scan was held back.
class ScanBar extends StatefulWidget {
  const ScanBar({super.key, required this.controller});

  final WifiController controller;

  @override
  State<ScanBar> createState() => _ScanBarState();
}

class _ScanBarState extends State<ScanBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final secs = c.secondsSinceScan;
    final wait = c.throttleWait;
    final stillWaiting = wait != null && c.throttle.waitTime(DateTime.now()) != null;
    final label = c.scanning
        ? 'Scanning...'
        : secs == null
            ? 'No scan yet'
            : 'Last scan ${agoText(secs)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$label · ${c.points.length} networks',
                style: context.text.bodySmall,
              ),
            ),
            if (c.scanning)
              const SizedBox(width: 20, height: 20, child: UiSpinner())
            else
              UiIconButton(
                Icons.refresh_rounded,
                tooltip: 'Scan again',
                onPressed: c.scan,
              ),
          ],
        ),
        if (stillWaiting)
          Padding(
            padding: const EdgeInsets.only(bottom: UiSpace.sm),
            child: UiAlert(
              'Android allows 4 Wi-Fi scans every 2 minutes. The next scan can start in '
              '${c.throttle.waitTime(DateTime.now())!.inSeconds + 1} s. The list below is from the last scan.',
              status: UiStatus.info,
            ),
          )
        else if (c.systemRefused)
          Padding(
            padding: const EdgeInsets.only(bottom: UiSpace.sm),
            child: UiAlert(
              'Android did not run the scan (it limits apps, or scan throttling is on in Developer options). '
              'Showing the last results.',
              status: UiStatus.warning,
            ),
          ),
      ],
    );
  }
}
