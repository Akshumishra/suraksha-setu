import 'package:cloud_firestore/cloud_firestore.dart';

class SosCase {
  const SosCase({
    required this.id,
    required this.userId,
    required this.location,
    required this.timestamp,
    required this.mediaUrl,
    required this.status,
    required this.assignedStationId,
    required this.cancelledAt,
  });

  final String id;
  final String userId;
  final GeoPoint? location;
  final DateTime? timestamp;
  final String? mediaUrl;
  final String status;
  final String? assignedStationId;
  final DateTime? cancelledAt;

  bool get isActive => status.toLowerCase() == 'active';
  bool get isAccepted => status.toLowerCase() == 'accepted';
  bool get isResolved => status.toLowerCase() == 'resolved';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get hasMediaUrl => mediaUrl != null && mediaUrl!.isNotEmpty;

  factory SosCase.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return SosCase(
      id: doc.id,
      userId: (data['userId'] as String?) ?? '',
      location: data['location'] as GeoPoint?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      mediaUrl: _trimToNull(data['mediaUrl']),
      status: ((data['status'] as String?) ?? 'active').toLowerCase(),
      assignedStationId: data['assignedStationId'] as String?,
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
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
