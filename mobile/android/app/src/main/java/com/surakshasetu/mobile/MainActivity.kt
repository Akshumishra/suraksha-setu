package com.surakshasetu.mobile

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    private val channel = "com.surakshasetu.sos"
    private val tag = "MainActivity"
    private val comboWindowMs = 1_500L
    private val comboCooldownMs = 15_000L

    private var lastVolumeUpDownMs = 0L
    private var lastVolumeDownDownMs = 0L
    private var lastComboTriggerMs = 0L
    private var isVolumeUpPressed = false
    private var isVolumeDownPressed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "triggerSOS" -> {
                    try {
                        triggerSosFromNative(
                            source = "app_ui",
                            whileLocked = false,
                        )
                        result.success("SOS Triggered")
                    } catch (e: IllegalStateException) {
                        Log.e(tag, "Foreground service start denied by OS", e)
                        result.error("fgs_not_allowed", e.message, null)
                    } catch (e: SecurityException) {
                        Log.e(tag, "Missing permission to start foreground service", e)
                        result.error("permission_error", e.message, null)
                    } catch (e: Exception) {
                        Log.e(tag, "Failed to start SOS service", e)
                        result.error("trigger_failed", e.message, null)
                    }
                }

                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "isVolumeSosAccessibilityEnabled" -> {
                    result.success(isVolumeServiceEnabled())
                }

                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(tag, "Failed to open battery optimization settings", e)
                        result.error("battery_settings_error", e.message, null)
                    }
                }

                "openSystemGestureSettings" -> {
                    try {
                        val opened = openFirstAvailableSettings(
                            Intent("android.settings.SYSTEM_GESTURES_SETTINGS"),
                            Intent("android.settings.SYSTEM_NAVIGATION_SETTINGS"),
                            Intent("android.settings.BUTTON_SETTINGS"),
                            Intent(Settings.ACTION_SETTINGS),
                        )
                        if (opened) {
                            result.success(true)
                        } else {
                            result.error(
                                "gesture_settings_unavailable",
                                "No compatible settings screen found.",
                                null,
                            )
                        }
                    } catch (e: Exception) {
                        Log.e(tag, "Failed to open system gesture settings", e)
                        result.error("gesture_settings_error", e.message, null)
                    }
                }

                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        val isVolumeKey = keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (!isVolumeKey) {
            return super.onKeyDown(keyCode, event)
        }

        if (event.repeatCount > 0) {
            return super.onKeyDown(keyCode, event)
        }

        val now = SystemClock.elapsedRealtime()
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            isVolumeUpPressed = true
            lastVolumeUpDownMs = now
        } else {
            isVolumeDownPressed = true
            lastVolumeDownDownMs = now
        }

        val bothPressed = isVolumeUpPressed && isVolumeDownPressed
        val withinWindow =
            lastVolumeUpDownMs > 0L &&
                lastVolumeDownDownMs > 0L &&
                abs(lastVolumeUpDownMs - lastVolumeDownDownMs) <= comboWindowMs
        val cooldownPassed = now - lastComboTriggerMs >= comboCooldownMs

        if ((bothPressed || withinWindow) && cooldownPassed) {
            lastComboTriggerMs = now
            resetVolumeComboState()
            triggerSosFromNative(
                source = "volume_buttons_foreground",
                whileLocked = false,
            )
            return true
        }

        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            isVolumeUpPressed = false
        } else if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            isVolumeDownPressed = false
        }
        return super.onKeyUp(keyCode, event)
    }

    private fun resetVolumeComboState() {
        isVolumeUpPressed = false
        isVolumeDownPressed = false
        lastVolumeUpDownMs = 0L
        lastVolumeDownDownMs = 0L
    }

    private fun triggerSosFromNative(
        source: String,
        whileLocked: Boolean,
    ) {
        val intent = Intent(this, SosForegroundService::class.java).apply {
            action = SosForegroundService.ACTION_TRIGGER_SOS
            putExtra(SosForegroundService.EXTRA_TRIGGER_SOURCE, source)
            putExtra(SosForegroundService.EXTRA_TRIGGER_WHILE_LOCKED, whileLocked)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun isVolumeServiceEnabled(): Boolean {
        val expectedClassName = VolumeButtonService::class.java.name
        val accessibilityManager = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = accessibilityManager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_ALL_MASK
        )

        return enabledServices.any { serviceInfo ->
            val resolvedService = serviceInfo.resolveInfo?.serviceInfo ?: return@any false
            if (resolvedService.packageName != packageName) {
                return@any false
            }
            val resolvedClassName =
                if (resolvedService.name.startsWith(".")) {
                    resolvedService.packageName + resolvedService.name
                } else {
                    resolvedService.name
                }
            resolvedClassName == expectedClassName
        }
    }

    private fun openFirstAvailableSettings(vararg intents: Intent): Boolean {
        for (intent in intents) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }
        }
        return false
    }
}
