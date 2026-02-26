import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/police_station.dart';

class PoliceStationService {
  PoliceStationService._();

  static final PoliceStationService instance = PoliceStationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<PoliceStation>> watchStations() {
    return _firestore
        .collection('police_stations')
        .orderBy('stationName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(PoliceStation.fromDoc).toList(growable: false),
        );
  }

  Future<void> createStation({
    required String stationName,
    required double latitude,
    required double longitude,
    required String contactNumber,
    required double jurisdictionRadius,
  }) async {
    final payload = PoliceStation(
      id: '',
      stationName: stationName,
      latitude: latitude,
      longitude: longitude,
      contactNumber: contactNumber,
      jurisdictionRadius: jurisdictionRadius,
    ).toMap();

    await _firestore.collection('police_stations').add(payload);
  }
}
