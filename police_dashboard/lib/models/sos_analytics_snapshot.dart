import 'sos_case.dart';

class SosAnalyticsBucket {
  const SosAnalyticsBucket({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  factory SosAnalyticsBucket.fromMap(Map<String, dynamic> data) {
    return SosAnalyticsBucket(
      label: (data['label'] as String?)?.trim() ?? 'Unknown',
      count: data['count'] is num
          ? (data['count'] as num).toInt()
          : int.tryParse('${data['count'] ?? 0}') ?? 0,
    );
  }
}

class SosAnalyticsSnapshot {
  const SosAnalyticsSnapshot({
    required this.totalCases,
    required this.activeCases,
    required this.acceptedCases,
    required this.resolvedCases,
    required this.cancelledCases,
    required this.openCases,
    required this.freshTrackedCases,
    required this.staleTrackedCases,
    required this.missingTrackedCases,
    required this.uploadedEvidenceCases,
    required this.localOnlyEvidenceCases,
    required this.pendingEvidenceCases,
    required this.triggerBreakdown,
    required this.recordingBreakdown,
    required this.evidenceBreakdown,
    required this.trackingBreakdown,
  });

  final int totalCases;
  final int activeCases;
  final int acceptedCases;
  final int resolvedCases;
  final int cancelledCases;
  final int openCases;
  final int freshTrackedCases;
  final int staleTrackedCases;
  final int missingTrackedCases;
  final int uploadedEvidenceCases;
  final int localOnlyEvidenceCases;
  final int pendingEvidenceCases;
  final List<SosAnalyticsBucket> triggerBreakdown;
  final List<SosAnalyticsBucket> recordingBreakdown;
  final List<SosAnalyticsBucket> evidenceBreakdown;
  final List<SosAnalyticsBucket> trackingBreakdown;

  String get topTriggerLabel =>
      triggerBreakdown.isEmpty ? 'No trigger data yet' : triggerBreakdown.first.label;

  int get topTriggerCount =>
      triggerBreakdown.isEmpty ? 0 : triggerBreakdown.first.count;

  factory SosAnalyticsSnapshot.fromMap(Map<String, dynamic> data) {
    return SosAnalyticsSnapshot(
      totalCases: _readInt(data['totalCases']),
      activeCases: _readInt(data['activeCases']),
      acceptedCases: _readInt(data['acceptedCases']),
      resolvedCases: _readInt(data['resolvedCases']),
      cancelledCases: _readInt(data['cancelledCases']),
      openCases: _readInt(data['openCases']),
      freshTrackedCases: _readInt(data['freshTrackedCases']),
      staleTrackedCases: _readInt(data['staleTrackedCases']),
      missingTrackedCases: _readInt(data['missingTrackedCases']),
      uploadedEvidenceCases: _readInt(data['uploadedEvidenceCases']),
      localOnlyEvidenceCases: _readInt(data['localOnlyEvidenceCases']),
      pendingEvidenceCases: _readInt(data['pendingEvidenceCases']),
      triggerBreakdown: _readBuckets(data['triggerBreakdown']),
      recordingBreakdown: _readBuckets(data['recordingBreakdown']),
      evidenceBreakdown: _readBuckets(data['evidenceBreakdown']),
      trackingBreakdown: _readBuckets(data['trackingBreakdown']),
    );
  }

  static SosAnalyticsSnapshot fromCases(
    Iterable<SosCase> cases, {
    DateTime? now,
    Duration freshWindow = const Duration(minutes: 2),
  }) {
    final referenceTime = now ?? DateTime.now();
    final items = cases.toList(growable: false);
    final triggerCounts = <String, int>{};
    final recordingCounts = <String, int>{};
    var activeCases = 0;
    var acceptedCases = 0;
    var resolvedCases = 0;
    var cancelledCases = 0;
    var uploadedEvidenceCases = 0;
    var localOnlyEvidenceCases = 0;
    var pendingEvidenceCases = 0;
    var freshTrackedCases = 0;
    var staleTrackedCases = 0;
    var missingTrackedCases = 0;

    for (final sosCase in items) {
      switch (sosCase.status) {
        case 'active':
          activeCases++;
          break;
        case 'accepted':
          acceptedCases++;
          break;
        case 'resolved':
          resolvedCases++;
          break;
        case 'cancelled':
          cancelledCases++;
          break;
      }

      _incrementBucket(
        triggerCounts,
        _humanizeValue(
          sosCase.triggerSource.isEmpty ? 'app_ui' : sosCase.triggerSource,
        ),
      );
      _incrementBucket(
        recordingCounts,
        _humanizeValue(
          sosCase.recordingStatus.isEmpty
              ? 'recording_pending'
              : sosCase.recordingStatus,
        ),
      );

      if (sosCase.mediaUrl.trim().isNotEmpty) {
        uploadedEvidenceCases++;
      } else if (sosCase.localMediaPath.trim().isNotEmpty) {
        localOnlyEvidenceCases++;
      } else {
        pendingEvidenceCases++;
      }

      final isTrackable = sosCase.status == 'active' || sosCase.status == 'accepted';
      if (!isTrackable) {
        continue;
      }

      final trackingTime = sosCase.lastLocationUpdateAt ?? sosCase.timestamp;
      if (trackingTime == null) {
        missingTrackedCases++;
        continue;
      }

      final age = referenceTime.difference(trackingTime);
      if (age <= freshWindow) {
        freshTrackedCases++;
      } else {
        staleTrackedCases++;
      }
    }

    final openCases = activeCases + acceptedCases;
    final evidenceBreakdown = <SosAnalyticsBucket>[
      SosAnalyticsBucket(label: 'Uploaded', count: uploadedEvidenceCases),
      SosAnalyticsBucket(label: 'Device Only', count: localOnlyEvidenceCases),
      SosAnalyticsBucket(label: 'Pending', count: pendingEvidenceCases),
    ];
    final trackingBreakdown = <SosAnalyticsBucket>[
      SosAnalyticsBucket(label: 'Fresh < 2 min', count: freshTrackedCases),
      SosAnalyticsBucket(label: 'Stale > 2 min', count: staleTrackedCases),
      SosAnalyticsBucket(label: 'No feed yet', count: missingTrackedCases),
    ];

    return SosAnalyticsSnapshot(
      totalCases: items.length,
      activeCases: activeCases,
      acceptedCases: acceptedCases,
      resolvedCases: resolvedCases,
      cancelledCases: cancelledCases,
      openCases: openCases,
      freshTrackedCases: freshTrackedCases,
      staleTrackedCases: staleTrackedCases,
      missingTrackedCases: missingTrackedCases,
      uploadedEvidenceCases: uploadedEvidenceCases,
      localOnlyEvidenceCases: localOnlyEvidenceCases,
      pendingEvidenceCases: pendingEvidenceCases,
      triggerBreakdown: _sortedBuckets(triggerCounts),
      recordingBreakdown: _sortedBuckets(recordingCounts),
      evidenceBreakdown: evidenceBreakdown,
      trackingBreakdown: trackingBreakdown,
    );
  }

  static void _incrementBucket(Map<String, int> buckets, String label) {
    buckets.update(label, (count) => count + 1, ifAbsent: () => 1);
  }

  static List<SosAnalyticsBucket> _sortedBuckets(Map<String, int> buckets) {
    final items = buckets.entries
        .map(
          (entry) => SosAnalyticsBucket(
            label: entry.key,
            count: entry.value,
          ),
        )
        .toList(growable: false);
    items.sort((a, b) {
      final countComparison = b.count.compareTo(a.count);
      if (countComparison != 0) {
        return countComparison;
      }
      return a.label.compareTo(b.label);
    });
    return items;
  }

  static List<SosAnalyticsBucket> _readBuckets(dynamic value) {
    if (value is! List) {
      return const <SosAnalyticsBucket>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => SosAnalyticsBucket.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  static int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static String _humanizeValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Unavailable';
    }

    return trimmed
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          final lower = part.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}
