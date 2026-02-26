import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sos_alert.dart';

class SosAlertService {
  SosAlertService._();

  static final SosAlertService instance = SosAlertService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _requireUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _alertsCollectionForUser(
    String userId,
  ) {
    return _firestore.collection('users').doc(userId).collection('incoming_sos');
  }

  Stream<List<SosAlert>> watchIncomingAlerts() {
    final userId = _requireUserId();
    return _alertsCollectionForUser(userId).snapshots().map((snapshot) {
      final alerts = snapshot.docs.map(SosAlert.fromDoc).toList(growable: false);
      alerts.sort((a, b) {
        final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
        final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return alerts;
    });
  }

  Future<void> markAsRead(String alertId) async {
    final userId = _requireUserId();
    await _alertsCollectionForUser(userId).doc(alertId).update(
      <String, dynamic>{'isRead': true},
    );
  }
}
