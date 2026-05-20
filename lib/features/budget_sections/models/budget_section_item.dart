class BudgetSectionItem {
  const BudgetSectionItem({
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

  factory BudgetSectionItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return BudgetSectionItem(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      programCode: json['program_code'] as String,
      programName: json['program_name'] as String,
      fiscalYearId: json['fiscal_year_id']?.toString(),
      fiscalYear: parseInt(json['fiscal_year']),
      fiscalYearName: json['fiscal_year_name']?.toString(),
      budgetTypeId: json['budget_type_id']?.toString(),
      budgetTypeCode: json['budget_type_code']?.toString(),
      budgetTypeName: json['budget_type_name']?.toString(),
      parentId: json['parent_id']?.toString(),
      level: parseInt(json['level']) == 0 ? 1 : parseInt(json['level']),
      fullCode: json['full_code']?.toString() ?? json['code'].toString(),
      isPostable: json['is_postable'] as bool? ?? true,
      sortOrder: parseInt(json['sort_order']),
      path: json['path']?.toString(),
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description']?.toString(),
      allocatedAmount: parseDouble(json['allocated_amount']),
      totalAllocatedAmount: parseDouble(
        json['total_allocated_amount'] ?? json['allocated_amount'],
      ),
      childrenCount: parseInt(json['children_count']),
      isActive: json['is_active'] as bool? ?? false,
      fundingsCount: parseInt(json['fundings_count']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
