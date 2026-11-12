# Airscope (package: airscope / com.itsash.airscope)

Wi-Fi analyzer for Android. `UiShell` bottom navigation with four tabs: Networks
(scan list, band filter, sorting), Channels (per-band channel graph, best-channel
recommendation, router steps), Connection (live RSSI gauge, link speed, IP,
gateway, signal history), Walk test (named spots, 8 s average RSSI, Good/OK/Weak).
Until permission, Location services and Wi-Fi are all on, `HomeScreen` shows an
access gate instead of the tabs.

## Code layout

- `lib/core/`: pure Dart, all unit tested (`test/wifi_math_test.dart`). Add a test
  for every change.
  - `wifi_math.dart`: `bandOf`, `channelOf`, `centerFreqOf`, `widthMhzOf`
    (ScanResult width codes), `qualityOf`, `signalLevelOf`, `wifiStandardName`,
    `occupiedRange` (a 20 MHz 2.4 GHz AP occupies 22 MHz), `congestionScore`
    (overlap share x squared signal weight), `recommendChannel` (candidates 1/6/11
    on 2.4 GHz, `channels5` on 5 GHz; ties go to non-DFS, then lower channel),
    `parabola` (graph curve).
  - `security.dart`: `parseSecurity(capabilities)`.
  - `scan_throttle.dart`: `ScanThrottle`, 4 scans per 2 minutes.
  - `models.dart`: `AccessPoint`, `ConnectionInfo`, `WalkSpot` (JSON), `verdictOf`
    (>= -60 good, >= -70 ok, else weak).
- `lib/platform/`: `WifiSource` (interface, faked in tests), `WifiChannel`
  (real one: `com.itsash.airscope/wifi` method channel, `/scan` and `/connection`
  event channels, permission_handler for Location and Nearby devices).
- `lib/state/wifi_controller.dart`: `ChangeNotifier`; access state machine, scan
  throttling (own `ScanThrottle` plus the system's refusal), auto scan every 40 s
  while foreground (keeps one scan of budget for the button), 1 Hz connection
  history, walk test, spots saved in `shared_preferences`.
- `lib/widgets/`: `ChannelChart` (CustomPainter, the theme has no
  frequency-axis chart; colors from `context.colors`), `ScanBar`, `SignalBar`.
  Signal history uses `UiLineChart`, walk comparison `UiBarChart`.
- `lib/screens/`: `home_screen`, `networks_screen`, `channels_screen`,
  `connection_screen`, `walk_screen`, `settings_screen` (ends with
  `UiAppearanceSection`, `UiUpdateSection(storeId: 'airscope')`,
  `UiDeveloperSection()`).
- `android/app/src/main/kotlin/com/itsash/airscope/`: `MainActivity.kt`,
  `WifiStreams.kt` (`WifiReader`, scan broadcast receiver, 1 s connection poll;
  `WifiManager.connectionInfo` is deprecated but still the simplest source).

## Commands

- `make run`, `make build` (release APK), `make test` (`flutter analyze` +
  `flutter test`), `make clean`.
- Icon: SVG sources in `assets/icon/` (`logo`, `logo_foreground`,
  `logo_background`; 16x16 grid, cell 64) -> `rsvg-convert -w 1024 -h 1024` to
  `*-1024.png`, then `dart run flutter_launcher_icons`.

## Conventions

- minSdk 26. UI only from the shared `theme` package (`../theme`, read
  `../theme/COMPONENTS.md`); no hardcoded colors.
- Permissions: `ACCESS_FINE_LOCATION`/`COARSE` (Android requires it for scan
  results and SSID), `NEARBY_WIFI_DEVICES` (`neverForLocation`, Android 13+),
  `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `ACCESS_NETWORK_STATE`, `INTERNET`
  (update check only). Location is never read, stored or sent.
- Android limits foreground apps to 4 scans per 2 minutes: never call
  `startScan` outside `WifiController.scan`.

## Release (Ash Store)

- `store.json` (id `airscope`, repo its-ash/airscope), `store.mk`,
  `index.html` + `CNAME` (`airscope.itsash.in`). See
  `../ash-store/store-kit/STORE.md`.
- `make deploy` = bump version -> build -> commit, tag `vX.Y.Z`, push -> GitHub
  release with `airscope.apk` -> topics, homepage, Pages. Never create releases,
  tags or asset names by hand.
- Do not edit `store.mk` here. Edit `../ash-store/store-kit/store.mk`, then run
  `make store-sync` at the workspace root.
