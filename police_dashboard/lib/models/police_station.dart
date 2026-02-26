import 'package:cloud_firestore/cloud_firestore.dart';

class PoliceStation {
  const PoliceStation({
    required this.id,
    required this.stationName,
    required this.latitude,
    required this.longitude,
    required this.contactNumber,
    required this.jurisdictionRadius,
  });

  final String id;
  final String stationName;
  final double latitude;
  final double longitude;
  final String contactNumber;
  final double jurisdictionRadius;

  factory PoliceStation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return PoliceStation(
      id: doc.id,
      stationName: (data['stationName'] as String?) ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      contactNumber: (data['contactNumber'] as String?) ?? '',
      jurisdictionRadius: (data['jurisdictionRadius'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'stationName': stationName.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'contactNumber': contactNumber.trim(),
      'jurisdictionRadius': jurisdictionRadius,
    };
  }
}
