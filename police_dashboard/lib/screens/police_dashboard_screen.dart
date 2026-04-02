import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_routes.dart';
import '../models/police_station.dart';
import '../models/sos_analytics_snapshot.dart';
import '../models/sos_case.dart';
import '../services/police_auth_service.dart';
import '../services/police_station_service.dart';
import '../services/sos_dashboard_service.dart';
import '../widgets/sos_analytics_panel.dart';
import '../widgets/suraksha_setu_brand_logo.dart';
import 'sos_case_detail_screen.dart';

class PoliceDashboardScreen extends StatelessWidget {
  const PoliceDashboardScreen({
    super.key,
    required this.session,
  });

  final PoliceSession session;

  static const Color _navy = Color(0xFF12344D);
  static const Color _teal = Color(0xFF1F6B7A);
  static const Color _sand = Color(0xFFF5EFE4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const SurakshaSetuBrandLogo(width: 56, compact: true),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Police Response Dashboard'),
                Text(
                  'Assigned station response queue',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await PoliceAuthService.instance.signOut();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.home,
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<SosCase>>(
        stream:
            SosDashboardService.instance.watchAssignedCases(session.stationId),
        builder: (context, snapshot) {
          if (PoliceAuthService.instance.currentUser == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Failed to load cases: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = List<SosCase>.of(snapshot.data!)..sort(_compareCases);
          final activeCases =
              cases.where((caseItem) => caseItem.status == 'active').toList();
          final acceptedCases =
              cases.where((caseItem) => caseItem.status == 'accepted').toList();
          final resolvedCases =
              cases.where((caseItem) => caseItem.status == 'resolved').toList();
          final latestUpdate = _latestCaseUpdate(cases);
          final analytics = SosAnalyticsSnapshot.fromCases(cases);

          return StreamBuilder<PoliceStation?>(
            stream: PoliceStationService.instance
                .watchStationById(session.stationId),
            builder: (context, stationSnapshot) {
              final station = stationSnapshot.data;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _overviewBanner(
                    context,
                    session: session,
                    station: station,
                    totalCases: cases.length,
                    activeCount: activeCases.length,
                    acceptedCount: acceptedCases.length,
                    latestUpdate: latestUpdate,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: 220,
                        child: _metricCard(
                          context,
                          title: 'Live SOS',
                          value: '${activeCases.length}',
                          subtitle: activeCases.isEmpty
                              ? 'No emergencies right now'
                              : 'Needs immediate attention',
                          color: Colors.red,
                          icon: Icons.notifications_active_outlined,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _metricCard(
                          context,
                          title: 'Accepted Cases',
                          value: '${acceptedCases.length}',
                          subtitle: acceptedCases.isEmpty
                              ? 'No active follow-up'
                              : 'Being handled by station',
                          color: Colors.orange,
                          icon: Icons.assignment_turned_in_outlined,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _metricCard(
                          context,
                          title: 'Resolved Today',
                          value: '${resolvedCases.length}',
                          subtitle: resolvedCases.isEmpty
                              ? 'No closures yet'
                              : 'Closed in assigned queue',
                          color: Colors.green,
                          icon: Icons.task_alt,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: _metricCard(
                          context,
                          title: 'Station Queue',
                          value: '${cases.length}',
                          subtitle: _compactStationId(session.stationId),
                          color: _teal,
                          icon: Icons.account_tree_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (analytics.openCases > 0 &&
                      (analytics.staleTrackedCases > 0 ||
                          analytics.missingTrackedCases > 0)) ...[
                    const SizedBox(height: 18),
                    _trackingAlertCard(context, analytics),
                  ],
                  const SizedBox(height: 26),
                  SosAnalyticsPanel(
                    analytics: analytics,
                    title: 'SOS Intelligence',
                    subtitle:
                        'Trigger trends, evidence readiness, and live tracking health for the assigned station queue.',
                    accentColor: _teal,
                  ),
                  const SizedBox(height: 26),
                  _sectionHeader(
                    context,
                    title: 'Priority Queue',
                    subtitle: activeCases.isEmpty
                        ? 'No live SOS at the moment. Assigned cases stay visible below.'
                        : 'Live SOS cases are pinned first so the team can triage faster.',
                  ),
                  const SizedBox(height: 12),
                  if (activeCases.isEmpty)
                    _emptyPriorityState(context)
                  else
                    ...activeCases.map(
                      (caseItem) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _caseCard(
                          context,
                          sosCase: caseItem,
                          stationId: session.stationId,
                          priority: true,
                        ),
                      ),
                    ),
                  if (acceptedCases.isNotEmpty || resolvedCases.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionHeader(
                      context,
                      title: 'Assigned Cases',
                      subtitle:
                          'Accepted and resolved incidents remain available for quick follow-up.',
                    ),
                    const SizedBox(height: 12),
                    ...acceptedCases.map(
                      (caseItem) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _caseCard(
                          context,
                          sosCase: caseItem,
                          stationId: session.stationId,
                        ),
                      ),
                    ),
                    ...resolvedCases.map(
                      (caseItem) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _caseCard(
                          context,
                          sosCase: caseItem,
                          stationId: session.stationId,
                        ),
                      ),
                    ),
                  ],
                  if (cases.isEmpty) ...[
                    const SizedBox(height: 18),
                    _emptyQueueState(context, station),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _overviewBanner(
    BuildContext context, {
    required PoliceSession session,
    required PoliceStation? station,
    required int totalCases,
    required int activeCount,
    required int acceptedCount,
    required DateTime? latestUpdate,
  }) {
    final stationName = station?.stationName.trim();
    final stationLabel = stationName != null && stationName.isNotEmpty
        ? stationName
        : 'Assigned Police Station';
    final leadText = activeCount > 0
        ? '$activeCount live SOS ${activeCount == 1 ? 'needs' : 'need'} attention right now.'
        : totalCases == 0
            ? 'No assigned SOS cases right now. The dashboard is ready for the next alert.'
            : 'No live SOS right now. Keep tracking accepted and resolved cases below.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[_navy, _teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2212344D),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: _sand,
                  size: 28,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stationLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leadText,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _bannerPill(
                label: 'Station ID',
                value: _compactStationId(session.stationId),
              ),
              if (station?.contactNumber.trim().isNotEmpty == true)
                _bannerPill(
                  label: 'Contact',
                  value: station!.contactNumber.trim(),
                ),
              _bannerPill(
                label: 'Latest activity',
                value: latestUpdate == null
                    ? 'Waiting for first incident'
                    : _formatBannerTime(latestUpdate),
              ),
              _bannerPill(
                label: 'Cases in queue',
                value: '$totalCases total / $acceptedCount accepted',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bannerPill({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD7E6ED),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
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
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF425466),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF16212E),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF617180),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF16212E),
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF617180),
                height: 1.45,
              ),
        ),
      ],
    );
  }

  Widget _trackingAlertCard(
    BuildContext context,
    SosAnalyticsSnapshot analytics,
  ) {
    final staleCount = analytics.staleTrackedCases;
    final missingCount = analytics.missingTrackedCases;
    final detailText = [
      if (staleCount > 0) '$staleCount stale feed${staleCount == 1 ? '' : 's'}',
      if (missingCount > 0) '$missingCount without location',
    ].join(' and ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.radar_outlined,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking Needs Attention',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF92400E),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The open queue currently has $detailText. Review those cases first so the team is not working from stale victim coordinates.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF78350F),
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPriorityState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.verified_user_outlined, color: Colors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Priority queue is clear. New live SOS cases will appear here first.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF243444),
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyQueueState(BuildContext context, PoliceStation? station) {
    final stationName = station?.stationName.trim();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE3EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No Assigned SOS Cases',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            stationName == null || stationName.isEmpty
                ? 'When a victim is routed to this station, the case will appear here automatically.'
                : 'When a victim is routed to $stationName, the case will appear here automatically.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF617180),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }

  Widget _caseCard(
    BuildContext context, {
    required SosCase sosCase,
    required String stationId,
    bool priority = false,
  }) {
    final statusColor = _statusColor(sosCase.status);
    final locationText = _formatLocationText(sosCase);
    final eventTime = sosCase.timestamp;
    final lastUpdate = sosCase.lastLocationUpdateAt;
    final caseSummary = _caseSummary(sosCase);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: priority
              ? statusColor.withValues(alpha: 0.28)
              : const Color(0xFFDCE3EA),
          width: priority ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: priority
                ? statusColor.withValues(alpha: 0.10)
                : const Color(0x12000000),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SosCaseDetailScreen(
              caseId: sosCase.id,
              stationId: stationId,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          priority ? 'Immediate Response' : 'Assigned Case',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SOS ${_shortCaseId(sosCase.id)}',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF16212E),
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(sosCase.status),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _infoPill(
                    icon: Icons.schedule_outlined,
                    text: eventTime == null
                        ? 'Timestamp pending'
                        : DateFormat('dd MMM, hh:mm a').format(eventTime),
                  ),
                  _infoPill(
                    icon: Icons.update_outlined,
                    text: lastUpdate == null
                        ? 'No live update yet'
                        : 'Updated ${_formatRelativeTime(lastUpdate)}',
                  ),
                  _infoPill(
                    icon: Icons.location_on_outlined,
                    text: locationText,
                  ),
                  _infoPill(
                    icon: Icons.flash_on_outlined,
                    text: _humanizeValue(
                      sosCase.triggerSource.isEmpty
                          ? 'app_ui'
                          : sosCase.triggerSource,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                caseSummary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF526273),
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SosCaseDetailScreen(
                          caseId: sosCase.id,
                          stationId: stationId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open details'),
                  ),
                  if (sosCase.googleMapsUrl != null)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _openMap(context, sosCase.googleMapsUrl!),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open map link'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF617180)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    final label = _statusLabel(status);

    return Chip(
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      backgroundColor: color.withValues(alpha: 0.10),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
    );
  }

  Future<void> _openMap(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map link is invalid.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the map link.')),
      );
    }
  }

  int _compareCases(SosCase a, SosCase b) {
    final rankA = _statusRank(a.status);
    final rankB = _statusRank(b.status);
    if (rankA != rankB) {
      return rankA.compareTo(rankB);
    }

    final aTime =
        (a.lastLocationUpdateAt ?? a.timestamp)?.millisecondsSinceEpoch ?? 0;
    final bTime =
        (b.lastLocationUpdateAt ?? b.timestamp)?.millisecondsSinceEpoch ?? 0;
    return bTime.compareTo(aTime);
  }

  int _statusRank(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 0;
      case 'accepted':
        return 1;
      case 'resolved':
        return 2;
      case 'cancelled':
        return 3;
      default:
        return 4;
    }
  }

  DateTime? _latestCaseUpdate(List<SosCase> cases) {
    DateTime? latest;
    for (final caseItem in cases) {
      final candidate = caseItem.lastLocationUpdateAt ?? caseItem.timestamp;
      if (candidate == null) {
        continue;
      }
      if (latest == null || candidate.isAfter(latest)) {
        latest = candidate;
      }
    }
    return latest;
  }

  String _formatBannerTime(DateTime value) {
    return '${DateFormat('dd MMM, hh:mm a').format(value)} | ${_formatRelativeTime(value)}';
  }

  String _compactStationId(String stationId) {
    if (stationId.length <= 10) {
      return stationId;
    }
    return '${stationId.substring(0, 5)}...${stationId.substring(stationId.length - 4)}';
  }

  String _shortCaseId(String caseId) {
    if (caseId.length <= 8) {
      return caseId;
    }
    return caseId.substring(0, 8);
  }

  String _formatLocationText(SosCase sosCase) {
    final latitude = sosCase.resolvedLatitude;
    final longitude = sosCase.resolvedLongitude;
    if (latitude == null || longitude == null) {
      return 'Live location unavailable';
    }
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  String _caseSummary(SosCase sosCase) {
    if (sosCase.status == 'resolved' &&
        (sosCase.resolutionReport?.isNotEmpty ?? false)) {
      return 'Closure report captured: ${_truncate(sosCase.resolutionReport!, 160)}';
    }
    final recordingText = sosCase.recordingStatus.isEmpty
        ? 'recording status pending'
        : _humanizeValue(sosCase.recordingStatus).toLowerCase();
    if (sosCase.mediaUrl.isNotEmpty) {
      return 'Evidence is uploaded, $recordingText, and the location feed is ready for follow-up.';
    }
    if (sosCase.localMediaPath.isNotEmpty) {
      return 'Media is still on-device, $recordingText, and the case should be reviewed in detail for latest evidence.';
    }
    return 'Location and incident metadata are available. Open the case to review response details and update status.';
  }

  String _truncate(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLength - 1)}...';
  }

  String _formatRelativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inSeconds < 60) {
      return 'just now';
    }
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes min ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hr ago';
    }
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  String _humanizeValue(String value) {
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
    }).join(' ');
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'accepted':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'cancelled':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'accepted':
        return 'Accepted';
      case 'resolved':
        return 'Resolved';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
