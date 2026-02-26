package com.surakshasetu.mobile

import android.Manifest
import android.animation.ObjectAnimator
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class EmergencyCameraActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "EmergencyCameraActivity"
        private const val MAX_RECORDING_DURATION_MS = 45_000L
    }

    private lateinit var previewView: PreviewView
    private lateinit var recordingIndicator: TextView
    private lateinit var timerView: TextView

    private var cameraProvider: ProcessCameraProvider? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null
    private var recordingStartMs = 0L
    private var recordingFinalized = false
    private var sosId: String = ""

    private val mainHandler = Handler(Looper.getMainLooper())

    private val timerRunnable = object : Runnable {
        override fun run() {
            if (recordingStartMs == 0L) {
                return
            }
            val elapsedSec = ((SystemClock.elapsedRealtime() - recordingStartMs) / 1000L).toInt()
            val min = elapsedSec / 60
            val sec = elapsedSec % 60
            timerView.text = String.format(Locale.US, "%02d:%02d", min, sec)
            mainHandler.postDelayed(this, 1_000L)
        }
    }

    private val autoStopRunnable = Runnable {
        stopRecordingSafely("max_duration_reached")
    }

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            val cameraGranted = result[Manifest.permission.CAMERA] == true || hasPermission(Manifest.permission.CAMERA)
            if (!cameraGranted) {
                handleCameraFailure("camera_permission_denied")
                return@registerForActivityResult
            }
            startCamera()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 14 camera policy requires an actually visible Activity surface.
        // The service cannot open camera in the background, so this screen must be
        // brought to foreground and kept visible while capture runs.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_emergency_camera)

        previewView = findViewById(R.id.previewView)
        recordingIndicator = findViewById(R.id.recordingIndicator)
        timerView = findViewById(R.id.recordingTimer)
        sosId = intent.getStringExtra(SosForegroundService.EXTRA_SOS_ID).orEmpty().ifBlank {
            UUID.randomUUID().toString()
        }

        startBlinkingIndicator()

        if (hasPermission(Manifest.permission.CAMERA)) {
            startCamera()
        } else {
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.CAMERA,
                    Manifest.permission.RECORD_AUDIO,
                ),
            )
        }
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations && !recordingFinalized) {
            stopRecordingSafely("activity_no_longer_visible")
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(timerRunnable)
        mainHandler.removeCallbacks(autoStopRunnable)
        try {
            activeRecording?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to stop recording during destroy", e)
        }
        activeRecording = null
        cameraProvider?.unbindAll()
        cameraProvider = null
        super.onDestroy()
    }

    private fun startCamera() {
        val providerFuture = ProcessCameraProvider.getInstance(this)
        providerFuture.addListener(
            {
                try {
                    cameraProvider = providerFuture.get()
                    bindCameraUseCases()
                    startRecording()
                } catch (securityException: SecurityException) {
                    handleCameraFailure("security_exception:${securityException.message}")
                } catch (illegalStateException: IllegalStateException) {
                    handleCameraFailure("illegal_state:${illegalStateException.message}")
                } catch (e: Exception) {
                    handleCameraFailure("camera_provider_failed:${e.message}")
                }
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: throw IllegalStateException("Camera provider not ready")

        // CameraX must bind against this Activity lifecycle owner so camera
        // automatically stops when UI is no longer visible (Android 14 compliance).
        val preview = Preview.Builder().build().also {
            it.surfaceProvider = previewView.surfaceProvider
        }

        val recorder = Recorder.Builder()
            .setQualitySelector(
                QualitySelector.from(
                    Quality.FHD,
                    FallbackStrategy.lowerQualityOrHigherThan(Quality.SD),
                ),
            )
            .build()

        videoCapture = VideoCapture.withOutput(recorder)

        provider.unbindAll()
        provider.bindToLifecycle(
            this,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            videoCapture,
        )
    }

    private fun startRecording() {
        val capture = videoCapture ?: throw IllegalStateException("VideoCapture is not initialized")
        val outputFile = createOutputFile() ?: run {
            handleCameraFailure("output_file_creation_failed")
            return
        }

        try {
            val outputOptions = FileOutputOptions.Builder(outputFile).build()
            var pendingRecording = capture.output.prepareRecording(this, outputOptions)
            if (hasPermission(Manifest.permission.RECORD_AUDIO)) {
                pendingRecording = pendingRecording.withAudioEnabled()
            }

            activeRecording = pendingRecording.start(ContextCompat.getMainExecutor(this)) { event ->
                when (event) {
                    is VideoRecordEvent.Start -> {
                        recordingStartMs = SystemClock.elapsedRealtime()
                        timerView.text = "00:00"
                        mainHandler.post(timerRunnable)
                        mainHandler.postDelayed(autoStopRunnable, MAX_RECORDING_DURATION_MS)
                        notifyService(
                            action = SosForegroundService.ACTION_CAMERA_RECORDING_STARTED,
                            recordingPath = outputFile.absolutePath,
                        )
                    }

                    is VideoRecordEvent.Finalize -> {
                        mainHandler.removeCallbacks(timerRunnable)
                        mainHandler.removeCallbacks(autoStopRunnable)
                        recordingFinalized = true
                        activeRecording = null

                        if (event.hasError()) {
                            val reason = "recording_finalize_error:${event.error}:${event.cause?.message.orEmpty()}"
                            notifyService(
                                action = SosForegroundService.ACTION_CAMERA_RECORDING_FAILED,
                                failureReason = reason,
                            )
                            Log.e(TAG, "CameraX finalize failed: $reason")
                        } else {
                            notifyService(
                                action = SosForegroundService.ACTION_CAMERA_RECORDING_FINISHED,
                                recordingPath = outputFile.absolutePath,
                            )
                        }
                        finishAndRemoveTask()
                    }
                }
            }
        } catch (securityException: SecurityException) {
            handleCameraFailure("security_exception:${securityException.message}")
        } catch (illegalStateException: IllegalStateException) {
            handleCameraFailure("illegal_state:${illegalStateException.message}")
        } catch (e: Exception) {
            handleCameraFailure("recording_start_failed:${e.message}")
        }
    }

    private fun stopRecordingSafely(reason: String) {
        if (recordingFinalized) {
            return
        }
        try {
            activeRecording?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording safely", e)
            notifyService(
                action = SosForegroundService.ACTION_CAMERA_RECORDING_FAILED,
                failureReason = "stop_failed:$reason:${e.message}",
            )
            recordingFinalized = true
            finishAndRemoveTask()
        }
    }

    private fun createOutputFile(): File? {
        return try {
            val outputDir = File(filesDir, "sos_videos")
            if (!outputDir.exists() && !outputDir.mkdirs()) {
                return null
            }
            val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
            File(outputDir, "sos_video_${sosId}_${timestamp}.mp4")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create output file", e)
            null
        }
    }

    private fun notifyService(
        action: String,
        recordingPath: String? = null,
        failureReason: String? = null,
    ) {
        val intent = Intent(this, SosForegroundService::class.java).apply {
            this.action = action
            putExtra(SosForegroundService.EXTRA_SOS_ID, sosId)
            if (!recordingPath.isNullOrBlank()) {
                putExtra(SosForegroundService.EXTRA_RECORDING_PATH, recordingPath)
            }
            if (!failureReason.isNullOrBlank()) {
                putExtra(SosForegroundService.EXTRA_FAILURE_REASON, failureReason)
            }
        }
        try {
            startService(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify SOS service action=$action", e)
        }
    }

    private fun handleCameraFailure(reason: String) {
        Log.e(TAG, "Emergency camera failure: $reason")
        notifyService(
            action = SosForegroundService.ACTION_CAMERA_RECORDING_FAILED,
            failureReason = reason,
        )
        recordingFinalized = true
        finishAndRemoveTask()
    }

    private fun startBlinkingIndicator() {
        // UI must remain visible and obvious for policy compliance; hidden/invisible
        // capture patterns are not allowed for emergency camera use on Android 14.
        ObjectAnimator.ofFloat(recordingIndicator, "alpha", 1f, 0.2f).apply {
            duration = 550L
            repeatCount = ObjectAnimator.INFINITE
            repeatMode = ObjectAnimator.REVERSE
            interpolator = LinearInterpolator()
            start()
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }
}
