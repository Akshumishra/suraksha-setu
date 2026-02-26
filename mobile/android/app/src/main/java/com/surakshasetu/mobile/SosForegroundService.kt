package com.surakshasetu.mobile

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.GeoPoint
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

class SosForegroundService : Service() {

    companion object {
        const val TAG = "SosForegroundService"

        const val ACTION_TRIGGER_SOS = "com.surakshasetu.mobile.action.TRIGGER_SOS"
        const val ACTION_CAMERA_RECORDING_STARTED = "com.surakshasetu.mobile.action.CAMERA_RECORDING_STARTED"
        const val ACTION_CAMERA_RECORDING_FINISHED = "com.surakshasetu.mobile.action.CAMERA_RECORDING_FINISHED"
        const val ACTION_CAMERA_RECORDING_FAILED = "com.surakshasetu.mobile.action.CAMERA_RECORDING_FAILED"

        const val EXTRA_TRIGGER_SOURCE = "extra_trigger_source"
        const val EXTRA_TRIGGER_WHILE_LOCKED = "extra_trigger_while_locked"
        const val EXTRA_SOS_ID = "extra_sos_id"
        const val EXTRA_RECORDING_PATH = "extra_recording_path"
        const val EXTRA_FAILURE_REASON = "extra_failure_reason"

        private const val CHANNEL_ID = "sos_emergency_channel"
        private const val NOTIFICATION_ID = 98081
        private const val FIREBASE_TIMEOUT_SECONDS = 20L
        private const val LOCATION_TIMEOUT_SECONDS = 8L
        private const val LOCATION_UPDATE_INTERVAL_MS = 10_000L
        private const val LOCATION_FASTEST_INTERVAL_MS = 5_000L
        private const val DEFAULT_EMERGENCY_NUMBER = "112"
        private const val AUTO_STOP_DELAY_MS = 20_000L
    }

    private data class StationMatch(
        val stationId: String,
        val contactNumber: String?,
    )

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var firestore: FirebaseFirestore
    private lateinit var fusedLocationClient: FusedLocationProviderClient

    @Volatile
    private var sosFlowRunning = false

    @Volatile
    private var activeSosId: String? = null

    @Volatile
    private var activeUserId: String? = null

    private var stopSelfJob: Job? = null
    private var liveLocationCallback: LocationCallback? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
            }
            firestore = FirebaseFirestore.getInstance()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Firebase in SOS service", e)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_TRIGGER_SOS -> handleSosTrigger(intent)
            ACTION_CAMERA_RECORDING_STARTED -> handleCameraRecordingStarted(intent)
            ACTION_CAMERA_RECORDING_FINISHED -> handleCameraRecordingFinished(intent)
            ACTION_CAMERA_RECORDING_FAILED -> handleCameraRecordingFailed(intent)
            else -> Log.w(TAG, "Unsupported action received: ${intent?.action}")
        }
        return START_STICKY
    }

    private fun handleSosTrigger(intent: Intent) {
        startForegroundWithNotification(getString(R.string.sos_notification_starting))

        val existingSosId = activeSosId
        if (sosFlowRunning && !existingSosId.isNullOrBlank()) {
            // We intentionally relaunch the camera screen because Android 14 requires
            // camera capture to occur from a visible Activity, not from this service.
            launchEmergencyCameraActivity(
                sosId = existingSosId,
                triggerSource = intent.getStringExtra(EXTRA_TRIGGER_SOURCE) ?: "unknown",
            )
            updateNotification(getString(R.string.sos_notification_recording))
            return
        }

        val triggerSource = intent.getStringExtra(EXTRA_TRIGGER_SOURCE) ?: "unknown"
        val whileLocked = intent.getBooleanExtra(EXTRA_TRIGGER_WHILE_LOCKED, false)
        val sosId = UUID.randomUUID().toString()

        activeSosId = sosId
        activeUserId = FirebaseAuth.getInstance().currentUser?.uid
        sosFlowRunning = true

        launchEmergencyCameraActivity(
            sosId = sosId,
            triggerSource = triggerSource,
        )
        Log.i(TAG, "SOS trigger accepted source=$triggerSource whileLocked=$whileLocked sosId=$sosId")

        serviceScope.launch {
            runSosAlertPipeline(
                sosId = sosId,
                triggerSource = triggerSource,
            )
        }
    }

    private fun handleCameraRecordingStarted(intent: Intent) {
        intent.getStringExtra(EXTRA_SOS_ID)?.takeIf { it.isNotBlank() }?.let { activeSosId = it }
        val path = intent.getStringExtra(EXTRA_RECORDING_PATH).orEmpty()
        updateNotification(getString(R.string.sos_notification_recording))
        updateRecordingMetadata(
            recordingStatus = "recording",
            localPath = path,
            failureReason = null,
        )
    }

    private fun handleCameraRecordingFinished(intent: Intent) {
        intent.getStringExtra(EXTRA_SOS_ID)?.takeIf { it.isNotBlank() }?.let { activeSosId = it }
        val path = intent.getStringExtra(EXTRA_RECORDING_PATH).orEmpty()
        updateNotification(getString(R.string.sos_notification_recording_finished))
        updateRecordingMetadata(
            recordingStatus = "finished",
            localPath = path,
            failureReason = null,
        )
        scheduleSelfStop()
    }

    private fun handleCameraRecordingFailed(intent: Intent) {
        intent.getStringExtra(EXTRA_SOS_ID)?.takeIf { it.isNotBlank() }?.let { activeSosId = it }
        val reason = intent.getStringExtra(EXTRA_FAILURE_REASON).orEmpty()
        Log.e(TAG, "Emergency camera failed: $reason")
        updateNotification(getString(R.string.sos_notification_camera_failed))
        updateRecordingMetadata(
            recordingStatus = "failed",
            localPath = null,
            failureReason = reason,
        )
        scheduleSelfStop()
    }

    private suspend fun runSosAlertPipeline(
        sosId: String,
        triggerSource: String,
    ) {
        try {
            if (!::firestore.isInitialized) {
                updateNotification(getString(R.string.sos_notification_pipeline_failed))
                scheduleSelfStop()
                return
            }
            val userId = activeUserId
            if (userId.isNullOrBlank()) {
                updateNotification(getString(R.string.sos_notification_auth_required))
                Log.e(TAG, "SOS requires authenticated user")
                scheduleSelfStop()
                return
            }

            updateNotification(getString(R.string.sos_notification_locating))
            val location = getCurrentLocationSafely()
            val stationMatch = location?.let { findNearestStation(it.latitude, it.longitude) }

            writeSosDocument(
                sosId = sosId,
                userId = userId,
                triggerSource = triggerSource,
                location = location,
                assignedStationId = stationMatch?.stationId,
            )
            notifyLinkedEmergencyContacts(
                sosId = sosId,
                sourceUserId = userId,
                location = location,
                assignedStationId = stationMatch?.stationId,
            )

            if (!hasInternetConnection()) {
                triggerSmsFallback(
                    userId = userId,
                    location = location,
                    stationContactNumber = stationMatch?.contactNumber,
                )
            }

            startLiveLocationUpdates(sosId)
            updateNotification(getString(R.string.sos_notification_recording))
        } catch (e: Exception) {
            Log.e(TAG, "SOS pipeline failed", e)
            updateNotification(getString(R.string.sos_notification_pipeline_failed))
            scheduleSelfStop()
        }
    }

    private fun launchEmergencyCameraActivity(
        sosId: String,
        triggerSource: String,
    ) {
        // Android 14 blocks background/headless camera starts. We launch a visible
        // Activity to own camera access and lifecycle binding in a policy-compliant way.
        val cameraIntent = Intent(this, EmergencyCameraActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(EXTRA_SOS_ID, sosId)
            putExtra(EXTRA_TRIGGER_SOURCE, triggerSource)
        }
        try {
            startActivity(cameraIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Could not open EmergencyCameraActivity", e)
            updateNotification(getString(R.string.sos_notification_open_camera_failed))
        }
    }

    private fun startForegroundWithNotification(content: String) {
        val notification = buildNotification(content)
        // Foreground service remains responsible for long-running SOS workflows
        // (location + responder alert pipeline), while camera runs in a visible Activity.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(content: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            1001,
            Intent(this, EmergencyCameraActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                activeSosId?.let { putExtra(EXTRA_SOS_ID, it) }
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(getString(R.string.sos_notification_title))
            .setContentText(content)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_camera,
                getString(R.string.sos_notification_action_camera),
                pendingIntent,
            )
            .build()
    }

    private fun updateNotification(content: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(content))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.sos_notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.sos_notification_channel_description)
        }
        manager.createNotificationChannel(channel)
    }

    private fun scheduleSelfStop() {
        stopSelfJob?.cancel()
        stopSelfJob = serviceScope.launch {
            delay(AUTO_STOP_DELAY_MS)
            stopSelf()
        }
    }

    private fun updateRecordingMetadata(
        recordingStatus: String,
        localPath: String?,
        failureReason: String?,
    ) {
        if (!::firestore.isInitialized) {
            return
        }
        val sosId = activeSosId ?: return
        val payload = mutableMapOf<String, Any?>(
            "recordingStatus" to recordingStatus,
            "recordingFailureReason" to failureReason,
        )
        if (!localPath.isNullOrBlank()) {
            payload["localMediaPath"] = localPath
        }
        firestore.collection("sos")
            .document(sosId)
            .set(payload, SetOptions.merge())
            .addOnFailureListener { Log.e(TAG, "Failed to update recording metadata", it) }
    }

    @SuppressLint("MissingPermission")
    private fun startLiveLocationUpdates(sosId: String) {
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            Log.w(TAG, "ACCESS_FINE_LOCATION not granted; skipping live location updates")
            return
        }

        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            LOCATION_UPDATE_INTERVAL_MS,
        ).setMinUpdateIntervalMillis(LOCATION_FASTEST_INTERVAL_MS)
            .build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val latestLocation = result.lastLocation ?: return
                val payload = mapOf<String, Any>(
                    "location" to GeoPoint(latestLocation.latitude, latestLocation.longitude),
                    "lat" to latestLocation.latitude,
                    "lon" to latestLocation.longitude,
                    "lastLocationUpdateAt" to FieldValue.serverTimestamp(),
                )
                firestore.collection("sos")
                    .document(sosId)
                    .set(payload, SetOptions.merge())
                    .addOnFailureListener { error ->
                        Log.e(TAG, "Failed to write live location update", error)
                    }
            }
        }

        liveLocationCallback = callback
        try {
            fusedLocationClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            Log.e(TAG, "Location update request denied", e)
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected location request failure", e)
        }
    }

    private fun stopLiveLocationUpdates() {
        val callback = liveLocationCallback ?: return
        fusedLocationClient.removeLocationUpdates(callback)
            .addOnFailureListener { error ->
                Log.w(TAG, "Failed to remove live location updates cleanly", error)
            }
        liveLocationCallback = null
    }

    private fun writeSosDocument(
        sosId: String,
        userId: String,
        triggerSource: String,
        location: Location?,
        assignedStationId: String?,
    ) {
        val payload = mutableMapOf<String, Any?>(
            "userId" to userId,
            "timestamp" to FieldValue.serverTimestamp(),
            "status" to "active",
            "mediaUrl" to "",
            "triggerSource" to triggerSource,
            "recordingStatus" to "camera_activity_started",
            "recordingFailureReason" to null,
            "localMediaPath" to "",
            "assignedStationId" to (assignedStationId ?: ""),
            "cancelledAt" to null,
        )

        if (location != null) {
            payload["location"] = GeoPoint(location.latitude, location.longitude)
            payload["lat"] = location.latitude
            payload["lon"] = location.longitude
        }

        Tasks.await(
            firestore.collection("sos").document(sosId).set(payload),
            FIREBASE_TIMEOUT_SECONDS,
            TimeUnit.SECONDS,
        )
    }

    private fun notifyLinkedEmergencyContacts(
        sosId: String,
        sourceUserId: String,
        location: Location?,
        assignedStationId: String?,
    ) {
        try {
            val sourceProfile = getUserProfileSnapshot(sourceUserId)
            val sourceName =
                sourceProfile?.getString("name")?.takeIf { it.isNotBlank() } ?: "Emergency contact"
            val sourcePhone = sourceProfile?.getString("phone")?.trim() ?: ""

            val contactsSnapshot = Tasks.await(
                firestore.collection("users")
                    .document(sourceUserId)
                    .collection("emergency_contacts")
                    .get(),
                FIREBASE_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
            )

            val batch = firestore.batch()
            var targetCount = 0
            for (contactDoc in contactsSnapshot.documents) {
                val targetUserId = contactDoc.getString("contactUserId")?.trim()
                if (targetUserId.isNullOrEmpty() || targetUserId == sourceUserId) {
                    continue
                }

                val relation = contactDoc.getString("relation")?.trim() ?: ""
                val payload = mutableMapOf<String, Any?>(
                    "sosId" to sosId,
                    "sourceUserId" to sourceUserId,
                    "sourceContactId" to contactDoc.id,
                    "sourceName" to sourceName,
                    "sourcePhone" to sourcePhone,
                    "relation" to relation,
                    "status" to "active",
                    "timestamp" to FieldValue.serverTimestamp(),
                    "isRead" to false,
                    "assignedStationId" to (assignedStationId ?: ""),
                )
                if (location != null) {
                    payload["location"] = GeoPoint(location.latitude, location.longitude)
                }

                val targetAlertRef = firestore.collection("users")
                    .document(targetUserId)
                    .collection("incoming_sos")
                    .document(sosId)
                batch.set(targetAlertRef, payload, SetOptions.merge())
                targetCount++
            }

            if (targetCount > 0) {
                Tasks.await(
                    batch.commit(),
                    FIREBASE_TIMEOUT_SECONDS,
                    TimeUnit.SECONDS,
                )
            }
            Log.i(TAG, "Incoming SOS alerts dispatched count=$targetCount")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify emergency contacts", e)
        }
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentLocationSafely(): Location? {
        if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            return null
        }
        return try {
            val cancellationTokenSource = CancellationTokenSource()
            val location = Tasks.await(
                fusedLocationClient.getCurrentLocation(
                    Priority.PRIORITY_HIGH_ACCURACY,
                    cancellationTokenSource.token,
                ),
                LOCATION_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
            )
            location ?: Tasks.await(fusedLocationClient.lastLocation, 3, TimeUnit.SECONDS)
        } catch (e: Exception) {
            Log.e(TAG, "Could not resolve current location", e)
            null
        }
    }

    private fun triggerSmsFallback(
        userId: String,
        location: Location?,
        stationContactNumber: String?,
    ) {
        if (!hasPermission(Manifest.permission.SEND_SMS)) {
            return
        }
        val recipients = linkedSetOf<String>()
        normalizePhoneNumber(stationContactNumber)?.let { recipients.add(it) }
        if (recipients.isEmpty()) {
            recipients.add(DEFAULT_EMERGENCY_NUMBER)
        }
        recipients.addAll(getEmergencyContactNumbers(userId))
        if (recipients.isEmpty()) {
            return
        }

        val sourceName = getUserProfileSnapshot(userId)
            ?.getString("name")
            ?.takeIf { it.isNotBlank() }
            ?: "Suraksha Setu user"
        val latText = location?.latitude?.let { String.format(Locale.US, "%.6f", it) } ?: "unknown"
        val lonText = location?.longitude?.let { String.format(Locale.US, "%.6f", it) } ?: "unknown"
        val mapsUrl =
            if (location != null) "https://maps.google.com/?q=$latText,$lonText" else "unavailable"
        val message = "SOS ALERT from $sourceName. Lat:$latText Lon:$lonText Map:$mapsUrl"

        val smsManager =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                null
            } ?: run {
                Log.w(TAG, "SMS fallback unavailable on this OS build without deprecated APIs")
                return
            }

        for (recipient in recipients) {
            try {
                val parts = smsManager.divideMessage(message)
                if (parts.size > 1) {
                    smsManager.sendMultipartTextMessage(recipient, null, parts, null, null)
                } else {
                    smsManager.sendTextMessage(recipient, null, message, null, null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "SMS fallback failed for $recipient", e)
            }
        }
    }

    private fun getEmergencyContactNumbers(userId: String): List<String> {
        return try {
            val snapshot = Tasks.await(
                firestore.collection("users")
                    .document(userId)
                    .collection("emergency_contacts")
                    .get(),
                FIREBASE_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
            )
            snapshot.documents.mapNotNull { normalizePhoneNumber(it.getString("phone")) }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read emergency contacts", e)
            emptyList()
        }
    }

    private fun normalizePhoneNumber(number: String?): String? {
        val normalized = number
            ?.replace("\\s".toRegex(), "")
            ?.replace("-", "")
            ?.trim()
            ?.takeIf { it.isNotBlank() }
            ?: return null
        return normalized
    }

    private fun hasInternetConnection(): Boolean {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
        val activeNetwork = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun getUserProfileSnapshot(userId: String): DocumentSnapshot? {
        return try {
            Tasks.await(
                firestore.collection("users").document(userId).get(),
                FIREBASE_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load user profile for $userId", e)
            null
        }
    }

    private fun findNearestStation(
        latitude: Double,
        longitude: Double,
    ): StationMatch? {
        return try {
            val snapshot = Tasks.await(
                firestore.collection("police_stations").get(),
                FIREBASE_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
            )
            var nearestWithinRadius: StationMatch? = null
            var nearestWithinRadiusKm = Double.MAX_VALUE
            var nearestAny: StationMatch? = null
            var nearestAnyKm = Double.MAX_VALUE

            for (doc in snapshot.documents) {
                val stationLat = doc.getDouble("latitude") ?: continue
                val stationLon = doc.getDouble("longitude") ?: continue
                val radiusKm = doc.getDouble("jurisdictionRadius")
                val distanceKm = haversineKm(latitude, longitude, stationLat, stationLon)
                val stationMatch = StationMatch(
                    stationId = doc.id,
                    contactNumber = doc.getString("contactNumber"),
                )

                if (distanceKm < nearestAnyKm) {
                    nearestAnyKm = distanceKm
                    nearestAny = stationMatch
                }

                val insideJurisdiction = radiusKm == null || distanceKm <= radiusKm
                if (insideJurisdiction && distanceKm < nearestWithinRadiusKm) {
                    nearestWithinRadiusKm = distanceKm
                    nearestWithinRadius = stationMatch
                }
            }

            nearestWithinRadius ?: nearestAny
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve nearest station", e)
            null
        }
    }

    private fun haversineKm(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double,
    ): Double {
        val earthRadiusKm = 6371.0
        val dLat = Math.toRadians(toLat - fromLat)
        val dLon = Math.toRadians(toLon - fromLon)
        val a =
            sin(dLat / 2) * sin(dLat / 2) +
                cos(Math.toRadians(fromLat)) *
                    cos(Math.toRadians(toLat)) *
                    sin(dLon / 2) *
                    sin(dLon / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }

    private fun hasPermission(permission: String): Boolean {
        return ActivityCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED
    }

    override fun onDestroy() {
        stopSelfJob?.cancel()
        stopSelfJob = null
        stopLiveLocationUpdates()
        serviceScope.cancel()
        sosFlowRunning = false
        activeSosId = null
        activeUserId = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }
        super.onDestroy()
    }
}
