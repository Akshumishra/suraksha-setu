import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      if (currentUser == null) {
        return;
      }

      final firestore = FirebaseFirestore.instance;
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
          final metadata = await _loadOfflineMetadata(
            supportDir: supportDir,
            incidentId: incidentId,
          );
          final latitude = metadata?.latitude ?? incidentInfo.latitude;
          final longitude = metadata?.longitude ?? incidentInfo.longitude;
          AssignedPoliceStation? assignedStation = metadata?.assignedStation;
          if ((assignedStation == null ||
                  assignedStation.stationId.trim().isEmpty) &&
              latitude != null &&
              longitude != null) {
            assignedStation =
                await StationAssignmentService.instance.findNearestStation(
              latitude: latitude,
              longitude: longitude,
            );
          }

          try {
            final mediaUrl = await CloudinaryService.uploadMedia(file: file);
            final incidentRef = firestore.collection('sos').doc(incidentId);
            final incidentSnapshot = await incidentRef.get();

            if (incidentSnapshot.exists) {
              await incidentRef.update({
                'mediaUrl': mediaUrl,
              });
            } else {
              await incidentRef.set(
                _buildIncidentPayload(
                  currentUser: currentUser,
                  mediaUrl: mediaUrl,
                  latitude: latitude,
                  longitude: longitude,
                  metadata: metadata,
                  assignedStation: assignedStation,
                ),
              );
            }

            await _syncLinkedContactAlerts(
              userId: currentUser.uid,
              sosId: incidentId,
              mediaUrl: mediaUrl,
              latitude: latitude,
              longitude: longitude,
              metadata: metadata,
              assignedStation: assignedStation,
            );

            await file.delete();
            await _deleteOfflineMetadataIfPresent(
              supportDir: supportDir,
              incidentId: incidentId,
            );
          } catch (e, stackTrace) {
            debugPrint('SOS sync failed for ${file.path}: $e');
            debugPrintStack(stackTrace: stackTrace);
          }
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Map<String, Object?> _buildIncidentPayload({
    required User currentUser,
    required String mediaUrl,
    required double? latitude,
    required double? longitude,
    required _SosOfflineMetadata? metadata,
    required AssignedPoliceStation? assignedStation,
  }) {
    final payload = <String, Object?>{
      'userId': _trimToNull(metadata?.userId) ?? currentUser.uid,
      'timestamp': metadata?.createdAtEpochMs == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromMillisecondsSinceEpoch(metadata!.createdAtEpochMs!),
      'mediaUrl': mediaUrl,
      'status': 'active',
      'cancelledAt': null,
    };

    final triggerSource = _trimToNull(metadata?.triggerSource);
    if (triggerSource != null) {
      payload['triggerSource'] = triggerSource;
    }

    if (latitude != null && longitude != null) {
      payload['location'] = GeoPoint(latitude, longitude);
      payload['lat'] = latitude;
      payload['lon'] = longitude;
      payload['lastLocationUpdateAt'] = FieldValue.serverTimestamp();
    }

    final stationId = _trimToNull(
      assignedStation?.stationId.isEmpty == true
          ? metadata?.assignedStationId
          : assignedStation?.stationId,
    );
    if (stationId != null) {
      payload['assignedStationId'] = stationId;
    }

    return payload;
  }

  Future<void> _syncLinkedContactAlerts({
    required String userId,
    required String sosId,
    required String mediaUrl,
    required double? latitude,
    required double? longitude,
    required _SosOfflineMetadata? metadata,
    required AssignedPoliceStation? assignedStation,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final sourceProfile = await firestore.collection('users').doc(userId).get();
    final sourceData = sourceProfile.data() ?? <String, dynamic>{};
    final sourceName = _trimToNull(sourceData['name']) ?? 'Emergency contact';
    final sourcePhone = _trimToNull(sourceData['phone']) ?? '';
    final contactsSnapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('emergency_contacts')
        .get();

    if (contactsSnapshot.docs.isEmpty) {
      return;
    }

    final batch = firestore.batch();
    var targetCount = 0;
    for (final contactDoc in contactsSnapshot.docs) {
      final contactData = contactDoc.data();
      final targetUserId = _trimToNull(contactData['contactUserId']);
      if (targetUserId == null || targetUserId == userId) {
        continue;
      }

      final targetAlertRef = firestore
          .collection('users')
          .doc(targetUserId)
          .collection('incoming_sos')
          .doc(sosId);
      final existingAlert = await targetAlertRef.get();
      final payload = existingAlert.exists
          ? <String, dynamic>{'mediaUrl': mediaUrl}
          : <String, dynamic>{
              'sosId': sosId,
              'sourceUserId': userId,
              'sourceContactId': contactDoc.id,
              'sourceName': sourceName,
              'sourcePhone': sourcePhone,
              'relation': _trimToNull(contactData['relation']) ?? '',
              'status': 'active',
              'isRead': false,
              if (metadata?.createdAtEpochMs != null)
                'timestamp': Timestamp.fromMillisecondsSinceEpoch(
                  metadata!.createdAtEpochMs!,
                )
              else
                'timestamp': FieldValue.serverTimestamp(),
              if (latitude != null && longitude != null)
                'location': GeoPoint(latitude, longitude),
              'mediaUrl': mediaUrl,
            };

      final stationId = _trimToNull(
        assignedStation?.stationId.isEmpty == true
            ? metadata?.assignedStationId
            : assignedStation?.stationId,
      );
      final stationName = _trimToNull(
        assignedStation?.stationName ?? metadata?.assignedStationName,
      );
      final stationContactNumber = _trimToNull(
        assignedStation?.contactNumber ??
            metadata?.assignedStationContactNumber,
      );
      if (!existingAlert.exists) {
        if (stationId != null) {
          payload['assignedStationId'] = stationId;
        }
        if (stationName != null) {
          payload['assignedStationName'] = stationName;
        }
        if (stationContactNumber != null) {
          payload['assignedStationContactNumber'] = stationContactNumber;
        }
      }

      batch.set(targetAlertRef, payload, SetOptions(merge: true));
      targetCount++;
    }

    if (targetCount == 0) {
      return;
    }

    await batch.commit();
  }

  Future<_SosOfflineMetadata?> _loadOfflineMetadata({
    required Directory supportDir,
    required String incidentId,
  }) async {
    final metadataFile = _metadataFileForIncident(
      supportDir: supportDir,
      incidentId: incidentId,
    );
    if (!await metadataFile.exists()) {
      return null;
    }
    try {
      final raw = await metadataFile.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return _SosOfflineMetadata.fromJson(decoded);
    } catch (e, stackTrace) {
      debugPrint('Failed to read SOS offline metadata for $incidentId: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _deleteOfflineMetadataIfPresent({
    required Directory supportDir,
    required String incidentId,
  }) async {
    final metadataFile = _metadataFileForIncident(
      supportDir: supportDir,
      incidentId: incidentId,
    );
    if (!await metadataFile.exists()) {
      return;
    }
    try {
      await metadataFile.delete();
    } catch (e, stackTrace) {
      debugPrint('Failed to delete SOS offline metadata for $incidentId: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  File _metadataFileForIncident({
    required Directory supportDir,
    required String incidentId,
  }) {
    return File(
      p.join(supportDir.path, 'sos_metadata', '$incidentId.json'),
    );
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

  String? _trimToNull(dynamic value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class _SosOfflineMetadata {
  const _SosOfflineMetadata({
    required this.sosId,
    required this.userId,
    required this.triggerSource,
    required this.createdAtEpochMs,
    required this.localMediaPath,
    required this.latitude,
    required this.longitude,
    required this.assignedStationId,
    required this.assignedStationName,
    required this.assignedStationContactNumber,
  });

  final String sosId;
  final String? userId;
  final String? triggerSource;
  final int? createdAtEpochMs;
  final String? localMediaPath;
  final double? latitude;
  final double? longitude;
  final String? assignedStationId;
  final String? assignedStationName;
  final String? assignedStationContactNumber;

  AssignedPoliceStation? get assignedStation {
    final stationId = assignedStationId?.trim() ?? '';
    final stationName = assignedStationName?.trim();
    final contactNumber = assignedStationContactNumber?.trim();
    if (stationId.isEmpty &&
        (stationName == null || stationName.isEmpty) &&
        (contactNumber == null || contactNumber.isEmpty)) {
      return null;
    }
    return AssignedPoliceStation(
      stationId: stationId,
      stationName: stationName,
      contactNumber: contactNumber,
    );
  }

  factory _SosOfflineMetadata.fromJson(Map<String, dynamic> json) {
    return _SosOfflineMetadata(
      sosId: (json['sosId'] as String?)?.trim() ?? '',
      userId: (json['userId'] as String?)?.trim(),
      triggerSource: (json['triggerSource'] as String?)?.trim(),
      createdAtEpochMs: _readInt(json['createdAtEpochMs']),
      localMediaPath: (json['localMediaPath'] as String?)?.trim(),
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      assignedStationId: (json['assignedStationId'] as String?)?.trim(),
      assignedStationName: (json['assignedStationName'] as String?)?.trim(),
      assignedStationContactNumber:
          (json['assignedStationContactNumber'] as String?)?.trim(),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static double? _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
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
