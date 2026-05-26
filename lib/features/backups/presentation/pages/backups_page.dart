import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../models/database_backup_item.dart';
import '../controllers/backups_controller.dart';

class BackupsPage extends ConsumerStatefulWidget {
  const BackupsPage({super.key});

  @override
  ConsumerState<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends ConsumerState<BackupsPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backupsControllerProvider);

    ref.listen(backupsControllerProvider, (previous, next) {
      if (next.hasError && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'النسخ الاحتياطي والاسترجاع',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إدارة نسخ قاعدة البيانات قبل التسليم أو قبل أي تعديل حساس.',
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => ref
                          .read(backupsControllerProvider.notifier)
                          .refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _createBackup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('إنشاء Backup'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _WarningBox(),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: state,
                onRetry: () =>
                    ref.read(backupsControllerProvider.notifier).refresh(),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Text('لا توجد نسخ احتياطية محفوظة حالياً.'),
                      )
                    : _BackupsTable(
                        items: items,
                        busy: _busy,
                        onRestore: _restoreBackup,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      await ref.read(backupsControllerProvider.notifier).createBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية بنجاح')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(DatabaseBackupItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاسترجاع'),
        content: Text(
          'سيتم استبدال بيانات النظام الحالية بالنسخة:\n${item.fileName}\n\n'
          'يفضل إنشاء Backup جديد قبل الاسترجاع. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('استرجاع'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(backupsControllerProvider.notifier)
          .restoreBackup(item.fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استرجاع قاعدة البيانات بنجاح')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _WarningBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.25)),
      ),
      child: const Text(
        'تنبيه: الاسترجاع يرجع قاعدة البيانات إلى حالة النسخة المختارة. '
        'استخدمه فقط عند الحاجة، ويفضل إيقاف العمل على باقي الأجهزة أثناء العملية.',
      ),
    );
  }
}

class _BackupsTable extends StatelessWidget {
  const _BackupsTable({
    required this.items,
    required this.busy,
    required this.onRestore,
  });

  final List<DatabaseBackupItem> items;
  final bool busy;
  final ValueChanged<DatabaseBackupItem> onRestore;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 980,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('اسم الملف')),
                    DataColumn(label: Text('تاريخ الإنشاء')),
                    DataColumn(label: Text('الحجم')),
                    DataColumn(label: Text('المسار')),
                    DataColumn(label: Text('إجراءات')),
                  ],
                  rows: items.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item.fileName)),
                        DataCell(Text(formatter.format(item.createdAt))),
                        DataCell(Text(_formatSize(item.sizeBytes))),
                        DataCell(Text(item.path)),
                        DataCell(
                          FilledButton.tonalIcon(
                            onPressed: busy ? null : () => onRestore(item),
                            icon: const Icon(Icons.restore),
                            label: const Text('استرجاع'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [Text('إجمالي النسخ: ${items.length}')]),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
