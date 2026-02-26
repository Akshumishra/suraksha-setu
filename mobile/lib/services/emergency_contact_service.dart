import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/emergency_contact.dart';

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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmergencyContact.fromDoc(doc))
              .toList(growable: false),
    );
  }

  Future<AppUserContactProfile> findAppUserByEmail(String email) async {
    final currentUserId = _requireUserId();
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw StateError('App user email is required.');
    }

    final snapshot = await _usersCollection
        .where('email', isEqualTo: normalizedEmail)
        .where('role', isEqualTo: 'user')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      throw StateError('No app user found for the provided email.');
    }

    final doc = snapshot.docs.first;
    if (doc.id == currentUserId) {
      throw StateError('You cannot add your own account as emergency contact.');
    }

    final data = doc.data();
    final name = (data['name'] as String?)?.trim();
    final phone = (data['phone'] as String?)?.trim();
    final profileEmail = (data['email'] as String?)?.trim().toLowerCase();
    return AppUserContactProfile(
      userId: doc.id,
      name: name == null || name.isEmpty ? 'App User' : name,
      phone: phone ?? '',
      email: profileEmail == null || profileEmail.isEmpty
          ? normalizedEmail
          : profileEmail,
    );
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
  }

  Future<void> deleteContact(String contactId) async {
    final userId = _requireUserId();
    await _collectionForUser(userId).doc(contactId).delete();
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
