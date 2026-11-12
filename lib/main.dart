import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theme/theme.dart';

import 'platform/wifi_channel.dart';
import 'screens/home_screen.dart';
import 'state/wifi_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final controller = WifiController(const WifiChannel(), prefs: prefs);
  await controller.init();
  runApp(AirscopeApp(controller: controller));
}

class AirscopeApp extends StatelessWidget {
  const AirscopeApp({super.key, required this.controller});

  final WifiController controller;

  @override
  Widget build(BuildContext context) {
    return UiApp(
      title: 'Airscope',
      home: HomeScreen(controller: controller),
    );
  }
}
