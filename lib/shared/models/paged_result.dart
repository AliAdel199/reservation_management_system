import 'pagination_meta.dart';

class PagedResult<T> {
  const PagedResult({required this.items, required this.pagination});

  final List<T> items;
  final PaginationMeta pagination;

  factory PagedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemBuilder,
  ) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final rawPagination =
        json['pagination'] as Map<String, dynamic>? ?? const {};

    return PagedResult<T>(
      items: rawItems
          .whereType<Map>()
          .map((item) => itemBuilder(Map<String, dynamic>.from(item)))
          .toList(),
      pagination: PaginationMeta.fromJson(rawPagination),
    );
  }
}
