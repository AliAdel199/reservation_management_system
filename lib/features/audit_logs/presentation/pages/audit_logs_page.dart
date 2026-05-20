import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/live_refresh_provider.dart';
import '../../../../shared/widgets/async_value_view.dart';
import '../controllers/audit_logs_controller.dart';

class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key});

  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditLogsControllerProvider);

    ref.listen(liveRefreshProvider, (previous, next) {
      if (next.hasValue) {
        ref
            .read(auditLogsControllerProvider.notifier)
            .refresh(showLoading: false);
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل الإجراءات',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'متابعة كل عمليات الإنشاء والتعديل والاعتماد والصرف والتسجيل.',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'بحث بالإجراء أو المستخدم أو الوصف',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) => ref
                      .read(auditLogsControllerProvider.notifier)
                      .search(value),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => ref
                    .read(auditLogsControllerProvider.notifier)
                    .search(_searchController.text),
                child: const Text('بحث'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: state,
                onRetry: () =>
                    ref.read(auditLogsControllerProvider.notifier).refresh(),
                data: (data) => Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1220,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('التاريخ')),
                                DataColumn(label: Text('الإجراء')),
                                DataColumn(label: Text('الجدول')),
                                DataColumn(label: Text('المستخدم')),
                                DataColumn(label: Text('الوصف')),
                                DataColumn(label: Text('IP')),
                              ],
                              rows: data.result.items.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(_shortDateTime(item.createdAt)),
                                    ),
                                    DataCell(Text(item.action)),
                                    DataCell(Text(item.entityType)),
                                    DataCell(
                                      Text(
                                        item.fullName ?? item.username ?? '-',
                                      ),
                                    ),
                                    DataCell(Text(item.description ?? '-')),
                                    DataCell(Text(item.ipAddress ?? '-')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _PaginationBar(
                      page: data.result.pagination.page,
                      totalPages: data.result.pagination.totalPages,
                      total: data.result.pagination.total,
                      onPrevious: data.result.pagination.page > 1
                          ? () => ref
                                .read(auditLogsControllerProvider.notifier)
                                .changePage(data.result.pagination.page - 1)
                          : null,
                      onNext:
                          data.result.pagination.page <
                              data.result.pagination.totalPages
                          ? () => ref
                                .read(auditLogsControllerProvider.notifier)
                                .changePage(data.result.pagination.page + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortDateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text('إجمالي السجلات: $total'),
          const Spacer(),
          OutlinedButton(onPressed: onPrevious, child: const Text('السابق')),
          const SizedBox(width: 8),
          Text('الصفحة $page من $totalPages'),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onNext, child: const Text('التالي')),
        ],
      ),
    );
  }
}
