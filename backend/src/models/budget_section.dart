class BudgetSection {
  const BudgetSection({
    required this.id,
    required this.programId,
    required this.programCode,
    required this.programName,
    required this.fiscalYearId,
    required this.fiscalYear,
    required this.fiscalYearName,
    required this.budgetTypeId,
    required this.budgetTypeCode,
    required this.budgetTypeName,
    required this.parentId,
    required this.level,
    required this.fullCode,
    required this.isPostable,
    required this.sortOrder,
    required this.path,
    required this.code,
    required this.name,
    required this.description,
    required this.allocatedAmount,
    required this.totalAllocatedAmount,
    required this.childrenCount,
    required this.isActive,
    required this.fundingsCount,
    required this.createdAt,
  });

  final String id;
  final String programId;
  final String programCode;
  final String programName;
  final String? fiscalYearId;
  final int fiscalYear;
  final String? fiscalYearName;
  final String? budgetTypeId;
  final String? budgetTypeCode;
  final String? budgetTypeName;
  final String? parentId;
  final int level;
  final String fullCode;
  final bool isPostable;
  final int sortOrder;
  final String? path;
  final String code;
  final String name;
  final String? description;
  final double allocatedAmount;
  final double totalAllocatedAmount;
  final int childrenCount;
  final bool isActive;
  final int fundingsCount;
  final String createdAt;

  factory BudgetSection.fromRow(Map<String, dynamic> row) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return BudgetSection(
      id: row['id'].toString(),
      programId: row['program_id'].toString(),
      programCode: row['program_code'].toString(),
      programName: row['program_name'].toString(),
      fiscalYearId: row['fiscal_year_id']?.toString(),
      fiscalYear: parseInt(row['fiscal_year']),
      fiscalYearName: row['fiscal_year_name']?.toString(),
      budgetTypeId: row['budget_type_id']?.toString(),
      budgetTypeCode: row['budget_type_code']?.toString(),
      budgetTypeName: row['budget_type_name']?.toString(),
      parentId: row['parent_id']?.toString(),
      level: parseInt(row['level']) == 0 ? 1 : parseInt(row['level']),
      fullCode: row['full_code']?.toString() ?? row['code'].toString(),
      isPostable: row['is_postable'] as bool? ?? true,
      sortOrder: parseInt(row['sort_order']),
      path: row['path']?.toString(),
      code: row['code'].toString(),
      name: row['name'].toString(),
      description: row['description']?.toString(),
      allocatedAmount: parseDouble(row['allocated_amount']),
      totalAllocatedAmount: parseDouble(
        row['total_allocated_amount'] ?? row['allocated_amount'],
      ),
      childrenCount: parseInt(row['children_count']),
      isActive: row['is_active'] as bool,
      fundingsCount: parseInt(row['fundings_count']),
      createdAt: row['created_at'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'program_id': programId,
      'program_code': programCode,
      'program_name': programName,
      'fiscal_year_id': fiscalYearId,
      'fiscal_year': fiscalYear,
      'fiscal_year_name': fiscalYearName,
      'budget_type_id': budgetTypeId,
      'budget_type_code': budgetTypeCode,
      'budget_type_name': budgetTypeName,
      'parent_id': parentId,
      'level': level,
      'full_code': fullCode,
      'is_postable': isPostable,
      'sort_order': sortOrder,
      'path': path,
      'code': code,
      'name': name,
      'description': description,
      'allocated_amount': allocatedAmount,
      'total_allocated_amount': totalAllocatedAmount,
      'children_count': childrenCount,
      'is_active': isActive,
      'fundings_count': fundingsCount,
      'created_at': createdAt,
    };
  }
}
