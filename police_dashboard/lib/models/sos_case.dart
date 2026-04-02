import 'package:cloud_firestore/cloud_firestore.dart';

class SosCase {
  const SosCase({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.location,
    required this.lat,
    required this.lon,
    required this.mediaUrl,
    required this.localMediaPath,
    required this.status,
    required this.triggerSource,
    required this.recordingStatus,
    required this.recordingFailureReason,
    required this.assignedStationId,
    required this.lastLocationUpdateAt,
    required this.cancelledAt,
    required this.resolvedAt,
    required this.resolvedBy,
    required this.resolutionReport,
  });

  final String id;
  final String userId;
  final DateTime? timestamp;
  final GeoPoint? location;
  final double? lat;
  final double? lon;
  final String mediaUrl;
  final String localMediaPath;
  final String status;
  final String triggerSource;
  final String recordingStatus;
  final String? recordingFailureReason;
  final String? assignedStationId;
  final DateTime? lastLocationUpdateAt;
  final DateTime? cancelledAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionReport;

  bool get isActive => status == 'active';

  double? get resolvedLatitude => location?.latitude ?? lat;

  double? get resolvedLongitude => location?.longitude ?? lon;

  String? get googleMapsUrl {
    final latitude = resolvedLatitude;
    final longitude = resolvedLongitude;
    if (latitude == null || longitude == null) {
      return null;
    }
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  factory SosCase.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final lat = _readDouble(data['lat']);
    final lon = _readDouble(data['lon']);
    return SosCase(
      id: doc.id,
      userId: _readString(data['userId']) ?? '',
      timestamp: _readDateTime(data['timestamp']),
      location: _readLocation(data['location'], lat: lat, lon: lon),
      lat: lat,
      lon: lon,
      mediaUrl: _readString(data['mediaUrl']) ?? _readString(data['videoUrl']) ?? '',
      localMediaPath: _readString(data['localMediaPath']) ?? '',
      status: ((data['status'] as String?) ?? 'active').toLowerCase(),
      triggerSource: _readString(data['triggerSource']) ?? '',
      recordingStatus: _readString(data['recordingStatus']) ?? '',
      recordingFailureReason: _readString(data['recordingFailureReason']),
      assignedStationId: _readString(data['assignedStationId']),
      lastLocationUpdateAt: _readDateTime(data['lastLocationUpdateAt']),
      cancelledAt: _readDateTime(data['cancelledAt']),
      resolvedAt: _readDateTime(data['resolvedAt']),
      resolvedBy: _readString(data['resolvedBy']),
      resolutionReport: _readString(data['resolutionReport']),
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static GeoPoint? _readLocation(
    dynamic value, {
    required double? lat,
    required double? lon,
  }) {
    if (value is GeoPoint) {
      return value;
    }
    if (value is Map) {
      final mapLat = _readDouble(value['latitude'] ?? value['lat']);
      final mapLon = _readDouble(value['longitude'] ?? value['lon']);
      if (mapLat != null && mapLon != null) {
        return GeoPoint(mapLat, mapLon);
      }
    }
    if (lat != null && lon != null) {
      return GeoPoint(lat, lon);
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

  static String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
