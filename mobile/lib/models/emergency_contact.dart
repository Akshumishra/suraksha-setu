import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.contactUserId,
    required this.contactEmail,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String relation;
  final String? contactUserId;
  final String? contactEmail;
  final DateTime? createdAt;

  bool get isLinkedAppUser =>
      (contactUserId?.trim().isNotEmpty ?? false);

  factory EmergencyContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final contactUserId = (data['contactUserId'] as String?)?.trim();
    final contactEmail = (data['contactEmail'] as String?)?.trim();
    return EmergencyContact(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      relation: (data['relation'] as String?)?.trim() ?? '',
      contactUserId:
          contactUserId == null || contactUserId.isEmpty ? null : contactUserId,
      contactEmail:
          contactEmail == null || contactEmail.isEmpty ? null : contactEmail,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toCreatePayload() {
    return <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'relation': relation.trim(),
      'contactUserId': contactUserId?.trim(),
      'contactEmail': contactEmail?.trim().toLowerCase(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return <String, dynamic>{
      'name': name.trim(),
      'phone': phone.trim(),
      'relation': relation.trim(),
      'contactUserId': contactUserId?.trim(),
      'contactEmail': contactEmail?.trim().toLowerCase(),
    };
  }
}
