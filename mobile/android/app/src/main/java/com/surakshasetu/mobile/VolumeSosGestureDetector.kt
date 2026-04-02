package com.surakshasetu.mobile

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.KeyEvent
import kotlin.math.abs

internal class VolumeSosGestureDetector(
    private val holdDurationMs: Long = 750L,
    private val simultaneousPressWindowMs: Long = 800L,
    private val cooldownMs: Long = 15_000L,
    private val onTrigger: () -> Unit,
    private val onLog: (String) -> Unit = {},
) {
    private val handler = Handler(Looper.getMainLooper())

    private var isVolumeUpPressed = false
    private var isVolumeDownPressed = false
    private var lastVolumeUpDownMs = 0L
    private var lastVolumeDownDownMs = 0L
    private var holdStartMs = 0L
    private var lastTriggerMs = 0L
    private var triggeredForCurrentHold = false

    private val triggerRunnable = Runnable {
        val now = SystemClock.elapsedRealtime()
        val stillPressed = isVolumeUpPressed && isVolumeDownPressed
        val pressedTogether = hasValidSimultaneousPress()
        val holdCompleted = holdStartMs > 0L && now - holdStartMs >= holdDurationMs

        if (!stillPressed || !pressedTogether || !holdCompleted || triggeredForCurrentHold) {
            return@Runnable
        }

        tryTrigger(now, "Volume SOS combo confirmed")
    }

    fun onKeyDown(keyCode: Int, repeatCount: Int) {
        if (!isVolumeKey(keyCode) || repeatCount > 0) {
            return
        }

        val now = SystemClock.elapsedRealtime()
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                isVolumeUpPressed = true
                lastVolumeUpDownMs = now
            }

            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                isVolumeDownPressed = true
                lastVolumeDownDownMs = now
            }
        }

        maybeStartHold(now)
    }

    fun onKeyUp(keyCode: Int) {
        if (!isVolumeKey(keyCode)) {
            return
        }

        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                isVolumeUpPressed = false
                lastVolumeUpDownMs = 0L
            }

            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                isVolumeDownPressed = false
                lastVolumeDownDownMs = 0L
            }
        }

        if (!isVolumeUpPressed || !isVolumeDownPressed) {
            cancelPendingTrigger()
            holdStartMs = 0L
            triggeredForCurrentHold = false
        }
    }

    fun clear() {
        cancelPendingTrigger()
        isVolumeUpPressed = false
        isVolumeDownPressed = false
        lastVolumeUpDownMs = 0L
        lastVolumeDownDownMs = 0L
        holdStartMs = 0L
        triggeredForCurrentHold = false
    }

    private fun maybeStartHold(now: Long) {
        cancelPendingTrigger()

        if (triggeredForCurrentHold) {
            return
        }

        if (!isVolumeUpPressed || !isVolumeDownPressed) {
            holdStartMs = 0L
            return
        }

        if (!hasValidSimultaneousPress()) {
            holdStartMs = 0L
            onLog("Volume buttons were not pressed together closely enough")
            return
        }

        holdStartMs = maxOf(lastVolumeUpDownMs, lastVolumeDownDownMs)
        val elapsedHoldMs = now - holdStartMs
        val remainingHoldMs = (holdDurationMs - elapsedHoldMs).coerceAtLeast(0L)

        if (remainingHoldMs == 0L) {
            tryTrigger(now, "Volume SOS combo confirmed")
            return
        }

        onLog("Volume SOS combo detected; keep holding briefly to confirm")
        handler.postDelayed(triggerRunnable, remainingHoldMs)
    }

    private fun tryTrigger(now: Long, successMessage: String): Boolean {
        if (triggeredForCurrentHold) {
            return false
        }

        if (now - lastTriggerMs < cooldownMs) {
            onLog("Volume SOS combo ignored during cooldown")
            return false
        }

        lastTriggerMs = now
        triggeredForCurrentHold = true
        cancelPendingTrigger()
        onLog(successMessage)
        onTrigger()
        return true
    }

    private fun hasValidSimultaneousPress(): Boolean {
        return lastVolumeUpDownMs > 0L &&
            lastVolumeDownDownMs > 0L &&
            abs(lastVolumeUpDownMs - lastVolumeDownDownMs) <= simultaneousPressWindowMs
    }

    private fun cancelPendingTrigger() {
        handler.removeCallbacks(triggerRunnable)
    }

    private fun isVolumeKey(keyCode: Int): Boolean {
        return keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
    }
}
