class BudgetTypeItem {
  const BudgetTypeItem({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final bool isActive;
  final String createdAt;

  factory BudgetTypeItem.fromJson(Map<String, dynamic> json) {
    return BudgetTypeItem(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description']?.toString(),
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
