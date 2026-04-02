import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_sos_analysis_result.dart';
import '../services/sos_dashboard_service.dart';
import '../utils/firebase_error_mapper.dart';
import '../widgets/sos_analytics_panel.dart';

class AdminSosAnalysisScreen extends StatefulWidget {
  const AdminSosAnalysisScreen({super.key});

  @override
  State<AdminSosAnalysisScreen> createState() => _AdminSosAnalysisScreenState();
}

class _AdminSosAnalysisScreenState extends State<AdminSosAnalysisScreen> {
  late Future<AdminSosAnalysisResult> _analysisFuture;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _loadAnalysis();
  }

  Future<AdminSosAnalysisResult> _loadAnalysis() {
    return SosDashboardService.instance.fetchAdminSosAnalysis();
  }

  Future<void> _refresh() async {
    setState(() {
      _analysisFuture = _loadAnalysis();
    });
    await _analysisFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminSosAnalysisResult>(
      future: _analysisFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.insights_outlined,
                    size: 40,
                    color: Color(0xFF617180),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    FirebaseErrorMapper.toMessage(
                      snapshot.error!,
                      fallback: 'Failed to load SOS analysis.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return const Center(child: Text('No SOS analysis available.'));
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[
                      Color(0xFF16212E),
                      Color(0xFF1F6B7A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2216212E),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.insights_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System-wide SOS Review',
                            style:
                                Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Admin view for trigger patterns, evidence readiness, location freshness, and recent closure reports across all SOS incidents.',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.86),
                                      height: 1.45,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SosAnalyticsPanel(
                analytics: result.analytics,
                title: 'SOS Analysis',
                subtitle:
                    'Use this snapshot to review how incidents are triggered, whether evidence is arriving, and how healthy the live-location feed is.',
                accentColor: const Color(0xFF1F6B7A),
                surfaceColor: Colors.white,
              ),
              const SizedBox(height: 22),
              _recentReportsCard(context, result.recentResolvedCases),
            ],
          ),
        );
      },
    );
  }

  Widget _recentReportsCard(
    BuildContext context,
    List<AdminResolvedCase> resolvedCases,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
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
            'Recent Closure Reports',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF16212E),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Resolved cases stay visible here so admin can quickly review field outcomes and missing closure notes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF617180),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          if (resolvedCases.isEmpty)
            Text(
              'No resolved SOS cases yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF617180),
                  ),
            )
          else
            ...resolvedCases.map(
              (sosCase) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _infoPill(
                            context,
                            icon: Icons.task_alt_outlined,
                            text: 'Case ${_shortId(sosCase.id)}',
                          ),
                          _infoPill(
                            context,
                            icon: Icons.schedule_outlined,
                            text: sosCase.resolvedAt == null
                                ? 'Resolved time unavailable'
                                : DateFormat('dd MMM, hh:mm a')
                                    .format(sosCase.resolvedAt!),
                          ),
                          _infoPill(
                            context,
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
                        (sosCase.resolutionReport?.trim().isNotEmpty ?? false)
                            ? sosCase.resolutionReport!.trim()
                            : 'No closure report was stored for this resolved case.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF334155),
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoPill(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  String _shortId(String value) {
    if (value.length <= 8) {
      return value;
    }
    return value.substring(0, 8);
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
        })
        .join(' ');
  }
}
