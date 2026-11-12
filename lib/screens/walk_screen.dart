import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../core/models.dart';
import '../state/wifi_controller.dart';
import '../widgets/common.dart';

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key, required this.controller});

  final WifiController controller;

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    final c = widget.controller;
    if (c.startWalk(_name.text)) _name.clear();
  }

  Future<void> _clear() async {
    final ok = await UiDialog.confirm(
      context,
      title: 'Clear all spots?',
      message: 'This removes every measured spot from this phone.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (ok) widget.controller.clearSpots();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final text = context.text;
        final colors = context.colors;
        final weak = c.spots.where((s) => s.verdict == SpotVerdict.weak).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(UiSpace.page, UiSpace.md, UiSpace.page, UiSpace.xl),
          children: [
            UiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Walk test', style: text.titleMedium),
                  const UiGap(UiSpace.xs),
                  Text(
                    'Stand in a room or spot, name it, and measure. Airscope averages the signal of '
                    '${c.connection.connected && c.connection.ssid.isNotEmpty ? c.connection.ssid : 'the connected network'} '
                    'for ${c.walkDuration.inSeconds} seconds. Hold the phone still. Repeat in each room to find dead zones.',
                    style: text.bodySmall,
                  ),
                  const UiGap(UiSpace.md),
                  if (c.walking) ...[
                    UiProgressBar(c.walkProgress, label: 'Measuring "${c.walkName}"', showPercent: true),
                    const UiGap(UiSpace.md),
                    UiButton('Cancel', variant: UiButtonVariant.outline, onPressed: c.cancelWalk),
                  ] else ...[
                    UiTextField(
                      label: 'Spot name',
                      hint: 'Kitchen, Bedroom, Balcony',
                      controller: _name,
                      prefixIcon: Icons.place_outlined,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _start(),
                    ),
                    const UiGap(UiSpace.md),
                    UiButton(
                      c.connection.connected ? 'Measure this spot' : 'Connect to Wi-Fi first',
                      icon: Icons.directions_walk_rounded,
                      expand: true,
                      onPressed: c.connection.connected ? _start : null,
                    ),
                    if (c.walkError != null) ...[
                      const UiGap(UiSpace.sm),
                      UiAlert(c.walkError!, status: UiStatus.warning),
                    ],
                  ],
                ],
              ),
            ),
            if (weak.isNotEmpty) ...[
              const UiGap(UiSpace.md),
              UiAlert(
                weak.map((s) => s.name).join(', '),
                title: weak.length == 1 ? 'Possible dead zone' : 'Possible dead zones',
                status: UiStatus.danger,
              ),
            ],
            const UiGap(UiSpace.lg),
            if (c.spots.isEmpty)
              const UiEmptyState(
                title: 'No spots yet',
                message: 'Measured spots appear here with a verdict.',
                icon: Icons.router_outlined,
                compact: true,
              )
            else ...[
              Row(
                children: [
                  Expanded(child: Text('Spots', style: text.titleMedium)),
                  UiButton('Clear', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: _clear),
                ],
              ),
              const UiGap(UiSpace.sm),
              if (c.spots.length >= 2) ...[
                UiCard(
                  child: UiBarChart(
                    bars: [
                      for (final s in c.spots.take(8))
                        UiBarData(s.name, s.avgRssi + 100, color: colors.tone(statusOfVerdict(s.verdict)).color),
                    ],
                    horizontal: true,
                    showLegend: false,
                    showGrid: false,
                    yFormat: (v) => '${(v - 100).round()}',
                  ),
                ),
                const UiGap(UiSpace.md),
              ],
              UiListGroup(
                footer: 'Good: -60 dBm or stronger. OK: -70 to -60 dBm. Weak: below -70 dBm.',
                children: [
                  for (final s in c.spots)
                    UiListTile(
                      s.name,
                      subtitle: '${s.avgRssi.round()} dBm average · ${s.minRssi} to ${s.maxRssi} · '
                          '${s.samples} samples${s.ssid.isEmpty ? '' : ' · ${s.ssid}'}',
                      leading: UiStatusPill(s.verdict.label, status: statusOfVerdict(s.verdict)),
                      trailing: UiIconButton(
                        Icons.delete_outline_rounded,
                        tooltip: 'Delete',
                        onPressed: () => c.deleteSpot(s),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
