import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/emergency_contact.dart';
import 'sos_local_cache_service.dart';

class AppUserContactProfile {
  const AppUserContactProfile({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
  });

  final String userId;
  final String name;
  final String phone;
  final String email;
}

class EmergencyContactService {
  EmergencyContactService._();

  static final EmergencyContactService instance = EmergencyContactService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collectionForUser(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('emergency_contacts');
  }

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  String _requireUserId() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to manage emergency contacts.');
    }
    return user.uid;
  }

  Stream<List<EmergencyContact>> watchContacts() {
    final userId = _requireUserId();
    return _collectionForUser(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final contacts = snapshot.docs
          .map((doc) => EmergencyContact.fromDoc(doc))
          .toList(growable: false);
      unawaited(
        SosLocalCacheService.instance
            .cacheEmergencyContacts(userId: userId, contacts: contacts)
            .catchError((error, stackTrace) {
          debugPrint('Failed to cache emergency contacts: $error');
        }),
      );
      return contacts;
    });
  }

  Future<void> refreshLocalCache() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    try {
      final snapshot = await _collectionForUser(userId)
          .orderBy('createdAt', descending: true)
          .get();
      final contacts = snapshot.docs
          .map((doc) => EmergencyContact.fromDoc(doc))
          .toList(growable: false);
      await SosLocalCacheService.instance.cacheEmergencyContacts(
        userId: userId,
        contacts: contacts,
      );
    } catch (error, stackTrace) {
      debugPrint('Emergency contact cache refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<AppUserContactProfile> findAppUserByEmail(String email) async {
    final currentUserId = _requireUserId();
    final rawEmail = email.trim();
    final normalizedEmail = rawEmail.toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw StateError('App user email is required.');
    }

    final doc = await _findLinkedAppUserDoc(
      rawEmail: rawEmail,
      normalizedEmail: normalizedEmail,
    );
    if (doc == null) {
      throw StateError('No app user found for the provided email.');
    }

    if (doc.id == currentUserId) {
      throw StateError('You cannot add your own account as emergency contact.');
    }

    final data = doc.data();
    final name = _normalizedString(data['name']);
    final phone = _normalizedString(data['phone']);
    final profileEmail = _normalizedEmailString(data['email']);
    return AppUserContactProfile(
      userId: doc.id,
      name: name ?? 'App User',
      phone: phone ?? '',
      email: profileEmail ?? normalizedEmail,
    );
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findLinkedAppUserDoc({
    required String rawEmail,
    required String normalizedEmail,
  }) async {
    for (final candidate in <String>{rawEmail, normalizedEmail}) {
      final directMatch = await _findUserDocByExactEmail(candidate);
      if (directMatch != null) {
        return directMatch;
      }
    }

    // Fallback for older profiles saved with mixed-case emails or when
    // the compound email+role query is unavailable.
    final fallbackSnapshot =
        await _usersCollection.where('role', isEqualTo: 'user').get();
    for (final doc in fallbackSnapshot.docs) {
      if (_normalizedEmailString(doc.data()['email']) == normalizedEmail) {
        return doc;
      }
    }
    return null;
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserDocByExactEmail(
    String email,
  ) async {
    final candidate = email.trim();
    if (candidate.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _usersCollection
          .where('email', isEqualTo: candidate)
          .where('role', isEqualTo: 'user')
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      return snapshot.docs.first;
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }
      return null;
    }
  }

  String? _normalizedString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizedEmailString(dynamic value) {
    final normalized = _normalizedString(value);
    if (normalized == null) {
      return null;
    }
    return normalized.toLowerCase();
  }

  Future<void> addContact({
    required String name,
    required String phone,
    required String relation,
    String? contactUserId,
    String? contactEmail,
  }) async {
    final userId = _requireUserId();
    final contact = EmergencyContact(
      id: '',
      name: name,
      phone: phone,
      relation: relation,
      contactUserId: _normalizedOrNull(contactUserId),
      contactEmail: _normalizedEmailOrNull(contactEmail),
      createdAt: null,
    );
    await _collectionForUser(userId).add(contact.toCreatePayload());
    unawaited(refreshLocalCache());
  }

  Future<void> updateContact({
    required String contactId,
    required String name,
    required String phone,
    required String relation,
    String? contactUserId,
    String? contactEmail,
  }) async {
    final userId = _requireUserId();
    final contact = EmergencyContact(
      id: contactId,
      name: name,
      phone: phone,
      relation: relation,
      contactUserId: _normalizedOrNull(contactUserId),
      contactEmail: _normalizedEmailOrNull(contactEmail),
      createdAt: null,
    );
    await _collectionForUser(userId)
        .doc(contactId)
        .update(contact.toUpdatePayload());
    unawaited(refreshLocalCache());
  }

  Future<void> deleteContact(String contactId) async {
    final userId = _requireUserId();
    await _collectionForUser(userId).doc(contactId).delete();
    unawaited(refreshLocalCache());
  }

  String? _normalizedOrNull(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizedEmailOrNull(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
