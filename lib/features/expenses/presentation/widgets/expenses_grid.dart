import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/expense_item.dart';
import '../../../../shared/widgets/grid_text_cells.dart';

class ExpensesDataSource extends DataGridSource {
  ExpensesDataSource({
    required this.items,
    required this.formatter,
    required this.onAttachments,
    required this.onPrintPaymentVoucher,
    required this.onPrintJournalVoucher,
    this.onCancel,
  });

  final List<ExpenseItem> items;
  final NumberFormat formatter;
  final Future<void> Function(ExpenseItem item) onAttachments;
  final Future<void> Function(ExpenseItem item) onPrintPaymentVoucher;
  final Future<void> Function(ExpenseItem item) onPrintJournalVoucher;
  final Future<void> Function(ExpenseItem item)? onCancel;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<ExpenseItem>(columnName: 'number', value: item),
            DataGridCell<ExpenseItem>(columnName: 'reservation', value: item),
            DataGridCell<ExpenseItem>(columnName: 'section', value: item),
            DataGridCell<ExpenseItem>(columnName: 'amount', value: item),
            DataGridCell<ExpenseItem>(columnName: 'date', value: item),
            DataGridCell<ExpenseItem>(columnName: 'status', value: item),
            DataGridCell<ExpenseItem>(columnName: 'documents', value: item),
            DataGridCell<ExpenseItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as ExpenseItem;
    return DataGridRowAdapter(
      cells: [
        GridCellText(item.expenseNumber),
        GridCellText(item.reservationNumber),
        GridCellText(item.budgetSectionName),
        GridCellText(formatter.format(item.amount)),
        GridCellText(item.expenseDate),
        GridCellText(item.expenseStatus == 'cancelled' ? 'ملغي' : 'مصروف'),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Center(
            child: OutlinedButton.icon(
              onPressed: () => onAttachments(item),
              icon: const Icon(Icons.attach_file, size: 18),
              label: const Text('مرفقات'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<_ExpenseAction>(
              tooltip: 'إجراءات الصرف',
              onSelected: (value) {
                switch (value) {
                  case _ExpenseAction.attachments:
                    onAttachments(item);
                  case _ExpenseAction.paymentVoucher:
                    onPrintPaymentVoucher(item);
                  case _ExpenseAction.journalVoucher:
                    onPrintJournalVoucher(item);
                  case _ExpenseAction.cancel:
                    onCancel?.call(item);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _ExpenseAction.attachments,
                  child: _ActionLabel(icon: Icons.attach_file, label: 'مرفقات'),
                ),
                const PopupMenuItem(
                  value: _ExpenseAction.paymentVoucher,
                  child: _ActionLabel(
                    icon: Icons.receipt_long_outlined,
                    label: 'طباعة سند صرف',
                  ),
                ),
                const PopupMenuItem(
                  value: _ExpenseAction.journalVoucher,
                  child: _ActionLabel(
                    icon: Icons.account_balance_outlined,
                    label: 'طباعة مستند قيد',
                  ),
                ),
                if (item.expenseStatus != 'cancelled' && onCancel != null)
                  const PopupMenuItem(
                    value: _ExpenseAction.cancel,
                    child: _ActionLabel(
                      icon: Icons.undo_outlined,
                      label: 'إلغاء الصرف',
                    ),
                  ),
              ],
              child: const Icon(Icons.more_horiz),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ExpenseAction { attachments, paymentVoucher, journalVoucher, cancel }

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );
  }
}
