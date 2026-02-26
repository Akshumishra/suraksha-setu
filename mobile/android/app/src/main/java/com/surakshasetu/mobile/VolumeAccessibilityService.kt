package com.surakshasetu.mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class VolumeAccessibilityService : AccessibilityService() {

    private val TAG = "VolumeAccessibilitySvc"
    private val COMBO_WINDOW_MS = 1500L
    private val COOLDOWN_MS = 15_000L

    private var lastVolUpTime = 0L
    private var lastVolDownTime = 0L
    private var lastTriggerTime = 0L
    private var isVolUpPressed = false
    private var isVolDownPressed = false

    override fun onServiceConnected() {
        super.onServiceConnected()

        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        serviceInfo = info

        Log.i(TAG, "Accessibility Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val isVolumeKey = event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        if (!isVolumeKey) {
            return super.onKeyEvent(event)
        }

        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                val now = SystemClock.elapsedRealtime()
                if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                    isVolUpPressed = true
                    if (event.repeatCount == 0) {
                        lastVolUpTime = now
                    }
                } else {
                    isVolDownPressed = true
                    if (event.repeatCount == 0) {
                        lastVolDownTime = now
                    }
                }

                val hasBothDown = isVolUpPressed && isVolDownPressed
                val hasBothTimes = lastVolUpTime != 0L && lastVolDownTime != 0L
                val diff = if (hasBothTimes) kotlin.math.abs(lastVolUpTime - lastVolDownTime) else Long.MAX_VALUE
                val comboDetected = hasBothDown || (hasBothTimes && diff <= COMBO_WINDOW_MS)

                if (comboDetected) {
                    Log.i(TAG, "Volume Up + Down combo detected")
                    triggerSOS()
                    lastVolUpTime = 0L
                    lastVolDownTime = 0L
                    return true
                }
            }
            KeyEvent.ACTION_UP -> {
                if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                    isVolUpPressed = false
                } else {
                    isVolDownPressed = false
                }
            }
        }

        return super.onKeyEvent(event)
    }

    private fun triggerSOS() {
        val now = SystemClock.elapsedRealtime()
        if (now - lastTriggerTime < COOLDOWN_MS) {
            Log.i(TAG, "Ignoring trigger during cooldown")
            return
        }
        lastTriggerTime = now

        try {
            val intent = Intent(this, SosForegroundService::class.java)
            intent.action = SosForegroundService.ACTION_TRIGGER_SOS
            startForegroundService(intent)
            Log.i(TAG, "Requested SOS foreground service start")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to startForegroundService for SOS: $e")
            try {
                val fallbackIntent = Intent(this, SosForegroundService::class.java).apply {
                    action = SosForegroundService.ACTION_TRIGGER_SOS
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(fallbackIntent)
                } else {
                    startService(fallbackIntent)
                }
                Log.i(TAG, "Fallback SOS service start requested")
            } catch (fallbackError: Exception) {
                Log.e(TAG, "Fallback SOS service start failed: $fallbackError")
            }
        }
    }
}
