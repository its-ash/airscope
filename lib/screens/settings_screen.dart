import 'package:flutter/material.dart';
import 'package:theme/theme.dart';

import '../state/wifi_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final WifiController controller;

  @override
  Widget build(BuildContext context) {
    return UiScaffold(
      appBar: const UiAppBar(title: 'Settings'),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiListGroup(
            header: 'Permissions',
            footer: 'Android hides Wi-Fi scan results and network names from apps that have no location '
                'permission. Airscope never reads, stores or sends your location.',
            children: [
              UiListTile(
                'App permissions',
                icon: Icons.location_on_outlined,
                subtitle: 'Location and Nearby devices',
                chevron: true,
                onTap: controller.source.openAppSettings,
              ),
              UiListTile(
                'Location services',
                icon: Icons.gps_fixed_rounded,
                subtitle: 'Must be on for scan results',
                chevron: true,
                onTap: controller.source.openLocationSettings,
              ),
            ],
          ),
          const UiGap(UiSpace.lg),
          const UiListGroup(
            header: 'Privacy',
            children: [
              UiListTile(
                'Everything stays on this phone',
                subtitle: 'Scan results and walk-test spots are never sent anywhere. '
                    'Airscope uses the internet only to check for app updates.',
                maxSubtitleLines: 4,
                icon: Icons.lock_rounded,
                iconStatus: UiStatus.success,
              ),
            ],
          ),
          const UiGap(UiSpace.lg),
          const UiAppearanceSection(),
          const UiGap(UiSpace.lg),
          const UiUpdateSection(storeId: 'airscope'),
          const UiGap(UiSpace.lg),
          const UiDeveloperSection(),
        ],
      ),
    );
  }
}
