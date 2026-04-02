import 'sos_case.dart';

class SosCaseDetail {
  const SosCaseDetail({
    required this.sosCase,
    this.victimName,
    this.victimPhone,
    this.victimEmail,
    this.victimCity,
    this.assignedStationName,
    this.assignedStationContactNumber,
  });

  final SosCase sosCase;
  final String? victimName;
  final String? victimPhone;
  final String? victimEmail;
  final String? victimCity;
  final String? assignedStationName;
  final String? assignedStationContactNumber;

  String get victimDisplayName {
    return _firstNonEmpty(<String?>[
          victimName,
          sosCase.userId,
        ]) ??
        'Unknown user';
  }

  String get assignedStationDisplayName {
    return _firstNonEmpty(<String?>[
          assignedStationName,
          sosCase.assignedStationId,
        ]) ??
        'Unassigned';
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}
