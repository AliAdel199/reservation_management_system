class PaginationMeta {
  const PaginationMeta({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    int parse(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

    return PaginationMeta(
      total: parse(json['total']),
      page: parse(json['page']),
      pageSize: parse(json['page_size']),
      totalPages: parse(json['total_pages']),
    );
  }
}
