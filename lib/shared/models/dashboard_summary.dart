class DashboardSummary {
  const DashboardSummary({
    required this.totalAllocation,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingBalance,
    required this.disposableBalance,
    required this.reservationRate,
    required this.spendingRate,
    this.balanceAlerts = const [],
  });

  final double totalAllocation;
  final double totalReserved;
  final double totalSpent;
  final double remainingBalance;
  final double disposableBalance;
  final double reservationRate;
  final double spendingRate;
  final List<DashboardBalanceAlert> balanceAlerts;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    double parse(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    final totalAllocation = parse(json['total_allocation']);
    final totalReserved = parse(json['total_reserved']);
    final totalSpent = parse(json['total_spent']);
    final remainingBalance = parse(json['remaining_balance']);
    final fallbackReservationRate = totalAllocation > 0
        ? (totalReserved / totalAllocation) * 100
        : 0.0;
    final fallbackSpendingRate = totalAllocation > 0
        ? (totalSpent / totalAllocation) * 100
        : 0.0;

    final alertsPayload = json['balance_alerts'];
    final balanceAlerts = alertsPayload is List
        ? alertsPayload
              .whereType<Map>()
              .map(
                (item) => DashboardBalanceAlert.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : const <DashboardBalanceAlert>[];

    return DashboardSummary(
      totalAllocation: totalAllocation,
      totalReserved: totalReserved,
      totalSpent: totalSpent,
      remainingBalance: remainingBalance,
      // تعليق عربي: إذا كان الخادم القديم لا يرجع الحقل الجديد،
      // نحسبه من المتبقي حتى لا تظهر بطاقة القابل للصرف بصفر خطأً.
      disposableBalance: json.containsKey('disposable_balance')
          ? parse(json['disposable_balance'])
          : remainingBalance,
      reservationRate: json.containsKey('reservation_rate')
          ? parse(json['reservation_rate'])
          : fallbackReservationRate,
      spendingRate: json.containsKey('spending_rate')
          ? parse(json['spending_rate'])
          : fallbackSpendingRate,
      balanceAlerts: balanceAlerts,
    );
  }
}

class DashboardBalanceAlert {
  const DashboardBalanceAlert({
    required this.programName,
    required this.sectionCode,
    required this.sectionName,
    required this.remainingFunding,
    required this.threshold,
    required this.severity,
    required this.message,
  });

  final String programName;
  final String sectionCode;
  final String sectionName;
  final double remainingFunding;
  final double threshold;
  final String severity;
  final String message;

  bool get isCritical => severity == 'critical';

  factory DashboardBalanceAlert.fromJson(Map<String, dynamic> json) {
    double parse(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return DashboardBalanceAlert(
      programName: json['program_name']?.toString() ?? '',
      sectionCode: json['section_code']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      remainingFunding: parse(json['remaining_funding']),
      threshold: parse(json['threshold']),
      severity: json['severity']?.toString() ?? 'warning',
      message: json['message']?.toString() ?? '',
    );
  }
}

class DashboardSectionCard {
  const DashboardSectionCard({
    required this.sectionId,
    required this.programId,
    required this.programName,
    required this.sectionCode,
    required this.sectionName,
    required this.sectionPath,
    required this.totalAllocation,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingBalance,
    required this.childrenCount,
    required this.postableChildrenCount,
  });

  final String sectionId;
  final String programId;
  final String programName;
  final String sectionCode;
  final String sectionName;
  final String sectionPath;
  final double totalAllocation;
  final double totalReserved;
  final double totalSpent;
  final double remainingBalance;
  final int childrenCount;
  final int postableChildrenCount;

  factory DashboardSectionCard.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

    return DashboardSectionCard(
      sectionId: json['section_id']?.toString() ?? '',
      programId: json['program_id']?.toString() ?? '',
      programName: json['program_name']?.toString() ?? '',
      sectionCode: json['section_code']?.toString() ?? '',
      sectionName: json['section_name']?.toString() ?? '',
      sectionPath: json['section_path']?.toString() ?? '',
      totalAllocation: parseDouble(json['total_allocation']),
      totalReserved: parseDouble(json['total_reserved']),
      totalSpent: parseDouble(json['total_spent']),
      remainingBalance: parseDouble(json['remaining_balance']),
      childrenCount: parseInt(json['children_count']),
      postableChildrenCount: parseInt(json['postable_children_count']),
    );
  }
}
