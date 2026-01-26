package com.aidx.health.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.example.wearos/data"
        @JvmStatic
        var methodChannel: MethodChannel? = null

        @JvmStatic
        fun sendWearData(jsonPayload: String) {
            try {
                methodChannel?.invokeMethod("liveVitals", jsonPayload)
            } catch (_: Throwable) {
                // No-op if engine/channel not ready
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
    }
} 