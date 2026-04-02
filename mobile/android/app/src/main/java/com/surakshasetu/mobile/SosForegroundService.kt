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
import android.net.Uri
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
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Tasks
import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.DocumentSnapshot
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.GeoPoint
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.QuerySnapshot
import com.google.firebase.firestore.SetOptions
import com.google.firebase.firestore.Source
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.DataOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.net.URL
import java.net.URLConnection
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
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
        private const val MEDIA_UPLOAD_TIMEOUT_MS = 60_000
        private const val MEDIA_UPLOAD_BUFFER_SIZE = 8 * 1024
        private const val FIREBASE_CACHE_TIMEOUT_SECONDS = 3L
        private const val LOCAL_EMERGENCY_CONTACTS_CACHE_FILE = "emergency_contacts_cache.json"
        private const val LOCAL_USER_PROFILE_CACHE_FILE = "user_profile_cache.json"
        private const val LOCAL_SOS_METADATA_DIR = "sos_metadata"
    }

    private data class StationMatch(
        val stationId: String,
        val stationName: String?,
        val contactNumber: String?,
    )

    private data class CachedUserProfile(
        val userId: String,
        val name: String?,
        val phone: String?,
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

    @Volatile
    private var activeTriggerSource: String? = null

    @Volatile
    private var activeCreatedAtEpochMs: Long? = null

    @Volatile
    private var activeRecordingPath: String? = null

    @Volatile
    private var activeLatitude: Double? = null

    @Volatile
    private var activeLongitude: Double? = null

    @Volatile
    private var activeStationMatch: StationMatch? = null

    @Volatile
    private var deferredEmergencyDialNumber: String? = null

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
        activeTriggerSource = triggerSource
        activeCreatedAtEpochMs = System.currentTimeMillis()
        activeRecordingPath = null
        activeLatitude = null
        activeLongitude = null
        activeStationMatch = null
        deferredEmergencyDialNumber = null
        sosFlowRunning = true
        persistLocalSosMetadata()

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
        if (path.isNotBlank()) {
            activeRecordingPath = path
            persistLocalSosMetadata()
        }
        updateNotification(getString(R.string.sos_notification_recording))
        updateRecordingMetadata(
            recordingStatus = "recording",
            localPath = path,
            failureReason = null,
        )
    }

    private fun handleCameraRecordingFinished(intent: Intent) {
        val sosId = intent.getStringExtra(EXTRA_SOS_ID)?.takeIf { it.isNotBlank() }?.also {
            activeSosId = it
        } ?: activeSosId
        val path = intent.getStringExtra(EXTRA_RECORDING_PATH).orEmpty()
        if (path.isNotBlank()) {
            activeRecordingPath = path
        }
        persistLocalSosMetadata()
        updateNotification(getString(R.string.sos_notification_recording_finished))
        updateRecordingMetadata(
            recordingStatus = "finished",
            localPath = path,
            failureReason = null,
        )
        if (sosId.isNullOrBlank() || path.isBlank()) {
            consumeDeferredEmergencyDialNumber()?.let { placeEmergencyCall(it) }
            scheduleSelfStop()
            return
        }

        serviceScope.launch {
            consumeDeferredEmergencyDialNumber()?.let { placeEmergencyCall(it) }
            uploadRecordedMediaIfPossible(
                sosId = sosId,
                localPath = path,
            )
            scheduleSelfStop()
        }
    }

    private fun handleCameraRecordingFailed(intent: Intent) {
        intent.getStringExtra(EXTRA_SOS_ID)?.takeIf { it.isNotBlank() }?.let { activeSosId = it }
        val reason = intent.getStringExtra(EXTRA_FAILURE_REASON).orEmpty()
        Log.e(TAG, "Emergency camera failed: $reason")
        updateNotification(getString(R.string.sos_notification_camera_failed))
        persistLocalSosMetadata()
        updateRecordingMetadata(
            recordingStatus = "failed",
            localPath = null,
            failureReason = reason,
        )
        consumeDeferredEmergencyDialNumber()?.let { placeEmergencyCall(it) }
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

            var awaitRealtimeFirestore = hasInternetConnection()
            val seededSynchronously = seedInitialSosDocument(
                sosId = sosId,
                userId = userId,
                triggerSource = triggerSource,
                awaitSync = awaitRealtimeFirestore,
            )
            if (!seededSynchronously) {
                awaitRealtimeFirestore = false
            }

            updateNotification(getString(R.string.sos_notification_locating))
            val location = getCurrentLocationSafely()
            val stationMatch = location?.let { findNearestStation(it.latitude, it.longitude) }
            activeLatitude = location?.latitude
            activeLongitude = location?.longitude
            activeStationMatch = stationMatch
            persistLocalSosMetadata()

            awaitRealtimeFirestore = awaitRealtimeFirestore && hasInternetConnection()
            val locationWrittenSynchronously = writeSosDocument(
                sosId = sosId,
                location = location,
                assignedStationId = stationMatch?.stationId,
                awaitSync = awaitRealtimeFirestore,
            )
            if (!locationWrittenSynchronously) {
                awaitRealtimeFirestore = false
            }

            notifyLinkedEmergencyContacts(
                sosId = sosId,
                sourceUserId = userId,
                location = location,
                assignedStationMatch = stationMatch,
                awaitDispatch = awaitRealtimeFirestore,
            )

            if (!awaitRealtimeFirestore || !hasInternetConnection()) {
                triggerOfflineEmergencyFallback(
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
            .update(payload)
            .addOnFailureListener { error ->
                if (error is FirebaseFirestoreException &&
                    error.code == FirebaseFirestoreException.Code.NOT_FOUND
                ) {
                    Log.w(TAG, "Skipping recording metadata update; SOS document not found yet")
                } else {
                    Log.e(TAG, "Failed to update recording metadata", error)
                }
            }
    }

    private suspend fun uploadRecordedMediaIfPossible(
        sosId: String,
        localPath: String,
    ) {
        if (!::firestore.isInitialized) {
            return
        }
        val mediaFile = File(localPath)
        if (!mediaFile.exists()) {
            Log.w(TAG, "Recorded media file not found for upload: $localPath")
            return
        }
        if (!hasInternetConnection()) {
            Log.i(TAG, "Skipping immediate media upload because internet is unavailable")
            return
        }

        updateNotification(getString(R.string.sos_notification_uploading_media))
        try {
            val mediaUrl = uploadMediaToCloudinary(mediaFile)
            Tasks.await(
                firestore.collection("sos").document(sosId).update("mediaUrl", mediaUrl),
                FIREBASE_TIMEOUT_SECONDS,
                TimeUnit.SECONDS,
            )
            resolveSourceUserIdForSos(sosId)?.let { sourceUserId ->
                shareMediaLinkWithLinkedEmergencyContacts(
                    sosId = sosId,
                    sourceUserId = sourceUserId,
                    mediaUrl = mediaUrl,
                )
            }
            val deleted = mediaFile.delete()
            if (!deleted) {
                Log.w(TAG, "Uploaded media but could not delete local file: $localPath")
            } else {
                clearLocalSosMetadata(sosId)
            }
            Log.i(TAG, "SOS media uploaded successfully for sosId=$sosId")
        } catch (e: Exception) {
            Log.e(TAG, "Immediate media upload failed; background sync will retry", e)
        } finally {
            updateNotification(getString(R.string.sos_notification_recording_finished))
        }
    }

    private fun uploadMediaToCloudinary(file: File): String {
        val boundary = "----SurakshaSetu${System.currentTimeMillis()}"
        val lineEnd = "\r\n"
        val baseName = file.nameWithoutExtension.replace(Regex("[^A-Za-z0-9_-]"), "_")
        val publicId = "sos_${System.currentTimeMillis()}_$baseName"
        val uploadUrl =
            URL("https://api.cloudinary.com/v1_1/${BuildConfig.CLOUDINARY_CLOUD_NAME}/auto/upload")
        val connection = (uploadUrl.openConnection() as HttpURLConnection).apply {
            connectTimeout = MEDIA_UPLOAD_TIMEOUT_MS
            readTimeout = MEDIA_UPLOAD_TIMEOUT_MS
            doInput = true
            doOutput = true
            useCaches = false
            requestMethod = "POST"
            setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
        }

        try {
            DataOutputStream(connection.outputStream).use { output ->
                fun writeFormField(name: String, value: String) {
                    output.writeBytes("--$boundary$lineEnd")
                    output.writeBytes("Content-Disposition: form-data; name=\"$name\"$lineEnd")
                    output.writeBytes(lineEnd)
                    output.writeBytes(value)
                    output.writeBytes(lineEnd)
                }

                writeFormField("upload_preset", BuildConfig.CLOUDINARY_UPLOAD_PRESET)
                writeFormField("folder", BuildConfig.CLOUDINARY_FOLDER)
                writeFormField("public_id", publicId)

                val mimeType =
                    URLConnection.guessContentTypeFromName(file.name) ?: "application/octet-stream"
                output.writeBytes("--$boundary$lineEnd")
                output.writeBytes(
                    "Content-Disposition: form-data; name=\"file\"; filename=\"${file.name}\"$lineEnd",
                )
                output.writeBytes("Content-Type: $mimeType$lineEnd")
                output.writeBytes(lineEnd)
                file.inputStream().use { input ->
                    input.copyTo(output, MEDIA_UPLOAD_BUFFER_SIZE)
                }
                output.writeBytes(lineEnd)
                output.writeBytes("--$boundary--$lineEnd")
                output.flush()
            }

            val statusCode = connection.responseCode
            val responseBody = (
                if (statusCode in 200..299) connection.inputStream else connection.errorStream
                )
                ?.bufferedReader()
                ?.use { it.readText() }
                .orEmpty()

            if (statusCode !in 200..299) {
                throw IllegalStateException(
                    "Cloudinary upload failed ($statusCode): ${extractCloudinaryError(responseBody)}",
                )
            }

            val secureUrl = JSONObject(responseBody).optString("secure_url").trim()
            if (secureUrl.isBlank()) {
                throw IllegalStateException("Cloudinary upload succeeded but secure_url was missing.")
            }
            return secureUrl
        } finally {
            connection.disconnect()
        }
    }

    private fun extractCloudinaryError(responseBody: String): String {
        if (responseBody.isBlank()) {
            return "empty response"
        }
        return try {
            val decoded = JSONObject(responseBody)
            decoded.optJSONObject("error")?.optString("message")?.takeIf { it.isNotBlank() }
                ?: responseBody
        } catch (_: Exception) {
            responseBody
        }
    }

    private fun seedInitialSosDocument(
        sosId: String,
        userId: String,
        triggerSource: String,
        awaitSync: Boolean,
    ): Boolean {
        val payload = mutableMapOf<String, Any?>(
            "userId" to userId,
            "timestamp" to FieldValue.serverTimestamp(),
            "status" to "active",
            "triggerSource" to triggerSource,
            "recordingStatus" to "camera_activity_started",
            "recordingFailureReason" to null,
            "localMediaPath" to "",
            "assignedStationId" to "",
            "cancelledAt" to null,
        )

        return enqueueSet(
            task = firestore.collection("sos").document(sosId).set(payload, SetOptions.merge()),
            operationName = "seed initial SOS document",
            awaitSync = awaitSync,
        )
    }

    @SuppressLint("MissingPermission")
    private fun startLiveLocationUpdates(sosId: String) {
        if (!hasAnyLocationPermission()) {
            Log.w(TAG, "No location permission granted; skipping live location updates")
            return
        }

        val request = LocationRequest.Builder(
            resolveLocationPriority(),
            LOCATION_UPDATE_INTERVAL_MS,
        ).setMinUpdateIntervalMillis(LOCATION_FASTEST_INTERVAL_MS)
            .build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val latestLocation = result.lastLocation ?: return
                serviceScope.launch {
                    val stationMatch =
                        findNearestStation(latestLocation.latitude, latestLocation.longitude)
                    activeLatitude = latestLocation.latitude
                    activeLongitude = latestLocation.longitude
                    activeStationMatch = stationMatch
                    persistLocalSosMetadata()
                    val payload = mapOf<String, Any>(
                        "location" to GeoPoint(latestLocation.latitude, latestLocation.longitude),
                        "lat" to latestLocation.latitude,
                        "lon" to latestLocation.longitude,
                        "assignedStationId" to (stationMatch?.stationId ?: ""),
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
        location: Location?,
        assignedStationId: String?,
        awaitSync: Boolean,
    ): Boolean {
        if (location == null) {
            Log.w(TAG, "Skipping SOS location write because current location is unavailable")
            return awaitSync
        }

        val payload = mutableMapOf<String, Any?>(
            "location" to GeoPoint(location.latitude, location.longitude),
            "lat" to location.latitude,
            "lon" to location.longitude,
            "assignedStationId" to (assignedStationId ?: ""),
            "lastLocationUpdateAt" to FieldValue.serverTimestamp(),
        )

        return enqueueSet(
            task = firestore.collection("sos").document(sosId).set(payload, SetOptions.merge()),
            operationName = "write SOS location",
            awaitSync = awaitSync,
        )
    }

    private fun notifyLinkedEmergencyContacts(
        sosId: String,
        sourceUserId: String,
        location: Location?,
        assignedStationMatch: StationMatch?,
        awaitDispatch: Boolean,
    ) {
        try {
            val sourceProfile = getUserProfileSnapshot(sourceUserId)
            val sourceName =
                sourceProfile?.getString("name")?.takeIf { it.isNotBlank() } ?: "Emergency contact"
            val sourcePhone = sourceProfile?.getString("phone")?.trim() ?: ""

            val contactsSnapshot = getQuerySnapshotWithCacheFallback(
                firestore.collection("users")
                    .document(sourceUserId)
                    .collection("emergency_contacts"),
                operationName = "load linked emergency contacts",
                preferRemote = awaitDispatch,
            ) ?: return

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
                    "assignedStationId" to (assignedStationMatch?.stationId ?: ""),
                    "assignedStationName" to (assignedStationMatch?.stationName ?: ""),
                    "assignedStationContactNumber" to (assignedStationMatch?.contactNumber ?: ""),
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
                enqueueWrite(
                    task = batch.commit(),
                    operationName = "dispatch incoming SOS alerts",
                    awaitSync = awaitDispatch,
                )
            }
            Log.i(TAG, "Incoming SOS alerts dispatched count=$targetCount")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify emergency contacts", e)
        }
    }

    private fun shareMediaLinkWithLinkedEmergencyContacts(
        sosId: String,
        sourceUserId: String,
        mediaUrl: String,
    ) {
        try {
            val contactsSnapshot = getQuerySnapshotWithCacheFallback(
                firestore.collection("users")
                    .document(sourceUserId)
                    .collection("emergency_contacts"),
                operationName = "load linked emergency contacts for media sync",
            ) ?: return

            val batch = firestore.batch()
            var targetCount = 0
            for (contactDoc in contactsSnapshot.documents) {
                val targetUserId = contactDoc.getString("contactUserId")?.trim()
                if (targetUserId.isNullOrEmpty() || targetUserId == sourceUserId) {
                    continue
                }

                val targetAlertRef = firestore.collection("users")
                    .document(targetUserId)
                    .collection("incoming_sos")
                    .document(sosId)
                batch.set(
                    targetAlertRef,
                    mapOf(
                        "sosId" to sosId,
                        "sourceUserId" to sourceUserId,
                        "sourceContactId" to contactDoc.id,
                        "mediaUrl" to mediaUrl,
                    ),
                    SetOptions.merge(),
                )
                targetCount++
            }

            if (targetCount > 0) {
                enqueueWrite(
                    task = batch.commit(),
                    operationName = "dispatch SOS media links",
                    awaitSync = true,
                )
            }
            Log.i(TAG, "Incoming SOS media links dispatched count=$targetCount")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync SOS media links to emergency contacts", e)
        }
    }

    @SuppressLint("MissingPermission")
    private fun getCurrentLocationSafely(): Location? {
        if (!hasAnyLocationPermission()) {
            return null
        }
        return try {
            val cancellationTokenSource = CancellationTokenSource()
            val location = Tasks.await(
                fusedLocationClient.getCurrentLocation(
                    resolveLocationPriority(),
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
        recipients.addAll(getEmergencyContactNumbers(userId))
        if (recipients.isEmpty()) {
            return
        }

        val sourceProfile = getUserProfileSnapshot(userId)
        val cachedProfile = getCachedUserProfile(userId)
        val sourceName = sourceProfile
            ?.getString("name")
            ?.takeIf { it.isNotBlank() }
            ?: cachedProfile?.name
            ?: "Suraksha Setu user"
        val sourcePhone = sourceProfile
            ?.getString("phone")
            ?.takeIf { it.isNotBlank() }
            ?: cachedProfile?.phone
        val latText = location?.latitude?.let { String.format(Locale.US, "%.6f", it) } ?: "unknown"
        val lonText = location?.longitude?.let { String.format(Locale.US, "%.6f", it) } ?: "unknown"
        val mapsUrl =
            if (location != null) "https://maps.google.com/?q=$latText,$lonText" else "unavailable"
        val normalizedStationNumber = normalizePhoneNumber(stationContactNumber)
        val message = buildString {
            append("SOS ALERT from $sourceName.")
            if (!sourcePhone.isNullOrBlank()) {
                append(" Phone:$sourcePhone.")
            }
            append(" Lat:$latText Lon:$lonText Map:$mapsUrl.")
            if (!normalizedStationNumber.isNullOrBlank()) {
                append(" Police:$normalizedStationNumber.")
            }
            append(" Video link will sync when internet returns.")
        }

        val smsManager =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            } ?: run {
                Log.w(TAG, "SMS fallback unavailable because SmsManager could not be resolved")
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

    private fun triggerOfflineEmergencyFallback(
        userId: String,
        location: Location?,
        stationContactNumber: String?,
    ) {
        triggerSmsFallback(
            userId = userId,
            location = location,
            stationContactNumber = stationContactNumber,
        )
        deferredEmergencyDialNumber = DEFAULT_EMERGENCY_NUMBER
    }

    private fun placeEmergencyCall(number: String) {
        val normalizedNumber = normalizePhoneNumber(number) ?: DEFAULT_EMERGENCY_NUMBER
        val action =
            if (hasPermission(Manifest.permission.CALL_PHONE)) {
                Intent.ACTION_CALL
            } else {
                Intent.ACTION_DIAL
            }
        val callIntent = Intent(action, Uri.parse("tel:$normalizedNumber")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        try {
            startActivity(callIntent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch emergency call for $normalizedNumber", e)
        }
    }

    private fun getEmergencyContactNumbers(userId: String): List<String> {
        return try {
            val snapshot = getQuerySnapshotWithCacheFallback(
                firestore.collection("users")
                    .document(userId)
                    .collection("emergency_contacts"),
                operationName = "load emergency contact numbers",
            )
            val numbers = snapshot?.documents
                ?.mapNotNull { contactDoc ->
                    normalizePhoneNumber(contactDoc.getString("phone"))
                        ?: resolveLinkedEmergencyContactPhone(contactDoc.getString("contactUserId"))
                }
                .orEmpty()
            if (numbers.isNotEmpty()) {
                numbers
            } else {
                getCachedEmergencyContactNumbers(userId)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read emergency contacts", e)
            getCachedEmergencyContactNumbers(userId)
        }
    }

    private fun resolveLinkedEmergencyContactPhone(contactUserId: String?): String? {
        val normalizedUserId = contactUserId?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val linkedProfile = getUserProfileSnapshot(normalizedUserId) ?: return null
        return normalizePhoneNumber(linkedProfile.getString("phone"))
    }

    private fun normalizePhoneNumber(number: String?): String? {
        val trimmed = number?.trim()?.takeIf { it.isNotBlank() } ?: return null
        val hasLeadingPlus = trimmed.startsWith("+")
        val digitsOnly = trimmed.filter { it.isDigit() }
        if (digitsOnly.isBlank()) {
            return null
        }
        return if (hasLeadingPlus) "+$digitsOnly" else digitsOnly
    }

    private fun getCachedEmergencyContactNumbers(userId: String): List<String> {
        return try {
            val cacheFile = File(filesDir, LOCAL_EMERGENCY_CONTACTS_CACHE_FILE)
            if (!cacheFile.exists()) {
                return emptyList()
            }
            val decoded = JSONObject(cacheFile.readText())
            if (decoded.optString("userId").trim() != userId.trim()) {
                return emptyList()
            }
            val contacts = decoded.optJSONArray("contacts") ?: return emptyList()
            buildList {
                for (index in 0 until contacts.length()) {
                    val phone = normalizePhoneNumber(
                        contacts.optJSONObject(index)?.optString("phone"),
                    )
                    if (!phone.isNullOrBlank()) {
                        add(phone)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read cached emergency contacts", e)
            emptyList()
        }
    }

    private fun getCachedUserProfile(userId: String): CachedUserProfile? {
        return try {
            val cacheFile = File(filesDir, LOCAL_USER_PROFILE_CACHE_FILE)
            if (!cacheFile.exists()) {
                return null
            }
            val decoded = JSONObject(cacheFile.readText())
            val cachedUserId = decoded.optString("userId").trim()
            if (cachedUserId != userId.trim()) {
                return null
            }
            CachedUserProfile(
                userId = cachedUserId,
                name = decoded.optString("name").trim().ifBlank { null },
                phone = normalizePhoneNumber(decoded.optString("phone")),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read cached user profile", e)
            null
        }
    }

    private fun persistLocalSosMetadata() {
        val sosId = activeSosId?.trim().takeIf { !it.isNullOrEmpty() } ?: return
        try {
            val metadataDir = File(filesDir, LOCAL_SOS_METADATA_DIR)
            if (!metadataDir.exists()) {
                metadataDir.mkdirs()
            }
            val payload = JSONObject().apply {
                put("sosId", sosId)
                put("userId", activeUserId ?: JSONObject.NULL)
                put("triggerSource", activeTriggerSource ?: JSONObject.NULL)
                put("createdAtEpochMs", activeCreatedAtEpochMs ?: System.currentTimeMillis())
                put("localMediaPath", activeRecordingPath ?: JSONObject.NULL)
                put("latitude", activeLatitude ?: JSONObject.NULL)
                put("longitude", activeLongitude ?: JSONObject.NULL)
                put("assignedStationId", activeStationMatch?.stationId ?: JSONObject.NULL)
                put("assignedStationName", activeStationMatch?.stationName ?: JSONObject.NULL)
                put(
                    "assignedStationContactNumber",
                    activeStationMatch?.contactNumber ?: JSONObject.NULL,
                )
            }
            File(metadataDir, "$sosId.json").writeText(payload.toString())
        } catch (e: Exception) {
            Log.w(TAG, "Failed to persist local SOS metadata", e)
        }
    }

    private fun clearLocalSosMetadata(sosId: String) {
        try {
            val metadataFile = File(File(filesDir, LOCAL_SOS_METADATA_DIR), "${sosId.trim()}.json")
            if (metadataFile.exists() && !metadataFile.delete()) {
                Log.w(TAG, "Failed to delete local SOS metadata for sosId=$sosId")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to clear local SOS metadata", e)
        }
    }

    private fun consumeDeferredEmergencyDialNumber(): String? {
        val number = deferredEmergencyDialNumber
        deferredEmergencyDialNumber = null
        return number
    }

    private fun hasInternetConnection(): Boolean {
        val connectivityManager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
        val activeNetwork = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(activeNetwork) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
    }

    private fun resolveSourceUserIdForSos(sosId: String): String? {
        activeUserId?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }

        return try {
            val snapshot = getDocumentSnapshotWithCacheFallback(
                firestore.collection("sos").document(sosId),
                operationName = "resolve SOS source user",
            ) ?: return null
            snapshot.getString("userId")?.trim()?.takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve source user for sosId=$sosId", e)
            null
        }
    }

    private fun getUserProfileSnapshot(userId: String): DocumentSnapshot? {
        return try {
            getDocumentSnapshotWithCacheFallback(
                firestore.collection("users").document(userId),
                operationName = "load user profile",
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
            val snapshot = getQuerySnapshotWithCacheFallback(
                firestore.collection("police_stations"),
                operationName = "load police stations",
            ) ?: return null
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
                    stationName = doc.getString("stationName"),
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

    private fun enqueueSet(
        task: Task<Void>,
        operationName: String,
        awaitSync: Boolean,
    ): Boolean {
        return enqueueWrite(
            task = task,
            operationName = operationName,
            awaitSync = awaitSync,
        )
    }

    private fun enqueueWrite(
        task: Task<Void>,
        operationName: String,
        awaitSync: Boolean,
    ): Boolean {
        if (!awaitSync) {
            task.addOnFailureListener { error ->
                Log.e(TAG, "Failed to queue Firestore write: $operationName", error)
            }
            return false
        }

        return try {
            Tasks.await(task, FIREBASE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            true
        } catch (e: Exception) {
            if (isLikelyConnectivityIssue(e)) {
                Log.w(TAG, "Firestore write will continue best-effort: $operationName", e)
                false
            } else {
                throw e
            }
        }
    }

    private fun getDocumentSnapshotWithCacheFallback(
        reference: DocumentReference,
        operationName: String,
        preferRemote: Boolean = hasInternetConnection(),
    ): DocumentSnapshot? {
        if (!preferRemote) {
            return getCachedDocumentSnapshot(reference, operationName)
        }

        return try {
            Tasks.await(reference.get(), FIREBASE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (e: Exception) {
            if (isLikelyConnectivityIssue(e)) {
                Log.w(TAG, "Falling back to cached Firestore document for $operationName", e)
                getCachedDocumentSnapshot(reference, operationName)
            } else {
                throw e
            }
        }
    }

    private fun getCachedDocumentSnapshot(
        reference: DocumentReference,
        operationName: String,
    ): DocumentSnapshot? {
        return try {
            Tasks.await(reference.get(Source.CACHE), FIREBASE_CACHE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (e: Exception) {
            Log.w(TAG, "Cached Firestore document unavailable for $operationName", e)
            null
        }
    }

    private fun getQuerySnapshotWithCacheFallback(
        query: Query,
        operationName: String,
        preferRemote: Boolean = hasInternetConnection(),
    ): QuerySnapshot? {
        if (!preferRemote) {
            return getCachedQuerySnapshot(query, operationName)
        }

        return try {
            Tasks.await(query.get(), FIREBASE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (e: Exception) {
            if (isLikelyConnectivityIssue(e)) {
                Log.w(TAG, "Falling back to cached Firestore query for $operationName", e)
                getCachedQuerySnapshot(query, operationName)
            } else {
                throw e
            }
        }
    }

    private fun getCachedQuerySnapshot(
        query: Query,
        operationName: String,
    ): QuerySnapshot? {
        return try {
            Tasks.await(query.get(Source.CACHE), FIREBASE_CACHE_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        } catch (e: Exception) {
            Log.w(TAG, "Cached Firestore query unavailable for $operationName", e)
            null
        }
    }

    private fun isLikelyConnectivityIssue(error: Throwable): Boolean {
        var current: Throwable? = error
        while (current != null) {
            when (current) {
                is TimeoutException,
                is UnknownHostException,
                is SocketTimeoutException,
                -> return true
                is FirebaseFirestoreException -> {
                    if (
                        current.code == FirebaseFirestoreException.Code.UNAVAILABLE ||
                        current.code == FirebaseFirestoreException.Code.DEADLINE_EXCEEDED
                    ) {
                        return true
                    }
                }
            }
            current = current.cause
        }
        return false
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

    private fun hasAnyLocationPermission(): Boolean {
        return hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    private fun resolveLocationPriority(): Int {
        return if (hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
            Priority.PRIORITY_HIGH_ACCURACY
        } else {
            Priority.PRIORITY_BALANCED_POWER_ACCURACY
        }
    }

    override fun onDestroy() {
        stopSelfJob?.cancel()
        stopSelfJob = null
        stopLiveLocationUpdates()
        serviceScope.cancel()
        sosFlowRunning = false
        activeSosId = null
        activeUserId = null
        activeTriggerSource = null
        activeCreatedAtEpochMs = null
        activeRecordingPath = null
        activeLatitude = null
        activeLongitude = null
        activeStationMatch = null
        deferredEmergencyDialNumber = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }
        super.onDestroy()
    }
}
