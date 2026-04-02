import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sos_case.dart';
import '../models/sos_case_detail.dart';
import '../services/sos_dashboard_service.dart';
import '../utils/firebase_error_mapper.dart';

class SosCaseDetailScreen extends StatefulWidget {
  const SosCaseDetailScreen({
    super.key,
    required this.caseId,
    required this.stationId,
  });

  final String caseId;
  final String stationId;

  @override
  State<SosCaseDetailScreen> createState() => _SosCaseDetailScreenState();
}

class _SosCaseDetailScreenState extends State<SosCaseDetailScreen> {
  bool _refreshingLocation = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Case Detail'),
        actions: [
          IconButton(
            onPressed: _refreshingLocation ? null : _refreshLiveLocation,
            tooltip: 'Refresh live location',
            icon: _refreshingLocation
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<SosCaseDetail?>(
        stream: SosDashboardService.instance.watchCaseDetail(widget.caseId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load case details: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text('Case not found.'));
          }

          final sosCase = detail.sosCase;
          if (sosCase.assignedStationId != widget.stationId) {
            return const Center(
              child: Text('This SOS is not assigned to your station.'),
            );
          }

          final locationText = _formatLocation(sosCase);
          final latitudeText = _formatCoordinate(sosCase.resolvedLatitude);
          final longitudeText = _formatCoordinate(sosCase.resolvedLongitude);
          final mapsUrl = sosCase.googleMapsUrl;
          final mediaUrl = sosCase.mediaUrl.trim();
          final hasMediaUrl = mediaUrl.isNotEmpty;
          final localMediaPath = sosCase.localMediaPath.trim();

          return RefreshIndicator(
            onRefresh: _refreshLiveLocation,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  context,
                  title: 'Victim',
                  children: [
                    _item('Name', detail.victimDisplayName),
                    _item('User ID', sosCase.userId),
                    _item('Phone', detail.victimPhone ?? 'Unavailable'),
                    _item('Email', detail.victimEmail ?? 'Unavailable'),
                    _item('City', detail.victimCity ?? 'Unavailable'),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Incident',
                  children: [
                    _item('Case ID', sosCase.id),
                    _item('Status', sosCase.status.toUpperCase()),
                    _item(
                      'Assigned Station',
                      detail.assignedStationDisplayName,
                    ),
                    _item(
                      'Assigned Station ID',
                      sosCase.assignedStationId ?? 'Unassigned',
                    ),
                    _item(
                      'Station Contact',
                      detail.assignedStationContactNumber ?? 'Unavailable',
                    ),
                    _item('Trigger Source', _humanizeValue(sosCase.triggerSource)),
                    _item('Timestamp', _formatDateTime(sosCase.timestamp)),
                    _item(
                      'Last Location Update',
                      _formatDateTime(sosCase.lastLocationUpdateAt),
                    ),
                    _item('Cancelled At', _formatDateTime(sosCase.cancelledAt)),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  context,
                  title: 'Location',
                  children: [
                    _item('Live Location', locationText),
                    _item('Latitude', latitudeText),
                    _item('Longitude', longitudeText),
                    _item(
                      'Tracking Freshness',
                      _formatTrackingFreshness(sosCase),
                    ),
                    _item('Google Maps Link', mapsUrl ?? 'Unavailable'),
                    _actionWrap(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed:
                              _refreshingLocation ? null : _refreshLiveLocation,
                          icon: _refreshingLocation
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.my_location_outlined),
                          label: Text(
                            _refreshingLocation
                                ? 'Refreshing...'
                                : 'Refresh Live Location',
                          ),
                        ),
                        if (mapsUrl != null)
                          OutlinedButton.icon(
                            onPressed: () => _launchExternalUrl(
                              context,
                              mapsUrl,
                              failureLabel: 'Google Maps link',
                            ),
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Open Google Maps'),
                          ),
                        if (mapsUrl != null)
                          OutlinedButton.icon(
                            onPressed: () => _copyText(
                              context,
                              label: 'Google Maps link',
                              value: mapsUrl,
                            ),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Copy Link'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (sosCase.status == 'resolved' ||
                    (sosCase.resolutionReport?.isNotEmpty ?? false) ||
                    sosCase.resolvedAt != null) ...[
                  _sectionCard(
                    context,
                    title: 'Resolution',
                    children: [
                      _item(
                        'Resolved At',
                        _formatDateTime(sosCase.resolvedAt),
                      ),
                      _item(
                        'Resolved By',
                        sosCase.resolvedBy ?? 'Unavailable',
                      ),
                      _item(
                        'Closure Report',
                        sosCase.resolutionReport ??
                            'No closure report captured.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                _sectionCard(
                  context,
                  title: 'Evidence',
                  children: [
                    _item(
                      'Recording Status',
                      _humanizeValue(sosCase.recordingStatus),
                    ),
                    _item(
                      'Recording Failure',
                      sosCase.recordingFailureReason ?? 'None',
                    ),
                    _item(
                      'Media URL',
                      hasMediaUrl ? mediaUrl : 'Upload pending',
                    ),
                    _item(
                      'Local Media Path',
                      localMediaPath.isEmpty ? 'Unavailable' : localMediaPath,
                    ),
                    if (hasMediaUrl)
                      _actionWrap(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _launchExternalUrl(
                              context,
                              mediaUrl,
                              failureLabel: 'media URL',
                            ),
                            icon: const Icon(Icons.play_circle_fill),
                            label: const Text('Open Media'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyText(
                              context,
                              label: 'Media URL',
                              value: mediaUrl,
                            ),
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Copy URL'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (sosCase.status != 'cancelled')
                  _StatusDropdown(
                    caseId: sosCase.id,
                    currentStatus: sosCase.status,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshLiveLocation() async {
    if (_refreshingLocation) {
      return;
    }

    setState(() => _refreshingLocation = true);
    try {
      final detail =
          await SosDashboardService.instance.refreshCaseDetail(widget.caseId);
      if (!mounted) {
        return;
      }

      if (detail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case not found during refresh.')),
        );
        return;
      }

      final sosCase = detail.sosCase;
      final locationText = _formatLocation(sosCase);
      final freshnessText = _formatTrackingFreshness(sosCase);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Live location refreshed. $locationText | $freshnessText',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FirebaseErrorMapper.toMessage(
              e,
              fallback: 'Could not refresh live location. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshingLocation = false);
      }
    }
  }

  Future<void> _copyText(
    BuildContext context, {
    required String label,
    required String value,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied.')),
    );
  }

  Future<void> _launchExternalUrl(
    BuildContext context,
    String value, {
    required String failureLabel,
  }) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid $failureLabel.')),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open the $failureLabel.')),
      );
    }
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _item(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionWrap({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children,
      ),
    );
  }

  String _formatLocation(SosCase sosCase) {
    final latitude = sosCase.resolvedLatitude;
    final longitude = sosCase.resolvedLongitude;
    if (latitude == null || longitude == null) {
      return 'Unavailable';
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  String _formatCoordinate(double? value) {
    if (value == null) {
      return 'Unavailable';
    }
    return value.toStringAsFixed(6);
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return 'Unavailable';
    }
    return DateFormat('dd MMM yyyy, hh:mm:ss a').format(value);
  }

  String _formatTrackingFreshness(SosCase sosCase) {
    final trackingTime = sosCase.lastLocationUpdateAt ?? sosCase.timestamp;
    if (trackingTime == null) {
      return 'No live tracking feed yet';
    }

    final age = DateTime.now().difference(trackingTime);
    if (age.inMinutes < 2) {
      return 'Fresh live location (${_formatRelativeAge(age)})';
    }
    return 'Stale live location (${_formatRelativeAge(age)})';
  }

  String _formatRelativeAge(Duration age) {
    if (age.inSeconds < 60) {
      return 'updated just now';
    }
    if (age.inMinutes < 60) {
      return 'updated ${age.inMinutes} min ago';
    }
    if (age.inHours < 24) {
      return 'updated ${age.inHours} hr ago';
    }
    return 'updated ${age.inDays} day${age.inDays == 1 ? '' : 's'} ago';
  }

  String _humanizeValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
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

class _StatusDropdown extends StatefulWidget {
  const _StatusDropdown({
    required this.caseId,
    required this.currentStatus,
  });

  final String caseId;
  final String currentStatus;

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  late String _selected;
  late final TextEditingController _reportController;
  bool _saving = false;

  List<String> get _allowedNextStatuses {
    switch (widget.currentStatus.toLowerCase()) {
      case 'active':
        return const <String>['accepted'];
      case 'accepted':
        return const <String>['resolved'];
      default:
        return const <String>[];
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = _initialSelectedValue();
    _reportController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant _StatusDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selected = _initialSelectedValue();
    if (widget.currentStatus.toLowerCase() != 'accepted') {
      _reportController.clear();
    }
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  String _initialSelectedValue() {
    final allowedStatuses = _allowedNextStatuses;
    if (allowedStatuses.isNotEmpty) {
      return allowedStatuses.first;
    }
    return widget.currentStatus.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final allowedStatuses = _allowedNextStatuses;
    if (allowedStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_requiresReport) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Text(
              'Resolution report is required before the case can be marked resolved.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reportController,
            enabled: !_saving,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Resolution report',
              hintText:
                  'Describe what police found, what action was taken, and the current victim outcome.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('${widget.caseId}_$_selected'),
                initialValue: _selected,
                decoration: const InputDecoration(
                  labelText: 'Update Status',
                  border: OutlineInputBorder(),
                ),
                items: allowedStatuses
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_labelForStatus(value)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selected = value);
                      },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final report = _reportController.text.trim();
                      if (_requiresReport && report.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Add a resolution report before closing the case.',
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        setState(() => _saving = true);
                        await SosDashboardService.instance.updateStatus(
                          caseId: widget.caseId,
                          status: _selected,
                          resolutionReport: _requiresReport ? report : null,
                        );
                        if (!mounted) {
                          return;
                        }
                        _reportController.clear();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              _requiresReport
                                  ? 'Case resolved and report saved.'
                                  : 'Status updated.',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) {
                          return;
                        }
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              FirebaseErrorMapper.toMessage(
                                e,
                                fallback:
                                    'Status update failed. Please try again.',
                              ),
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _saving = false);
                        }
                      }
                    },
              child: _saving
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_requiresReport ? 'Resolve Case' : 'Save'),
            ),
          ],
        ),
      ],
    );
  }

  bool get _requiresReport => _selected == 'resolved';

  String _labelForStatus(String value) {
    switch (value) {
      case 'accepted':
        return 'Accepted';
      case 'resolved':
        return 'Resolved';
      default:
        return value;
    }
  }
}
