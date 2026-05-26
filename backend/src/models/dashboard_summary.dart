class DashboardSummary {
  const DashboardSummary({
    required this.totalAllocation,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingBalance,
    required this.disposableBalance,
    required this.reservationRate,
    required this.spendingRate,
    required this.noMovementSectionsCount,
    this.balanceAlerts = const [],
  });

  final double totalAllocation;
  final double totalReserved;
  final double totalSpent;
  final double remainingBalance;
  final double disposableBalance;
  final double reservationRate;
  final double spendingRate;
  final int noMovementSectionsCount;
  final List<DashboardBalanceAlert> balanceAlerts;

  Map<String, dynamic> toJson() {
    return {
      'total_allocation': totalAllocation,
      'total_reserved': totalReserved,
      'total_spent': totalSpent,
      'remaining_balance': remainingBalance,
      'disposable_balance': disposableBalance,
      'reservation_rate': reservationRate,
      'spending_rate': spendingRate,
      'no_movement_sections_count': noMovementSectionsCount,
      'balance_alerts': balanceAlerts.map((alert) => alert.toJson()).toList(),
    };
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

  Map<String, dynamic> toJson() {
    return {
      'program_name': programName,
      'section_code': sectionCode,
      'section_name': sectionName,
      'remaining_funding': remainingFunding,
      'threshold': threshold,
      'severity': severity,
      'message': message,
    };
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

  Map<String, dynamic> toJson() {
    return {
      'section_id': sectionId,
      'program_id': programId,
      'program_name': programName,
      'section_code': sectionCode,
      'section_name': sectionName,
      'section_path': sectionPath,
      'total_allocation': totalAllocation,
      'total_reserved': totalReserved,
      'total_spent': totalSpent,
      'remaining_balance': remainingBalance,
      'children_count': childrenCount,
      'postable_children_count': postableChildrenCount,
    };
  }
}

class DashboardAnalytics {
  const DashboardAnalytics({
    required this.programs,
    required this.sections,
    required this.monthly,
    required this.topSpentSections,
    required this.noMovementSections,
  });

  final List<DashboardAnalyticsItem> programs;
  final List<DashboardAnalyticsItem> sections;
  final List<DashboardMonthlyAnalyticsItem> monthly;
  final List<DashboardAnalyticsItem> topSpentSections;
  final List<DashboardNoMovementSection> noMovementSections;

  Map<String, dynamic> toJson() {
    return {
      'programs': programs.map((item) => item.toJson()).toList(),
      'sections': sections.map((item) => item.toJson()).toList(),
      'monthly': monthly.map((item) => item.toJson()).toList(),
      'top_spent_sections': topSpentSections
          .map((item) => item.toJson())
          .toList(),
      'no_movement_sections': noMovementSections
          .map((item) => item.toJson())
          .toList(),
    };
  }
}

class DashboardAnalyticsItem {
  const DashboardAnalyticsItem({
    required this.id,
    required this.label,
    this.subtitle,
    required this.totalAllocation,
    required this.totalReserved,
    required this.totalSpent,
    required this.remainingBalance,
    this.count = 0,
  });

  final String id;
  final String label;
  final String? subtitle;
  final double totalAllocation;
  final double totalReserved;
  final double totalSpent;
  final double remainingBalance;
  final int count;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'subtitle': subtitle,
      'total_allocation': totalAllocation,
      'total_reserved': totalReserved,
      'total_spent': totalSpent,
      'remaining_balance': remainingBalance,
      'count': count,
    };
  }
}

class DashboardMonthlyAnalyticsItem {
  const DashboardMonthlyAnalyticsItem({
    required this.month,
    required this.label,
    required this.totalReserved,
    required this.totalSpent,
  });

  final int month;
  final String label;
  final double totalReserved;
  final double totalSpent;

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'label': label,
      'total_reserved': totalReserved,
      'total_spent': totalSpent,
    };
  }
}

class DashboardNoMovementSection {
  const DashboardNoMovementSection({
    required this.sectionId,
    required this.programName,
    required this.sectionCode,
    required this.sectionName,
    required this.totalAllocation,
  });

  final String sectionId;
  final String programName;
  final String sectionCode;
  final String sectionName;
  final double totalAllocation;

  Map<String, dynamic> toJson() {
    return {
      'section_id': sectionId,
      'program_name': programName,
      'section_code': sectionCode,
      'section_name': sectionName,
      'total_allocation': totalAllocation,
    };
  }
}
