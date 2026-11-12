package com.itsash.airscope

import android.content.Intent
import android.location.LocationManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Wires the Dart side to WifiManager.
 *
 * Channels (names match `lib/platform/wifi_channel.dart`):
 * - `com.itsash.airscope/wifi` (method): `isWifiEnabled`, `isLocationEnabled`, `startScan`,
 *   `scanResults`, `openLocationSettings`, `openWifiSettings`, `keepScreenOn`.
 * - `com.itsash.airscope/scan` (events): `{success, results}` after each scan finishes.
 * - `com.itsash.airscope/connection` (events): the connected network, about once a second.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val wifi = WifiReader(applicationContext)

        MethodChannel(messenger, "$CHANNEL/wifi").setMethodCallHandler { call, result ->
            when (call.method) {
                "isWifiEnabled" -> result.success(wifi.wifiManager.isWifiEnabled)
                "isLocationEnabled" -> result.success(isLocationEnabled())
                "startScan" -> result.success(wifi.startScan())
                "scanResults" -> result.success(wifi.scanResults())
                "openLocationSettings" -> {
                    startActivity(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS))
                    result.success(null)
                }
                "openWifiSettings" -> {
                    startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                    result.success(null)
                }
                "keepScreenOn" -> {
                    if (call.arguments as? Boolean == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "$CHANNEL/scan")
            .setStreamHandler(ScanStreamHandler(applicationContext, wifi))
        EventChannel(messenger, "$CHANNEL/connection")
            .setStreamHandler(ConnectionStreamHandler(wifi))
    }

    private fun isLocationEnabled(): Boolean {
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        return lm.isLocationEnabled
    }

    private companion object {
        const val CHANNEL = "com.itsash.airscope"
    }
}
