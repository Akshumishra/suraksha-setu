import 'package:flutter/material.dart';

import '../models/sos_analytics_snapshot.dart';

class SosAnalyticsPanel extends StatelessWidget {
  const SosAnalyticsPanel({
    super.key,
    required this.analytics,
    required this.title,
    required this.subtitle,
    this.accentColor = const Color(0xFF1F6B7A),
    this.surfaceColor = Colors.white,
  });

  final SosAnalyticsSnapshot analytics;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCE3EA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF16212E),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF617180),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 220,
                child: _highlightCard(
                  context,
                  icon: Icons.flash_on_outlined,
                  title: 'Top Trigger',
                  value: analytics.topTriggerLabel,
                  subtitle: analytics.topTriggerCount == 0
                      ? 'Waiting for trigger data'
                      : '${analytics.topTriggerCount} case${analytics.topTriggerCount == 1 ? '' : 's'}',
                  color: accentColor,
                ),
              ),
              SizedBox(
                width: 220,
                child: _highlightCard(
                  context,
                  icon: Icons.my_location_outlined,
                  title: 'Fresh Tracking',
                  value:
                      '${analytics.freshTrackedCases}/${analytics.openCases == 0 ? 0 : analytics.openCases}',
                  subtitle: analytics.openCases == 0
                      ? 'No open cases'
                      : analytics.staleTrackedCases == 0 &&
                              analytics.missingTrackedCases == 0
                          ? 'All open cases have recent location'
                          : '${analytics.staleTrackedCases} stale, ${analytics.missingTrackedCases} missing',
                  color: const Color(0xFF0F8F6C),
                ),
              ),
              SizedBox(
                width: 220,
                child: _highlightCard(
                  context,
                  icon: Icons.video_library_outlined,
                  title: 'Evidence Ready',
                  value: '${analytics.uploadedEvidenceCases}',
                  subtitle: analytics.pendingEvidenceCases == 0
                      ? 'No pending uploads'
                      : '${analytics.pendingEvidenceCases} still pending',
                  color: const Color(0xFF8F4F12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 280,
                child: _breakdownCard(
                  context,
                  title: 'Trigger Sources',
                  subtitle: 'How SOS was activated',
                  items: analytics.triggerBreakdown,
                  color: accentColor,
                ),
              ),
              SizedBox(
                width: 280,
                child: _breakdownCard(
                  context,
                  title: 'Recording State',
                  subtitle: 'Camera and evidence capture health',
                  items: analytics.recordingBreakdown,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              SizedBox(
                width: 280,
                child: _breakdownCard(
                  context,
                  title: 'Evidence Pipeline',
                  subtitle: 'Upload readiness across SOS cases',
                  items: analytics.evidenceBreakdown,
                  color: const Color(0xFFB45309),
                ),
              ),
              SizedBox(
                width: 280,
                child: _breakdownCard(
                  context,
                  title: 'Tracking Freshness',
                  subtitle: 'Open-case location recency snapshot',
                  items: analytics.trackingBreakdown,
                  color: const Color(0xFF0F8F6C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _highlightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF425466),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF16212E),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF617180),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<SosAnalyticsBucket> items,
    required Color color,
  }) {
    final visibleItems = items.take(5).toList(growable: false);
    final maxCount =
        visibleItems.fold<int>(0, (current, item) => item.count > current ? item.count : current);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF16212E),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF617180),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          if (visibleItems.isEmpty)
            Text(
              'No data yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF617180),
                  ),
            )
          else
            ...visibleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _breakdownRow(
                  context,
                  item: item,
                  color: color,
                  maxCount: maxCount,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _breakdownRow(
    BuildContext context, {
    required SosAnalyticsBucket item,
    required Color color,
    required int maxCount,
  }) {
    final progress = maxCount <= 0 ? 0.0 : item.count / maxCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF243444),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${item.count}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF526273),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}
