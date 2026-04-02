import 'sos_analytics_snapshot.dart';

class AdminResolvedCase {
  const AdminResolvedCase({
    required this.id,
    required this.triggerSource,
    required this.resolvedAt,
    required this.resolutionReport,
  });

  final String id;
  final String triggerSource;
  final DateTime? resolvedAt;
  final String? resolutionReport;

  factory AdminResolvedCase.fromMap(Map<String, dynamic> data) {
    return AdminResolvedCase(
      id: (data['id'] as String?)?.trim() ?? '',
      triggerSource: (data['triggerSource'] as String?)?.trim() ?? '',
      resolvedAt: _readDateTime(data['resolvedAt']),
      resolutionReport: (data['resolutionReport'] as String?)?.trim(),
    );
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

class AdminSosAnalysisResult {
  const AdminSosAnalysisResult({
    required this.analytics,
    required this.recentResolvedCases,
  });

  final SosAnalyticsSnapshot analytics;
  final List<AdminResolvedCase> recentResolvedCases;

  factory AdminSosAnalysisResult.fromMap(Map<String, dynamic> data) {
    final recentResolved = data['recentResolvedCases'];
    return AdminSosAnalysisResult(
      analytics: SosAnalyticsSnapshot.fromMap(
        Map<String, dynamic>.from(data['summary'] as Map? ?? const {}),
      ),
      recentResolvedCases: recentResolved is! List
          ? const <AdminResolvedCase>[]
          : recentResolved
              .whereType<Map>()
              .map(
                (item) => AdminResolvedCase.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
    );
  }
}
