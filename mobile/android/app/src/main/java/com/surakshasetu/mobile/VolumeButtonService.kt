package com.surakshasetu.mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import kotlin.math.abs

/**
 * Accessibility-based fallback for Volume Up + Volume Down SOS triggering.
 *
 * Limitations:
 * 1) Android does not guarantee global hardware-key delivery to third-party apps. Key events can be
 *    blocked by OEM firmware, system gestures, gaming modes, or lock-screen policies.
 * 2) In background, this path depends on AccessibilityService stability. Some OEMs aggressively stop
 *    accessibility/background components, so foreground Activity handling remains the most reliable path.
 */
class VolumeButtonService : AccessibilityService() {

    private val tag = "VolumeButtonService"
    private val comboWindowMs = 1_500L
    private val cooldownMs = 15_000L

    private var lastVolumeUpDownMs = 0L
    private var lastVolumeDownDownMs = 0L
    private var lastTriggerMs = 0L
    private var isVolumeUpPressed = false
    private var isVolumeDownPressed = false

    private lateinit var keyguardManager: KeyguardManager
    private lateinit var powerManager: PowerManager

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        }
        serviceInfo = info

        keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        Log.i(tag, "Accessibility volume service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}

    override fun onInterrupt() {}

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) {
            return false
        }
        val isVolumeKey =
            event.keyCode == KeyEvent.KEYCODE_VOLUME_UP || event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (!isVolumeKey) {
            return super.onKeyEvent(event)
        }

        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                if (event.repeatCount > 0) {
                    return super.onKeyEvent(event)
                }

                val now = SystemClock.elapsedRealtime()
                if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
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

                if (bothPressed || withinWindow) {
                    if (now - lastTriggerMs < cooldownMs) {
                        Log.i(tag, "Volume combo ignored during cooldown")
                        return true
                    }
                    lastTriggerMs = now
                    resetVolumeState()
                    triggerSos()
                    return true
                }
            }

            KeyEvent.ACTION_UP -> {
                if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                    isVolumeUpPressed = false
                } else {
                    isVolumeDownPressed = false
                }
            }
        }

        return super.onKeyEvent(event)
    }

    private fun resetVolumeState() {
        isVolumeUpPressed = false
        isVolumeDownPressed = false
        lastVolumeUpDownMs = 0L
        lastVolumeDownDownMs = 0L
    }

    private fun triggerSos() {
        val whileLocked = isScreenOffOrLocked()
        val intent = Intent(this, SosForegroundService::class.java).apply {
            action = SosForegroundService.ACTION_TRIGGER_SOS
            putExtra(SosForegroundService.EXTRA_TRIGGER_SOURCE, "volume_buttons_accessibility")
            putExtra(SosForegroundService.EXTRA_TRIGGER_WHILE_LOCKED, whileLocked)
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.i(tag, "SOS foreground service start requested from accessibility trigger")
        } catch (securityException: SecurityException) {
            Log.e(tag, "Missing permission to start SOS foreground service", securityException)
        } catch (illegalStateException: IllegalStateException) {
            Log.e(tag, "OS denied foreground service start from accessibility trigger", illegalStateException)
        } catch (e: Exception) {
            Log.e(tag, "Unexpected error while starting SOS service", e)
        }
    }

    private fun isScreenOffOrLocked(): Boolean {
        val screenOff = try {
            !powerManager.isInteractive
        } catch (_: Exception) {
            false
        }
        val keyguardLocked = try {
            keyguardManager.isKeyguardLocked
        } catch (_: Exception) {
            false
        }
        return screenOff || keyguardLocked
    }
}
