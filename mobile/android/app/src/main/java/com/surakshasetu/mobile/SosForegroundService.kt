package com.surakshasetu.mobile
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.tasks.CancellationTokenSource

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.camera2.*
import android.location.Location
import android.media.MediaRecorder
import android.net.Uri
import android.os.*
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.storage.FirebaseStorage
import java.io.File
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit


/**
 * Foreground service that:
 *  - requests a single location (and optionally continuous tracking),
 *  - records a 15-second video (camera + audio) and saves to a temp file,
 *  - uploads the video (and audio) to Firebase Storage,
 *  - creates an incident doc in Firestore with userId, timestamp, lat, lon, storage urls,
 *  - if no internet, sends SMS fallback to emergency contact with a location link,
 *  - if still no network or SMS fails, attempts a direct call to emergency number.
 *
 * Notes:
 * - This implementation attempts to be robust but low-level camera2 + mediaRecorder code
 *   may need device-specific adjustments (camera permission, file paths).
 * - You must include Firebase initialization in your Application or MainActivity (FirebaseApp.initializeApp).
 */
 private var wakeLock: PowerManager.WakeLock? = null

class SosForegroundService : Service() {
    companion object {
        const val TAG = "SosForegroundService"
        const val CHANNEL_ID = "sos_channel_v1"
        const val NOTIF_ID = 98081
        const val ACTION_TRIGGER_SOS = "ACTION_TRIGGER_SOS"

        // length of the video to record (ms)
        const val RECORD_MS = 15_000L
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var firestore: FirebaseFirestore
    private lateinit var storage: FirebaseStorage
    private var tempVideoFile: File? = null
    private var mediaRecorder: MediaRecorder? = null

   override fun onCreate() {
    super.onCreate()
    Log.i(TAG, "Service created")
    createNotificationChannel()
    fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
    FirebaseApp.initializeApp(this)
    firestore = FirebaseFirestore.getInstance()
    storage = FirebaseStorage.getInstance()

    // Keep CPU awake for background volume triggers
    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
    wakeLock = powerManager.newWakeLock(
        PowerManager.PARTIAL_WAKE_LOCK,
        "SurakshaSetu::SosWakeLock"
    )
    wakeLock?.acquire(20 * 60 * 1000L) // 20 min max
}


    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand action=${intent?.action}")
        if (intent?.action == ACTION_TRIGGER_SOS) {
            startForeground(NOTIF_ID, buildNotification("Sending SOS..."))
            handleSosFlow()
            return START_STICKY
        }
        return START_NOT_STICKY
    }

    private fun buildNotification(content: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Suraksha Setu — SOS active")
            .setContentText(content)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SOS Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            nm.createNotificationChannel(channel)
        }
    }

    private fun handleSosFlow() {
    Thread {
        try {
            Log.i(TAG, "Starting SOS workflow...")

            // 1️⃣ Get location safely in background thread
            val location = getCurrentLocationBlocking()

            // 2️⃣ Record audio/video safely
            val videoFile = recordVideoBlocking(RECORD_MS)

            // 3️⃣ Upload and save to Firestore (same as before)
            val incidentId = UUID.randomUUID().toString()
            val dataMap = mutableMapOf<String, Any?>(
                "userId" to "unknown",
                "timestamp" to Date(),
                "lat" to (location?.latitude ?: 0.0),
                "lon" to (location?.longitude ?: 0.0),
                "status" to "active"
            )
            firestore.collection("incidents").document(incidentId).set(dataMap)
                .addOnSuccessListener { Log.i(TAG, "Incident doc written: $incidentId") }

            if (videoFile != null && videoFile.exists()) {
                val storageRef = storage.reference.child("incidents/$incidentId/video.mp4")
                storageRef.putFile(Uri.fromFile(videoFile))
                    .addOnSuccessListener {
                        storageRef.downloadUrl.addOnSuccessListener { url ->
                            firestore.collection("incidents")
                                .document(incidentId)
                                .update("videoUrl", url.toString())
                        }
                    }
            }

            if (!isNetworkAvailable()) {
                sendSmsFallback(location)
                attemptEmergencyCall()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error in SOS flow: $e")
        } finally {
            stopSelf()
        }
    }.start() // 👈 run on background thread
}

    // ----------- LOCATION -----------
    private fun getCurrentLocationBlocking(timeoutMs: Long = 8000L): Location? {
        try {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
            ) {
                Log.w(TAG, "Location permission missing")
                return null
            }

            val task = fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY, CancellationTokenSource().token
            )
            val location = Tasks.await(task, timeoutMs, java.util.concurrent.TimeUnit.MILLISECONDS)
            Log.i(TAG, "Location received: $location")
            return location
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get location: $e")
            return null
        }
    }

    // ----------- RECORDING (camera + mic) -----------
   private fun recordVideoBlocking(durationMs: Long): File? {
    var cameraDevice: CameraDevice? = null
    var session: CameraCaptureSession? = null
    var handlerThread: HandlerThread? = null

    try {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED ||
            ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(TAG, "Camera/Mic permission missing")
            return null
        }

        val outDir = File(filesDir, "sos_videos").apply { mkdirs() }
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val videoFile = File(outDir, "sos_$timeStamp.mp4")
        tempVideoFile = videoFile

        mediaRecorder = MediaRecorder()
        mediaRecorder?.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setOutputFile(videoFile.absolutePath)
            setVideoEncodingBitRate(6_000_000)
            setVideoFrameRate(30)
            setVideoSize(1280, 720)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            prepare()
        }

        val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
        val cameraId = cameraManager.cameraIdList.firstOrNull() ?: return null

        handlerThread = HandlerThread("CameraThread").apply { start() }
        val handler = Handler(handlerThread.looper)
        val latch = CountDownLatch(1)

        cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                cameraDevice = camera
                latch.countDown()
            }

            override fun onDisconnected(camera: CameraDevice) {
                camera.close()
                latch.countDown()
            }

            override fun onError(camera: CameraDevice, error: Int) {
                Log.e(TAG, "Camera error: $error")
                camera.close()
                latch.countDown()
            }
        }, handler)

        latch.await(3000, TimeUnit.MILLISECONDS)
        if (cameraDevice == null) {
            Log.e(TAG, "Camera not opened")
            return null
        }

        val recorderSurface = mediaRecorder!!.surface
        val captureBuilder = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
        captureBuilder.addTarget(recorderSurface)

        val sessionLatch = CountDownLatch(1)
        cameraDevice!!.createCaptureSession(listOf(recorderSurface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(sess: CameraCaptureSession) {
                    session = sess
                    sess.setRepeatingRequest(captureBuilder.build(), null, handler)
                    sessionLatch.countDown()
                }

                override fun onConfigureFailed(sess: CameraCaptureSession) {
                    Log.e(TAG, "Capture session failed")
                    sessionLatch.countDown()
                }
            }, handler)

        sessionLatch.await(2000, TimeUnit.MILLISECONDS)

        mediaRecorder!!.start()
        Log.i(TAG, "Recording started for ${durationMs / 1000}s")

        Thread.sleep(durationMs)

        try {
            mediaRecorder?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "Stop failed: $e")
        }

        mediaRecorder?.release()
        cameraDevice?.close()
        handlerThread.quitSafely()

        Log.i(TAG, "Recording finished: ${videoFile.absolutePath}")
        return videoFile
    } catch (e: Exception) {
        Log.e(TAG, "Recording failed: $e")
        try { mediaRecorder?.release() } catch (_: Exception) {}
        cameraDevice?.close()
        handlerThread?.quitSafely()
        return null
    }
}

    // ----------- NETWORK CHECK -----------
    private fun isNetworkAvailable(): Boolean {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
            val net = cm.activeNetworkInfo
            return net != null && net.isConnected
        } catch (e: Exception) {
            return false
        }
    }

    // ----------- SMS FALLBACK -----------
    private fun sendSmsFallback(location: Location?) {
        try {
            // emergencyContactNumber should be retrieved from your app's secure storage
            val emergencyContactNumber = getEmergencyContactNumber() ?: return
            val sms = SmsManager.getDefault()
            val lat = location?.latitude
            val lon = location?.longitude
            val mapsLink = if (lat != null && lon != null) "https://maps.google.com/?q=$lat,$lon" else "Location unavailable"
            val body = "SOS! I need help. Location: $mapsLink"
            sms.sendTextMessage(emergencyContactNumber, null, body, null, null)
            Log.i(TAG, "SMS fallback sent to $emergencyContactNumber")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send SMS: $e")
        }
    }

    private fun getEmergencyContactNumber(): String? {
        // TODO: read from SharedPreferences, Firestore user profile, or local DB
        // For demo, read from a shared pref key "emergency_contact"
        val prefs = getSharedPreferences("suraksha_prefs", Context.MODE_PRIVATE)
        return prefs.getString("emergency_contact", null)
    }

    // ----------- EMERGENCY CALL -----------
    private fun attemptEmergencyCall() {
        try {
            val emergencyNumber = "112" // replace with local emergency number or fetch user configured
            val callIntent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$emergencyNumber"))
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
                callIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(callIntent)
            } else {
                Log.w(TAG, "CALL_PHONE permission missing")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to place emergency call: $e")
        }
    }

   override fun onDestroy() {
    super.onDestroy()
    try {
        wakeLock?.release()
    } catch (_: Exception) {}
    Log.i(TAG, "Service destroyed")
}

}
