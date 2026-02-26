import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'cloudinary_service.dart';
import 'station_assignment_service.dart';

class SosSyncService {
  SosSyncService._();
  static final SosSyncService instance = SosSyncService._();

  Timer? _timer;
  bool _syncing = false;

  Future<void> startAutoSync() async {
    await syncPendingFiles();

    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncPendingFiles(),
    );
  }

  Future<void> syncPendingFiles() async {
    if (_syncing) {
      return;
    }
    _syncing = true;

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      // Firestore rules require auth; skip sync until user session is available.
      if (currentUser == null) {
        return;
      }

      final documentsDir = await getApplicationDocumentsDirectory();
      final supportDir = await getApplicationSupportDirectory();
      final scanDirs = <Directory>[
        documentsDir,
        Directory(p.join(supportDir.path, 'sos_videos')),
        Directory(p.join(supportDir.path, 'sos_audio')),
      ];

      for (final dir in scanDirs) {
        if (!dir.existsSync()) {
          continue;
        }
        final files = dir.listSync().whereType<File>();

        for (final file in files) {
          final name = p.basenameWithoutExtension(file.path);
          final incidentInfo = _parseIncidentInfo(name);
          if (incidentInfo == null) {
            continue;
          }

          final incidentId = incidentInfo.incidentId;
          final latitude = incidentInfo.latitude;
          final longitude = incidentInfo.longitude;

          try {
            final mediaUrl = await CloudinaryService.uploadMedia(file: file);
            final incidentRef = FirebaseFirestore.instance.collection('sos').doc(incidentId);
            final incidentSnapshot = await incidentRef.get();

            if (incidentSnapshot.exists) {
              await incidentRef.update({
                'mediaUrl': mediaUrl,
              });
            } else {
              final incidentPayload = <String, Object?>{
                'userId': currentUser.uid,
                'timestamp': FieldValue.serverTimestamp(),
                'mediaUrl': mediaUrl,
                'status': 'active',
                'assignedStationId': null,
                'cancelledAt': null,
              };

              if (latitude != null && longitude != null) {
                incidentPayload['location'] = GeoPoint(latitude, longitude);
                incidentPayload['lat'] = latitude;
                incidentPayload['lon'] = longitude;
                incidentPayload['assignedStationId'] =
                    await StationAssignmentService.instance.findNearestStationId(
                  latitude: latitude,
                  longitude: longitude,
                );
              }

              await incidentRef.set(incidentPayload);
            }

            await file.delete();
          } catch (e, stackTrace) {
            // Keep retrying per-file failures, but log for observability.
            debugPrint('SOS sync failed for ${file.path}: $e');
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      }
    } finally {
      _syncing = false;
    }
  }

  _IncidentInfo? _parseIncidentInfo(String baseName) {
    final prefix = baseName.startsWith('sos_video_')
        ? 'sos_video_'
        : baseName.startsWith('sos_audio_')
            ? 'sos_audio_'
            : null;
    if (prefix == null) {
      return null;
    }

    final suffix = baseName.substring(prefix.length);
    final parts = suffix.split('_');
    if (parts.isEmpty || parts.first.isEmpty) {
      return null;
    }

    double? latitude;
    double? longitude;
    if (parts.length >= 4) {
      final parsedLat = double.tryParse(parts[parts.length - 2]);
      final parsedLon = double.tryParse(parts[parts.length - 1]);
      if (parsedLat != null &&
          parsedLon != null &&
          parsedLat.abs() <= 90 &&
          parsedLon.abs() <= 180) {
        latitude = parsedLat;
        longitude = parsedLon;
      }
    }

    return _IncidentInfo(
      incidentId: parts.first,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class _IncidentInfo {
  _IncidentInfo({
    required this.incidentId,
    required this.latitude,
    required this.longitude,
  });

  final String incidentId;
  final double? latitude;
  final double? longitude;
}
