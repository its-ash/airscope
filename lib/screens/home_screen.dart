import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../platform/wifi_source.dart';
import '../state/wifi_controller.dart';
import 'channels_screen.dart';
import 'connection_screen.dart';
import 'networks_screen.dart';
import 'settings_screen.dart';
import 'walk_screen.dart';

/// Four tabs in a bottom navigation shell. Until Android grants what Wi-Fi scanning
/// needs (permission, location services on, Wi-Fi on), the tabs are replaced by a gate.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final WifiController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _items = [
    UiNavItem(Icons.wifi_rounded, 'Networks'),
    UiNavItem(Icons.bar_chart_rounded, 'Channels'),
    UiNavItem(Icons.speed_rounded, 'Connection'),
    UiNavItem(Icons.directions_walk_rounded, 'Walk test'),
  ];

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.source.keepScreenOn(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.source.keepScreenOn(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final ready = c.access == Access.ready;
        return UiShell(
          items: _items,
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
          appBar: UiAppBar(
            title: ready ? _items[_tab].label : 'Airscope',
            actions: [
              UiIconButton(
                Icons.settings_rounded,
                tooltip: 'Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => SettingsScreen(controller: c)),
                ),
              ),
            ],
          ),
          body: ready
              ? IndexedStack(
                  index: _tab,
                  children: [
                    NetworksScreen(controller: c),
                    ChannelsScreen(controller: c),
                    ConnectionScreen(controller: c),
                    WalkScreen(controller: c),
                  ],
                )
              : _AccessGate(controller: c),
        );
      },
    );
  }
}

class _AccessGate extends StatelessWidget {
  const _AccessGate({required this.controller});

  final WifiController controller;

  @override
  Widget build(BuildContext context) {
    final source = controller.source;
    switch (controller.access) {
      case Access.checking:
        return const Center(child: UiSpinner());
      case Access.needPermission:
        return UiEmptyState(
          title: 'Allow location to scan Wi-Fi',
          message: 'Android only shows nearby Wi-Fi networks, and the name of your own, to apps with '
              'the location permission. Airscope does not read, store or send your location.',
          icon: Icons.location_on_outlined,
          action: UiButton('Allow', icon: Icons.check_rounded, onPressed: controller.requestAccess),
        );
      case Access.permissionBlocked:
        return UiEmptyState(
          title: 'Location permission is blocked',
          message: 'Open the app settings, choose Permissions, and allow Location and Nearby devices.',
          icon: Icons.location_disabled_rounded,
          action: UiButton('Open app settings', icon: Icons.settings_rounded, onPressed: source.openAppSettings),
        );
      case Access.locationOff:
        return UiEmptyState(
          title: 'Turn on Location',
          message: 'Android hides Wi-Fi scan results while Location is switched off. '
              'Turn it on, then come back.',
          icon: Icons.location_off_outlined,
          action: UiButton('Open location settings', icon: Icons.settings_rounded, onPressed: source.openLocationSettings),
        );
      case Access.wifiOff:
        return UiEmptyState(
          title: 'Wi-Fi is off',
          message: 'Turn Wi-Fi on to scan for networks.',
          icon: Icons.wifi_off_rounded,
          action: UiButton('Open Wi-Fi settings', icon: Icons.settings_rounded, onPressed: source.openWifiSettings),
        );
      case Access.ready:
        return const SizedBox.shrink();
    }
  }
}
