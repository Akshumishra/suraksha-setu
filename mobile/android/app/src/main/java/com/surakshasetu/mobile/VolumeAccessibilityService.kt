package com.surakshasetu.mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class VolumeAccessibilityService : AccessibilityService() {

    private val TAG = "VolumeAccessibilitySvc"
    private val volumeSosGestureDetector =
        VolumeSosGestureDetector(
            onTrigger = { triggerSOS() },
            onLog = { message -> Log.i(TAG, message) },
        )

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
                volumeSosGestureDetector.onKeyDown(event.keyCode, event.repeatCount)
            }
            KeyEvent.ACTION_UP -> {
                volumeSosGestureDetector.onKeyUp(event.keyCode)
            }
        }

        return super.onKeyEvent(event)
    }

    private fun triggerSOS() {
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

    override fun onDestroy() {
        volumeSosGestureDetector.clear()
        super.onDestroy()
    }
}
