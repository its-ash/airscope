# Airscope

Wi-Fi analyzer: nearby networks, channel graphs, live signal and a dead-zone walk test.

**[Website](https://airscope.itsash.in)** · **[Download APK](https://github.com/its-ash/airscope/releases/latest/download/airscope.apk)** · Get it in **[Ash Store](https://store.itsash.in)**

## Features

- **Networks**: every access point in range with name (hidden ones marked), BSSID, band (2.4, 5, 6 GHz), channel and width, signal strength with a quality bar, security (Open, WEP, WPA, WPA2, WPA3) and Wi-Fi generation (Wi-Fi 4, 5, 6, 6E, 7). Filter by band, sort by signal, name or channel.
- **Channels**: a graph per band where each network is a curve over the channels it occupies, a best-channel recommendation for 2.4 GHz (1, 6, 11) and 5 GHz, and plain steps to change it on your router.
- **Connection**: live signal of the network you are on, updated every second, with link speed, frequency, channel, IP, gateway and a signal history graph.
- **Walk test**: name a room, hold still for 8 seconds, and get a Good, OK or Weak verdict. Compare spots to find dead zones.
- Respects Android's limit of 4 scans per 2 minutes: shows when the last scan ran and uses cached results in between.
- No ads, no tracking. Nothing leaves your phone, except the update check.

## Install

- **Ash Store**: install [Ash Store](https://store.itsash.in) once, then install and update Airscope from it.
- **APK**: download the [latest APK](https://github.com/its-ash/airscope/releases/latest/download/airscope.apk) on your phone and open it. Allow your browser to install unknown apps if Android asks.

Requires Android 8.0 (API 26) or newer. Android needs the Location permission (and Location switched on) to give any app Wi-Fi scan results. Airscope does not read or store your location.

## Develop

Needs Flutter ≥ 3.44 and the shared theme package at `../theme`.

```bash
make run      # run on a connected device
make build    # release APK
make test     # flutter analyze + flutter test
make deploy   # bump version, build, tag, push, GitHub release (see store.mk)
```

## Release

`make deploy` follows the Ash Store kit (`store.mk`, `store.json`): it bumps the
version in `pubspec.yaml`, builds, commits, tags `vX.Y.Z`, pushes, and publishes
a GitHub release with `airscope.apk`. Ash Store and the website pick up the new
version from that release.

## Project layout

```
lib/
├── main.dart                     # UiApp + HomeScreen
├── core/                         # pure, unit-tested
│   ├── wifi_math.dart            # frequency/channel math, overlap scoring, best channel
│   ├── security.dart             # capabilities string -> Open/WPA2/WPA3...
│   ├── scan_throttle.dart        # 4 scans per 2 minutes budget
│   └── models.dart               # AccessPoint, ConnectionInfo, WalkSpot
├── platform/                     # WifiSource interface, MethodChannel/EventChannel + permissions
├── state/wifi_controller.dart    # access state, scans, live connection, walk test
├── widgets/                      # channel graph painter, scan bar, signal bar
└── screens/                      # home (UiShell), networks, channels, connection, walk, settings
android/app/src/main/kotlin/com/itsash/airscope/
├── MainActivity.kt               # channels, location/Wi-Fi state, settings intents
└── WifiStreams.kt                # WifiManager reads, scan broadcast, 1 Hz connection poll
```

## License

No license file is included yet.

Built by [itsash.in](https://itsash.in).
