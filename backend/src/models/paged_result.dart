class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  int get totalPages => total == 0 ? 1 : (total / pageSize).ceil();

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T item) toJson) {
    return {
      'items': items.map(toJson).toList(),
      'pagination': {
        'total': total,
        'page': page,
        'page_size': pageSize,
        'total_pages': totalPages,
      },
    };
  }
}
