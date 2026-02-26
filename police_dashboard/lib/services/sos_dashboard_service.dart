import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sos_case.dart';

class SosDashboardService {
  SosDashboardService._();

  static final SosDashboardService instance = SosDashboardService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SosCase>> watchAssignedCases(String stationId) {
    return _firestore
        .collection('sos')
        .where('assignedStationId', isEqualTo: stationId)
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map(SosCase.fromDoc).toList(growable: false);
      items.sort((a, b) {
        final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
        final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return items;
    });
  }

  Stream<SosCase?> watchCaseById(String caseId) {
    return _firestore.collection('sos').doc(caseId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return SosCase.fromDoc(doc);
    });
  }

  Future<void> updateStatus({
    required String caseId,
    required String status,
  }) async {
    await _firestore.collection('sos').doc(caseId).update(<String, dynamic>{
      'status': status.toLowerCase(),
    });
  }
}
