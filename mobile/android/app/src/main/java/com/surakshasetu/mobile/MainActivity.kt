package com.surakshasetu.mobile

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.surakshasetu.sos"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "triggerSOS" -> {
                    val intent = Intent(this, SosForegroundService::class.java)
                    intent.action = SosForegroundService.ACTION_TRIGGER_SOS
                    startForegroundService(intent)
                    result.success("SOS Triggered")
                }
                else -> result.notImplemented()
            }
        }
    }
}
