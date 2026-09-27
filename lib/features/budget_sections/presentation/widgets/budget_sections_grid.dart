import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/budget_section_item.dart';

class BudgetSectionsDataSource extends DataGridSource {
  BudgetSectionsDataSource({
    required this.items,
    required this.formatter,
    required this.collapsedIds,
    required this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  final List<BudgetSectionItem> items;
  final NumberFormat formatter;
  final Set<String> collapsedIds;
  final ValueChanged<BudgetSectionItem> onToggle;
  final Future<void> Function(BudgetSectionItem item)? onEdit;
  final Future<void> Function(BudgetSectionItem item)? onDelete;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<BudgetSectionItem>(columnName: 'program', value: item),
            DataGridCell<BudgetSectionItem>(columnName: 'year', value: item),
            DataGridCell<BudgetSectionItem>(
              columnName: 'full_code',
              value: item,
            ),
            DataGridCell<BudgetSectionItem>(columnName: 'name', value: item),
            DataGridCell<BudgetSectionItem>(columnName: 'type', value: item),
            DataGridCell<BudgetSectionItem>(
              columnName: 'children',
              value: item,
            ),
            DataGridCell<BudgetSectionItem>(columnName: 'status', value: item),
            DataGridCell<BudgetSectionItem>(
              columnName: 'allocated',
              value: item,
            ),
            DataGridCell<BudgetSectionItem>(columnName: 'total', value: item),
            DataGridCell<BudgetSectionItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as BudgetSectionItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.programName),
        _GridCell(item.fiscalYearName ?? item.fiscalYear.toString()),
        _GridCell(item.fullCode),
        _TreeNameCell(
          item: item,
          isCollapsed: collapsedIds.contains(item.id),
          onToggle: onToggle,
        ),
        _GridCell(item.isPostable ? 'نهائي' : 'تجميعي'),
        _GridCell(item.childrenCount.toString()),
        _GridCell(item.isActive ? 'فعال' : 'معطل'),
        _GridCell(formatter.format(item.allocatedAmount)),
        _GridCell(formatter.format(item.totalAllocatedAmount)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (onEdit != null)
                IconButton(
                  onPressed: () => onEdit!(item),
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: () => onDelete!(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              if (onEdit == null && onDelete == null) const Text('معاينة'),
            ],
          ),
        ),
      ],
    );
  }
}

class BudgetSectionGridHeader extends StatelessWidget {
  const BudgetSectionGridHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: text,
          child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ),
    );
  }
}

class _TreeNameCell extends StatelessWidget {
  const _TreeNameCell({
    required this.item,
    required this.isCollapsed,
    required this.onToggle,
  });

  final BudgetSectionItem item;
  final bool isCollapsed;
  final ValueChanged<BudgetSectionItem> onToggle;

  @override
  Widget build(BuildContext context) {
    final indent = ((item.level - 1).clamp(0, 12) * 18).toDouble();
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 12 + indent,
        end: 12,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: item.childrenCount > 0 ? () => onToggle(item) : null,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                item.childrenCount > 0
                    ? (isCollapsed
                          ? Icons.keyboard_arrow_left_rounded
                          : Icons.keyboard_arrow_down_rounded)
                    : Icons.circle,
                size: item.childrenCount > 0 ? 22 : 8,
                color: item.isPostable
                    ? const Color(0xFF1A7F5A)
                    : const Color(0xFF0D4A73),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: '${item.fullCode} - ${item.name}',
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
