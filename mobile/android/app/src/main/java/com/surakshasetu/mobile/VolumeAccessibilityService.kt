package com.surakshasetu.mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

/**
 * Accessibility service that listens for hardware key events (volume up + volume down).
 * When both are pressed within a short window, it triggers the SOS Foreground Service.
 *
 * IMPORTANT:
 * - User must enable this service under Settings -> Accessibility.
 * - accessibility_service_config.xml must allow filterKeyEvents.
 */
class VolumeAccessibilityService : AccessibilityService() {
    private val TAG = "VolumeAccessibilitySvc"

    // Timestamp of last volume up/down press
    private var lastVolUpTs = 0L
    private var lastVolDownTs = 0L

    // threshold to treat two presses as "simultaneous" (ms)
    private val SIMULTANEOUS_THRESHOLD = 800L

    // Anti-spam cooldown (ms)
    private val COOLDOWN_MS = 10_000L
    private var lastTriggerTs = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.i(TAG, "Accessibility Service connected")
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPES_ALL_MASK
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags =
            AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // no-op
    }

    override fun onInterrupt() {
        // no-op
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        // We only react to KEY_DOWN to avoid duplicates
        if (event.action != KeyEvent.ACTION_DOWN) return super.onKeyEvent(event)

        val now = System.currentTimeMillis()

        when (event.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                lastVolUpTs = now
                checkSimultaneousTrigger(now)
                return true // consumed
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                lastVolDownTs = now
                checkSimultaneousTrigger(now)
                return true
            }
            else -> return super.onKeyEvent(event)
        }
    }

    private fun checkSimultaneousTrigger(now: Long) {
        if (now - lastTriggerTs < COOLDOWN_MS) {
            Log.d(TAG, "Cooldown active, ignore")
            return
        }
        val diff = kotlin.math.abs(lastVolUpTs - lastVolDownTs)
        if (diff <= SIMULTANEOUS_THRESHOLD && lastVolUpTs != 0L && lastVolDownTs != 0L) {
            lastTriggerTs = now
            Log.i(TAG, "Volume combo detected, starting SOS service")
            startSosService()
            // reset
            lastVolUpTs = 0L
            lastVolDownTs = 0L
        }
    }

    private fun startSosService() {
        try {
            val intent = Intent(this, SosForegroundService::class.java)
            intent.action = SosForegroundService.ACTION_TRIGGER_SOS
            // Use startForegroundService to survive background restrictions
            startForegroundService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start SOS service: $e")
        }
    }
}
