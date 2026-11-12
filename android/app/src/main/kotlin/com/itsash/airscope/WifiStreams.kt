@file:Suppress("DEPRECATION")

package com.itsash.airscope

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.ScanResult
import android.net.wifi.SupplicantState
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/** Reads scan results and the connection from [WifiManager]. Never throws on missing permission. */
class WifiReader(context: Context) {
    val wifiManager: WifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    fun startScan(): Boolean = try {
        wifiManager.startScan()
    } catch (_: SecurityException) {
        false
    }

    fun scanResults(): List<Map<String, Any?>> {
        val results = try {
            wifiManager.scanResults
        } catch (_: SecurityException) {
            emptyList()
        }
        val nowMs = SystemClock.elapsedRealtime()
        return results.map { it.toMap(nowMs) }
    }

    private fun ScanResult.toMap(nowMs: Long): Map<String, Any?> {
        val ssidText = if (Build.VERSION.SDK_INT >= 33) {
            wifiSsid?.toString()?.trim('"') ?: ""
        } else {
            SSID ?: ""
        }
        return mapOf(
            "ssid" to ssidText,
            "bssid" to BSSID,
            "rssi" to level,
            "frequency" to frequency,
            "channelWidth" to channelWidth,
            "centerFreq0" to centerFreq0,
            "centerFreq1" to centerFreq1,
            "capabilities" to capabilities,
            "standard" to if (Build.VERSION.SDK_INT >= 30) wifiStandard else null,
            "ageMs" to (nowMs - timestamp / 1000),
        )
    }

    fun connection(): Map<String, Any?> {
        val info = try {
            wifiManager.connectionInfo
        } catch (_: SecurityException) {
            null
        }
        val connected = info != null && info.networkId != -1 &&
            info.supplicantState == SupplicantState.COMPLETED && info.rssi > -127
        if (!connected || info == null) return mapOf("connected" to false)

        val dhcp = wifiManager.dhcpInfo
        return mapOf(
            "connected" to true,
            "ssid" to (info.ssid ?: "").trim('"').takeIf { it != "<unknown ssid>" }.orEmpty(),
            "bssid" to (info.bssid ?: ""),
            "rssi" to info.rssi,
            "linkSpeed" to info.linkSpeed,
            "txSpeed" to if (Build.VERSION.SDK_INT >= 29) info.txLinkSpeedMbps else -1,
            "rxSpeed" to if (Build.VERSION.SDK_INT >= 29) info.rxLinkSpeedMbps else -1,
            "frequency" to info.frequency,
            "ip" to ipString(info.ipAddress),
            "gateway" to ipString(dhcp?.gateway ?: 0),
        )
    }

    private fun ipString(v: Int): String =
        if (v == 0) "" else "${v and 0xff}.${v shr 8 and 0xff}.${v shr 16 and 0xff}.${v shr 24 and 0xff}"
}

/** Emits `{success, results}` whenever a scan finishes (ours or the system's). */
class ScanStreamHandler(private val context: Context, private val wifi: WifiReader) :
    EventChannel.StreamHandler {
    private var receiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                events.success(
                    mapOf(
                        "success" to intent.getBooleanExtra(WifiManager.EXTRA_RESULTS_UPDATED, true),
                        "results" to wifi.scanResults(),
                    ),
                )
            }
        }
        receiver = r
        val filter = IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION)
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(r, filter, Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(r, filter)
        }
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let { context.unregisterReceiver(it) }
        receiver = null
    }
}

/** Polls the connected network once a second while Dart listens. */
class ConnectionStreamHandler(private val wifi: WifiReader) : EventChannel.StreamHandler {
    private val handler = Handler(Looper.getMainLooper())
    private var tick: Runnable? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val r = object : Runnable {
            override fun run() {
                events.success(wifi.connection())
                handler.postDelayed(this, 1000)
            }
        }
        tick = r
        r.run()
    }

    override fun onCancel(arguments: Any?) {
        tick?.let { handler.removeCallbacks(it) }
        tick = null
    }
}
