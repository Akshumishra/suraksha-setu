import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

class StationAssignmentService {
  StationAssignmentService._();

  static final StationAssignmentService instance = StationAssignmentService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> findNearestStationId({
    required double latitude,
    required double longitude,
  }) async {
    final snapshot = await _firestore.collection('police_stations').get();
    if (snapshot.docs.isEmpty) {
      return null;
    }

    String? nearestStationId;
    double nearestDistanceKm = double.infinity;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final stationLat = (data['latitude'] as num?)?.toDouble();
      final stationLon = (data['longitude'] as num?)?.toDouble();
      final radiusKm = (data['jurisdictionRadius'] as num?)?.toDouble();
      if (stationLat == null || stationLon == null) {
        continue;
      }

      final distanceKm = _haversineKm(
        fromLat: latitude,
        fromLon: longitude,
        toLat: stationLat,
        toLon: stationLon,
      );

      final isWithinJurisdiction = radiusKm == null || distanceKm <= radiusKm;
      if (!isWithinJurisdiction) {
        continue;
      }

      if (distanceKm < nearestDistanceKm) {
        nearestDistanceKm = distanceKm;
        nearestStationId = doc.id;
      }
    }

    if (nearestStationId != null) {
      return nearestStationId;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final stationLat = (data['latitude'] as num?)?.toDouble();
      final stationLon = (data['longitude'] as num?)?.toDouble();
      if (stationLat == null || stationLon == null) {
        continue;
      }

      final distanceKm = _haversineKm(
        fromLat: latitude,
        fromLon: longitude,
        toLat: stationLat,
        toLon: stationLon,
      );
      if (distanceKm < nearestDistanceKm) {
        nearestDistanceKm = distanceKm;
        nearestStationId = doc.id;
      }
    }

    return nearestStationId;
  }

  double _haversineKm({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(toLat - fromLat);
    final dLon = _degToRad(toLon - fromLon);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(fromLat)) *
            math.cos(_degToRad(toLat)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double degree) => degree * (math.pi / 180);
}
