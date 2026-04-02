import 'package:cloud_firestore/cloud_firestore.dart';

class SosAlert {
  const SosAlert({
    required this.id,
    required this.sosId,
    required this.sourceUserId,
    required this.sourceName,
    required this.sourcePhone,
    required this.relation,
    required this.status,
    required this.timestamp,
    required this.location,
    required this.mediaUrl,
    required this.assignedStationId,
    required this.assignedStationName,
    required this.assignedStationContactNumber,
    required this.isRead,
  });

  final String id;
  final String sosId;
  final String sourceUserId;
  final String sourceName;
  final String sourcePhone;
  final String relation;
  final String status;
  final DateTime? timestamp;
  final GeoPoint? location;
  final String? mediaUrl;
  final String? assignedStationId;
  final String? assignedStationName;
  final String? assignedStationContactNumber;
  final bool isRead;

  bool get isActive => status.toLowerCase() == 'active';

  factory SosAlert.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final mediaUrl = (data['mediaUrl'] as String?)?.trim();
    return SosAlert(
      id: doc.id,
      sosId: (data['sosId'] as String?) ?? '',
      sourceUserId: (data['sourceUserId'] as String?) ?? '',
      sourceName: (data['sourceName'] as String?) ?? 'Emergency contact',
      sourcePhone: (data['sourcePhone'] as String?) ?? '',
      relation: (data['relation'] as String?) ?? '',
      status: ((data['status'] as String?) ?? 'active').toLowerCase(),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      location: data['location'] as GeoPoint?,
      mediaUrl: mediaUrl == null || mediaUrl.isEmpty ? null : mediaUrl,
      assignedStationId: data['assignedStationId'] as String?,
      assignedStationName: _trimToNull(data['assignedStationName']),
      assignedStationContactNumber: _trimToNull(
        data['assignedStationContactNumber'],
      ),
      isRead: (data['isRead'] as bool?) ?? false,
    );
  }

  static String? _trimToNull(dynamic value) {
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
