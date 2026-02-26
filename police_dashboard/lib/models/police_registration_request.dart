import 'package:cloud_firestore/cloud_firestore.dart';

class PoliceRegistrationRequest {
  const PoliceRegistrationRequest({
    required this.id,
    required this.officerName,
    required this.policeId,
    required this.email,
    required this.stationName,
    required this.contactNumber,
    required this.latitude,
    required this.longitude,
    required this.jurisdictionRadius,
    required this.status,
    required this.createdAt,
    required this.idProofUrl,
  });

  final String id;
  final String officerName;
  final String policeId;
  final String email;
  final String stationName;
  final String contactNumber;
  final double latitude;
  final double longitude;
  final double jurisdictionRadius;
  final String status;
  final DateTime? createdAt;
  final String? idProofUrl;

  factory PoliceRegistrationRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return PoliceRegistrationRequest(
      id: doc.id,
      officerName: (data['officerName'] as String?) ?? '',
      policeId: (data['policeId'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      stationName: (data['stationName'] as String?) ?? '',
      contactNumber: (data['contactNumber'] as String?) ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      jurisdictionRadius: (data['jurisdictionRadius'] as num?)?.toDouble() ?? 0,
      status: ((data['status'] as String?) ?? 'pending').toLowerCase(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      idProofUrl: data['idProofUrl'] as String?,
    );
  }
}
