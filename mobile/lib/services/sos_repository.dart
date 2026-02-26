import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/sos_config.dart';
import '../models/sos_case.dart';

class SosRepository {
  SosRepository._();

  static final SosRepository instance = SosRepository._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sosCollection =>
      _firestore.collection('sos');

  String _requireUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in.');
    }
    return user.uid;
  }

  Stream<List<SosCase>> watchUserSosHistory() {
    final userId = _requireUserId();
    return _sosCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) {
            final items =
                snapshot.docs.map(SosCase.fromDoc).toList(growable: false);
            items.sort((a, b) {
              final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
              final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
              return bTime.compareTo(aTime);
            });
            return items;
          },
        );
  }

  Future<void> cancelSos({
    required String sosId,
    Duration cancelWindow = SosConfig.cancelWindow,
  }) async {
    final userId = _requireUserId();
    final sosRef = _sosCollection.doc(sosId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(sosRef);
      if (!snapshot.exists) {
        throw StateError('SOS case not found.');
      }
      final data = snapshot.data() ?? <String, dynamic>{};

      if (data['userId'] != userId) {
        throw StateError('Unauthorized SOS cancellation.');
      }

      final status = ((data['status'] as String?) ?? '').toLowerCase();
      if (status == 'accepted' || status == 'resolved') {
        throw StateError('SOS cannot be cancelled after police acceptance.');
      }
      if (status != 'active') {
        throw StateError('Only active SOS can be cancelled.');
      }

      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null &&
          DateTime.now().difference(timestamp) > cancelWindow) {
        throw StateError('Cancellation window has expired.');
      }

      transaction.update(sosRef, <String, dynamic>{
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelLatestActiveSos({
    Duration cancelWindow = SosConfig.cancelWindow,
  }) async {
    final userId = _requireUserId();
    final snapshot =
        await _sosCollection.where('userId', isEqualTo: userId).get();
    final activeCases = snapshot.docs
        .map(SosCase.fromDoc)
        .where((record) => record.isActive)
        .toList(growable: false)
      ..sort((a, b) {
        final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
        final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });

    if (activeCases.isEmpty) {
      throw StateError('No active SOS available to cancel.');
    }

    await cancelSos(
      sosId: activeCases.first.id,
      cancelWindow: cancelWindow,
    );
  }
}
