class ProgramItem {
  const ProgramItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.fiscalYearId,
    required this.fiscalYearName,
    required this.fiscalYear,
    required this.isActive,
    required this.budgetSectionsCount,
    required this.fundingsCount,
    required this.totalAllocations,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? fiscalYearId;
  final String? fiscalYearName;
  final int fiscalYear;
  final bool isActive;
  final int budgetSectionsCount;
  final int fundingsCount;
  final double totalAllocations;
  final String createdAt;

  factory ProgramItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return ProgramItem(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description']?.toString(),
      fiscalYearId: json['fiscal_year_id']?.toString(),
      fiscalYearName: json['fiscal_year_name']?.toString(),
      fiscalYear: parseInt(json['fiscal_year']),
      isActive: json['is_active'] as bool? ?? false,
      budgetSectionsCount: parseInt(json['budget_sections_count']),
      fundingsCount: parseInt(json['fundings_count']),
      totalAllocations: parseDouble(json['total_allocations']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
