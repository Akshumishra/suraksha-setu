package com.surakshasetu.mobile

import android.accessibilityservice.AccessibilityService
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.util.Log

class VolumeButtonService : AccessibilityService() {

    private var lastVolumeUpTime = 0L
    private var lastVolumeDownTime = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Required override — but not used in this service
    }

    override fun onInterrupt() {
        // Required override — not used
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event?.action == KeyEvent.ACTION_DOWN) {
            val currentTime = System.currentTimeMillis()

            if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                lastVolumeUpTime = currentTime
            } else if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                lastVolumeDownTime = currentTime
            }

            // If both pressed within 800ms → trigger SOS
            if (kotlin.math.abs(lastVolumeUpTime - lastVolumeDownTime) < 800) {
                triggerSos()
                lastVolumeUpTime = 0
                lastVolumeDownTime = 0
            }
        }
        return super.onKeyEvent(event)
    }

    private fun triggerSos() {
        try {
            Log.i("VolumeButtonService", "SOS Triggered via Volume Buttons")
            val intent = Intent(this, SosForegroundService::class.java)
            intent.action = SosForegroundService.ACTION_TRIGGER_SOS
            startForegroundService(intent)
        } catch (e: Exception) {
            Log.e("VolumeButtonService", "Failed to trigger SOS: $e")
        }
    }
}
