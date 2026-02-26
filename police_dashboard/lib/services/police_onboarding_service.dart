import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/police_registration_request.dart';

class PoliceOnboardingService {
  PoliceOnboardingService._();

  static final PoliceOnboardingService instance = PoliceOnboardingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<List<PoliceRegistrationRequest>> watchPendingRequests() {
    return _firestore
        .collection('police_registration_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map(PoliceRegistrationRequest.fromDoc)
          .toList(growable: false);
      requests.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return requests;
    });
  }

  Future<String> uploadIdProof({
    required String fileName,
    required List<int> bytes,
  }) async {
    final cleanName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ref = _storage.ref().child(
          'police_id_proofs/${DateTime.now().millisecondsSinceEpoch}_$cleanName',
        );
    await ref.putData(Uint8List.fromList(bytes));
    return ref.getDownloadURL();
  }

  Future<void> submitPoliceRegistration({
    required String officerName,
    required String policeId,
    required String email,
    required String stationName,
    required String contactNumber,
    required double latitude,
    required double longitude,
    required double jurisdictionRadius,
    String? idProofUrl,
  }) async {
    final callable =
        _functions.httpsCallable('submitPoliceRegistrationRequest');
    await callable.call(<String, dynamic>{
      'officerName': officerName,
      'policeId': policeId,
      'email': email,
      'stationName': stationName,
      'contactNumber': contactNumber,
      'latitude': latitude,
      'longitude': longitude,
      'jurisdictionRadius': jurisdictionRadius,
      'idProofUrl': idProofUrl,
    });
  }

  Future<void> approveRequest(String requestId) async {
    final callable =
        _functions.httpsCallable('approvePoliceRegistrationRequest');
    await callable.call(<String, dynamic>{
      'requestId': requestId,
    });
  }

  Future<void> rejectRequest({
    required String requestId,
    String? reason,
  }) async {
    final callable =
        _functions.httpsCallable('rejectPoliceRegistrationRequest');
    await callable.call(<String, dynamic>{
      'requestId': requestId,
      'reason': reason,
    });
  }
}
