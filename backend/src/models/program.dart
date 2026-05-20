class Program {
  const Program({
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

  factory Program.fromRow(Map<String, dynamic> row) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return Program(
      id: row['id'].toString(),
      code: row['code'].toString(),
      name: row['name'].toString(),
      description: row['description']?.toString(),
      fiscalYearId: row['fiscal_year_id']?.toString(),
      fiscalYearName: row['fiscal_year_name']?.toString(),
      fiscalYear: parseInt(row['fiscal_year']),
      isActive: row['is_active'] as bool,
      budgetSectionsCount: parseInt(row['budget_sections_count']),
      fundingsCount: parseInt(row['fundings_count']),
      totalAllocations: parseDouble(row['total_allocations']),
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'fiscal_year_id': fiscalYearId,
      'fiscal_year_name': fiscalYearName,
      'fiscal_year': fiscalYear,
      'is_active': isActive,
      'budget_sections_count': budgetSectionsCount,
      'fundings_count': fundingsCount,
      'total_allocations': totalAllocations,
      'created_at': createdAt,
    };
  }
}
