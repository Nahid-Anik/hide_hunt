package com.hidehunt.hide_hunt_flutter

import io.flutter.embedding.android.FlutterActivity
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hide_hunt/local_network")
            .setMethodCallHandler { call, result ->
                val connectivity = getSystemService(ConnectivityManager::class.java)
                try {
                    when (call.method) {
                        "useWifi" -> {
                            // A hotspot may have no internet. Keep game sockets on Wi-Fi
                            // even when Android prefers mobile data for internet traffic.
                            @Suppress("DEPRECATION")
                            val wifi = connectivity.allNetworks.firstOrNull { network ->
                                connectivity.getNetworkCapabilities(network)
                                    ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
                            }
                            result.success(wifi != null && connectivity.bindProcessToNetwork(wifi))
                        }
                        "keepAwake" -> {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            result.success(true)
                        }
                        "release" -> {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            result.success(connectivity.bindProcessToNetwork(null))
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: SecurityException) {
                    result.error("network_permission", "Could not access the Wi-Fi network.", null)
                }
            }
    }
}
