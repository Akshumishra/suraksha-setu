import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/admin_sos_analysis_result.dart';
import '../models/sos_analytics_snapshot.dart';
import '../models/sos_case.dart';
import '../models/sos_case_detail.dart';
import '../models/police_station.dart';
import 'police_auth_service.dart';

class SosDashboardService {
  SosDashboardService._();

  static final SosDashboardService instance = SosDashboardService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<List<SosCase>> watchAssignedCases(String stationId) {
    return _firestore
        .collection('sos')
        .where('assignedStationId', isEqualTo: stationId)
        .snapshots()
        .map((snapshot) => _sortCases(snapshot.docs.map(SosCase.fromDoc)));
  }

  Stream<List<SosCase>> watchAllCases() {
    return _firestore
        .collection('sos')
        .snapshots()
        .map((snapshot) => _sortCases(snapshot.docs.map(SosCase.fromDoc)));
  }

  Future<AdminSosAnalysisResult> fetchAdminSosAnalysis() async {
    await PoliceAuthService.instance.refreshCurrentSession();
    try {
      final cases = await _fetchAllCasesForAdminFallback();
      return _buildAdminSosAnalysisFromCases(cases);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError(
          'Admin SOS analysis could not load because this session does not '
          'have direct read access to `/sos`. Deploy the latest Firestore '
          'rules, then sign out and sign back in.',
        );
      }
      rethrow;
    }
  }

  Stream<SosCase?> watchCaseById(String caseId) {
    return _firestore.collection('sos').doc(caseId).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return SosCase.fromDoc(doc);
    });
  }

  Stream<SosCaseDetail?> watchCaseDetail(String caseId) {
    return _firestore
        .collection('sos')
        .doc(caseId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) {
        return null;
      }

      return _buildCaseDetailFromDoc(doc);
    });
  }

  Future<SosCaseDetail?> refreshCaseDetail(String caseId) async {
    final doc = await _firestore.collection('sos').doc(caseId).get(
          const GetOptions(source: Source.server),
        );
    if (!doc.exists) {
      return null;
    }
    return _buildCaseDetailFromDoc(
      doc,
      source: Source.server,
    );
  }

  Future<void> updateStatus({
    required String caseId,
    required String status,
    String? resolutionReport,
  }) async {
    final normalizedStatus = status.trim().toLowerCase();
    final normalizedReport = _trimToNull(resolutionReport);
    if (normalizedStatus == 'resolved' && normalizedReport == null) {
      throw StateError(
          'Resolution report is required before closing the case.');
    }

    await PoliceAuthService.instance.refreshCurrentSession();
    try {
      await _functions
          .httpsCallable('updateSosCaseStatus')
          .call(<String, dynamic>{
        'caseId': caseId,
        'status': normalizedStatus,
        if (normalizedReport != null) 'resolutionReport': normalizedReport,
      });
      return;
    } on FirebaseFunctionsException catch (error) {
      if (!_shouldFallbackFromCallable(error)) {
        rethrow;
      }
    }

    final updateData = <String, dynamic>{
      'status': normalizedStatus,
    };
    if (normalizedStatus == 'resolved' && normalizedReport != null) {
      updateData['resolutionReport'] = normalizedReport;
      updateData['resolvedAt'] = FieldValue.serverTimestamp();
      final currentUid = PoliceAuthService.instance.currentUser?.uid;
      final trimmedCurrentUid = currentUid?.trim();
      if (trimmedCurrentUid != null && trimmedCurrentUid.isNotEmpty) {
        updateData['resolvedBy'] = trimmedCurrentUid;
      }
    }

    await _firestore.collection('sos').doc(caseId).update(updateData);
  }

  Future<Map<String, dynamic>?> _loadVictimProfile(
    String userId, {
    Source source = Source.serverAndCache,
  }) async {
    final trimmedUserId = _trimToNull(userId);
    if (trimmedUserId == null) {
      return null;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(trimmedUserId)
          .get(GetOptions(source: source));
      return doc.data();
    } on FirebaseException {
      return null;
    }
  }

  Future<PoliceStation?> _loadAssignedStation(
    String? stationId, {
    Source source = Source.serverAndCache,
  }) async {
    final trimmedStationId = _trimToNull(stationId);
    if (trimmedStationId == null) {
      return null;
    }

    try {
      final doc = await _firestore
          .collection('police_stations')
          .doc(trimmedStationId)
          .get(GetOptions(source: source));
      if (!doc.exists) {
        return null;
      }
      return PoliceStation.fromDoc(doc);
    } on FirebaseException {
      return null;
    }
  }

  static String? _firstNonEmpty(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return null;
    }
    for (final key in keys) {
      final value = _trimToNull(data[key]);
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  static String? _trimToNull(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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

  Future<List<SosCase>> _fetchAllCasesForAdminFallback() async {
    try {
      final snapshot = await _firestore
          .collection('sos')
          .get(const GetOptions(source: Source.server));
      return _sortCases(snapshot.docs.map(SosCase.fromDoc));
    } on FirebaseException catch (error) {
      if (error.code != 'unavailable') {
        rethrow;
      }

      final cachedSnapshot = await _firestore
          .collection('sos')
          .get(const GetOptions(source: Source.cache));
      return _sortCases(cachedSnapshot.docs.map(SosCase.fromDoc));
    }
  }

  Future<SosCaseDetail> _buildCaseDetailFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    Source source = Source.serverAndCache,
  }) async {
    final sosCase = SosCase.fromDoc(doc);
    final victimProfile = await _loadVictimProfile(
      sosCase.userId,
      source: source,
    );
    final assignedStation = await _loadAssignedStation(
      sosCase.assignedStationId,
      source: source,
    );

    return SosCaseDetail(
      sosCase: sosCase,
      victimName: _firstNonEmpty(victimProfile, const <String>[
        'name',
        'fullName',
        'displayName',
      ]),
      victimPhone: _firstNonEmpty(victimProfile, const <String>[
        'phone',
        'phoneNumber',
        'mobile',
      ]),
      victimEmail: _firstNonEmpty(victimProfile, const <String>['email']),
      victimCity: _firstNonEmpty(victimProfile, const <String>['city']),
      assignedStationName: assignedStation?.stationName,
      assignedStationContactNumber: _trimToNull(
        assignedStation?.contactNumber,
      ),
    );
  }

  List<SosCase> _sortCases(Iterable<SosCase> cases) {
    final items = cases.toList(growable: false);
    items.sort((a, b) {
      final aTime = (a.lastLocationUpdateAt ?? a.resolvedAt ?? a.timestamp)
              ?.millisecondsSinceEpoch ??
          0;
      final bTime = (b.lastLocationUpdateAt ?? b.resolvedAt ?? b.timestamp)
              ?.millisecondsSinceEpoch ??
          0;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  AdminSosAnalysisResult _buildAdminSosAnalysisFromCases(List<SosCase> cases) {
    final recentResolvedCases = List<SosCase>.of(cases)
      ..sort((a, b) {
        final aTime = (a.resolvedAt ?? a.lastLocationUpdateAt ?? a.timestamp)
                ?.millisecondsSinceEpoch ??
            0;
        final bTime = (b.resolvedAt ?? b.lastLocationUpdateAt ?? b.timestamp)
                ?.millisecondsSinceEpoch ??
            0;
        return bTime.compareTo(aTime);
      });

    return AdminSosAnalysisResult(
      analytics: SosAnalyticsSnapshot.fromCases(cases),
      recentResolvedCases: recentResolvedCases
          .where((item) => item.status == 'resolved')
          .take(5)
          .map(
            (item) => AdminResolvedCase(
              id: item.id,
              triggerSource: item.triggerSource,
              resolvedAt: item.resolvedAt,
              resolutionReport: item.resolutionReport,
            ),
          )
          .toList(growable: false),
    );
  }
}
