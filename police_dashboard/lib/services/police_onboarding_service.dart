import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../firebase_options.dart';
import '../models/police_registration_request.dart';

class PoliceOnboardingService {
  PoliceOnboardingService._();

  static final PoliceOnboardingService instance = PoliceOnboardingService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _normalizePoliceId(String policeId) {
    return policeId.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');
  }

  Map<String, dynamic> _buildRegistrationPayload({
    required String officerName,
    required String policeId,
    required String email,
    required String stationName,
    required String contactNumber,
    required double latitude,
    required double longitude,
    required double jurisdictionRadius,
    String? idProofUrl,
  }) {
    return <String, dynamic>{
      'officerName': officerName.trim(),
      'policeId': _normalizePoliceId(policeId),
      'email': email.trim().toLowerCase(),
      'stationName': stationName.trim(),
      'contactNumber': contactNumber.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'jurisdictionRadius': jurisdictionRadius,
      'idProofUrl': idProofUrl?.trim().isEmpty ?? true ? null : idProofUrl!.trim(),
    };
  }

  Map<String, dynamic> _coerceStoredRegistrationPayload(
    Map<String, dynamic> data,
  ) {
    final payload = _buildRegistrationPayload(
      officerName: (data['officerName'] as String?) ?? '',
      policeId: (data['policeId'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      stationName: (data['stationName'] as String?) ?? '',
      contactNumber: (data['contactNumber'] as String?) ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? double.nan,
      longitude: (data['longitude'] as num?)?.toDouble() ?? double.nan,
      jurisdictionRadius:
          (data['jurisdictionRadius'] as num?)?.toDouble() ?? double.nan,
      idProofUrl: data['idProofUrl'] as String?,
    );

    final officerName = payload['officerName'] as String;
    final policeId = payload['policeId'] as String;
    final email = payload['email'] as String;
    final stationName = payload['stationName'] as String;
    final contactNumber = payload['contactNumber'] as String;
    final latitude = payload['latitude'] as double;
    final longitude = payload['longitude'] as double;
    final jurisdictionRadius = payload['jurisdictionRadius'] as double;

    if (officerName.isEmpty ||
        policeId.isEmpty ||
        email.isEmpty ||
        stationName.isEmpty ||
        contactNumber.isEmpty) {
      throw StateError('Registration request is missing required fields.');
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw StateError('Registration request has an invalid latitude.');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw StateError('Registration request has an invalid longitude.');
    }
    if (!jurisdictionRadius.isFinite || jurisdictionRadius <= 0) {
      throw StateError('Registration request has an invalid radius.');
    }

    return payload;
  }

  bool _shouldFallbackFromCallable(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'not-found':
      case 'unimplemented':
      case 'internal':
      case 'unavailable':
      case 'deadline-exceeded':
        return true;
      default:
        return false;
    }
  }

  String _generateTemporaryPassword({int length = 18}) {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = '!@#%^*()-_=+';
    const allChars = upper + lower + digits + symbols;
    final random = Random.secure();

    final passwordChars = <String>[
      upper[random.nextInt(upper.length)],
      lower[random.nextInt(lower.length)],
      digits[random.nextInt(digits.length)],
      symbols[random.nextInt(symbols.length)],
    ];

    while (passwordChars.length < length) {
      passwordChars.add(allChars[random.nextInt(allChars.length)]);
    }

    passwordChars.shuffle(random);
    return passwordChars.join();
  }

  Future<T> _withSecondaryFirebaseApp<T>(
    Future<T> Function(
      FirebaseAuth secondaryAuth,
      FirebaseFirestore secondaryFirestore,
    )
    operation,
  ) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'police_onboarding_${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final secondaryFirestore = FirebaseFirestore.instanceFor(app: secondaryApp);

    try {
      return await operation(secondaryAuth, secondaryFirestore);
    } finally {
      try {
        await secondaryAuth.signOut();
      } catch (_) {}
      try {
        await secondaryApp.delete();
      } catch (_) {}
    }
  }

  Future<void> _createRegistrationRequestDirectly(
    Map<String, dynamic> payload,
  ) async {
    final policeId = payload['policeId'] as String? ?? '';
    if (policeId.isEmpty) {
      throw StateError('Police ID is required.');
    }

    final requestRef = _firestore
        .collection('police_registration_requests')
        .doc(policeId);
    // Public clients cannot read registration requests, so the fallback must
    // avoid transactions or existence checks that would require read access.
    try {
      await requestRef.set(<String, dynamic>{
        ...payload,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError(
          'A registration request already exists for this Police ID. Please wait for admin approval or use a different Police ID.',
        );
      }
      rethrow;
    }
  }

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

  Future<void> _approveRequestDirectly(String requestId) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) {
      throw StateError('Please log in again to continue.');
    }

    final requestRef = _firestore
        .collection('police_registration_requests')
        .doc(requestId);
    final registration = await requestRef.get();
    if (!registration.exists) {
      throw StateError('Registration request not found.');
    }

    final data = registration.data() ?? <String, dynamic>{};
    final status = ((data['status'] as String?) ?? 'pending').trim().toLowerCase();
    if (status != 'pending') {
      throw StateError('Only pending requests can be approved.');
    }

    final payload = _coerceStoredRegistrationPayload(data);
    final policeId = payload['policeId'] as String;
    final email = payload['email'] as String;
    final officerName = payload['officerName'] as String;

    final duplicateStation = await _firestore
        .collection('police_stations')
        .where('policeId', isEqualTo: policeId)
        .limit(1)
        .get();
    if (duplicateStation.docs.isNotEmpty) {
      throw StateError('This police ID already has a station record.');
    }

    final stationRef = _firestore.collection('police_stations').doc();
    final temporaryPassword = _generateTemporaryPassword();

    await _withSecondaryFirebaseApp((secondaryAuth, secondaryFirestore) async {
      UserCredential credential;
      try {
        credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: temporaryPassword,
        );
      } on FirebaseAuthException catch (error) {
        if (error.code == 'email-already-in-use') {
          throw StateError('An account already exists for this email.');
        }
        rethrow;
      }

      final user = credential.user;
      if (user == null) {
        throw StateError('Failed to create the police account.');
      }

      try {
        await user.updateDisplayName(officerName);
        await secondaryFirestore.collection('users').doc(user.uid).set(
          <String, dynamic>{
            'email': email,
            'officerName': officerName,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );

        var emailDeliveryStatus = 'password-reset-sent';
        String? emailError;
        try {
          await _auth.sendPasswordResetEmail(email: email);
        } on FirebaseAuthException catch (error) {
          emailDeliveryStatus = 'password-reset-failed';
          emailError = error.message?.trim().isNotEmpty == true
              ? error.message!.trim()
              : error.code;
        }

        final batch = _firestore.batch();
        batch.set(stationRef, <String, dynamic>{
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(_firestore.collection('users').doc(user.uid), <String, dynamic>{
          'role': 'police',
          'stationId': stationRef.id,
          'policeId': policeId,
          'email': email,
          'officerName': officerName,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        final requestUpdate = <String, dynamic>{
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': adminUid,
          'policeUid': user.uid,
          'stationId': stationRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
          'emailDeliveryStatus': emailDeliveryStatus,
        };
        if (emailDeliveryStatus == 'password-reset-sent') {
          requestUpdate['credentialsSentAt'] = FieldValue.serverTimestamp();
        }
        if (emailError != null) {
          requestUpdate['emailError'] = emailError;
        }
        batch.update(requestRef, requestUpdate);

        await batch.commit();
      } catch (error) {
        try {
          await _firestore.collection('users').doc(user.uid).delete();
        } catch (_) {}
        try {
          await user.delete();
        } catch (_) {}
        rethrow;
      }
    });
  }

  Future<void> _rejectRequestDirectly({
    required String requestId,
    String? reason,
  }) async {
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) {
      throw StateError('Please log in again to continue.');
    }

    final requestRef = _firestore
        .collection('police_registration_requests')
        .doc(requestId);
    final registration = await requestRef.get();
    if (!registration.exists) {
      throw StateError('Registration request not found.');
    }

    final data = registration.data() ?? <String, dynamic>{};
    final status = ((data['status'] as String?) ?? 'pending').trim().toLowerCase();
    if (status != 'pending') {
      throw StateError('Only pending requests can be rejected.');
    }

    final normalizedReason = reason?.trim();
    await requestRef.update(<String, dynamic>{
      'status': 'rejected',
      'rejectedBy': adminUid,
      'rejectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (normalizedReason != null && normalizedReason.isNotEmpty)
        'rejectionReason': normalizedReason,
    });
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
    final payload = _buildRegistrationPayload(
      officerName: officerName,
      policeId: policeId,
      email: email,
      stationName: stationName,
      contactNumber: contactNumber,
      latitude: latitude,
      longitude: longitude,
      jurisdictionRadius: jurisdictionRadius,
      idProofUrl: idProofUrl,
    );

    try {
      final callable =
          _functions.httpsCallable('submitPoliceRegistrationRequest');
      await callable.call(payload);
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldFallbackFromCallable(error)) {
        rethrow;
      }
      await _createRegistrationRequestDirectly(payload);
    }
  }

  Future<void> approveRequest(String requestId) async {
    try {
      final callable =
          _functions.httpsCallable('approvePoliceRegistrationRequest');
      await callable.call(<String, dynamic>{
        'requestId': requestId,
      });
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldFallbackFromCallable(error)) {
        rethrow;
      }
      await _approveRequestDirectly(requestId);
    }
  }

  Future<void> rejectRequest({
    required String requestId,
    String? reason,
  }) async {
    try {
      final callable =
          _functions.httpsCallable('rejectPoliceRegistrationRequest');
      await callable.call(<String, dynamic>{
        'requestId': requestId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldFallbackFromCallable(error)) {
        rethrow;
      }
      await _rejectRequestDirectly(
        requestId: requestId,
        reason: reason,
      );
    }
  }
}
