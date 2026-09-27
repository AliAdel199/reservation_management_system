import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/reservation_item.dart';
import 'reservation_status.dart';
import 'reservation_formatting.dart';

class ReservationsDataSource extends DataGridSource {
  ReservationsDataSource({
    required this.items,
    required this.formatter,
    required this.onDetails,
    this.onEdit,
    this.onSubmit,
    this.onApprove,
    this.onCancel,
    this.onSpend,
    this.onDelete,
    required this.onAttachments,
  });

  final List<ReservationItem> items;
  final NumberFormat formatter;
  final Future<void> Function(ReservationItem item) onDetails;
  final Future<void> Function(ReservationItem item)? onEdit;
  final Future<void> Function(ReservationItem item)? onSubmit;
  final Future<void> Function(ReservationItem item)? onApprove;
  final Future<void> Function(ReservationItem item)? onCancel;
  final void Function(ReservationItem item)? onSpend;
  final Future<void> Function(ReservationItem item)? onDelete;
  final Future<void> Function(ReservationItem item) onAttachments;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<ReservationItem>(columnName: 'number', value: item),
            DataGridCell<ReservationItem>(columnName: 'title', value: item),
            DataGridCell<ReservationItem>(
              columnName: 'department',
              value: item,
            ),
            DataGridCell<ReservationItem>(columnName: 'phone', value: item),
            DataGridCell<ReservationItem>(
              columnName: 'section_code',
              value: item,
            ),
            DataGridCell<ReservationItem>(
              columnName: 'section_name',
              value: item,
            ),
            DataGridCell<ReservationItem>(columnName: 'budget', value: item),
            DataGridCell<ReservationItem>(columnName: 'amount', value: item),
            DataGridCell<ReservationItem>(columnName: 'date', value: item),
            DataGridCell<ReservationItem>(
              columnName: 'execution_note',
              value: item,
            ),
            DataGridCell<ReservationItem>(columnName: 'status', value: item),
            DataGridCell<ReservationItem>(columnName: 'spent', value: item),
            DataGridCell<ReservationItem>(columnName: 'remaining', value: item),
            DataGridCell<ReservationItem>(columnName: 'documents', value: item),
            DataGridCell<ReservationItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as ReservationItem;
    return DataGridRowAdapter(
      cells: [
        _GridCell(item.reservationNumber),
        _GridCell(displayOrDash(item.beneficiary)),
        _GridCell(displayOrDash(item.requesterDepartment)),
        _GridCell(displayOrDash(item.contactPhone)),
        _GridCell(item.budgetSectionCode),
        _GridCell(item.budgetSectionName),
        _GridCell(item.programName),
        _GridCell(formatter.format(item.reservedAmount)),
        _GridCell(dateOnly(item.reservationDate)),
        _GridCell(displayOrDash(item.executionNote)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: ReservationStatusBadge(status: item.workflowStatus),
          ),
        ),
        _GridCell(formatter.format(item.spentAmount)),
        _GridCell(formatter.format(item.remainingAmount)),
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
            child: _ReservationActionsMenu(
              item: item,
              onDetails: onDetails,
              onEdit: onEdit,
              onSubmit: onSubmit,
              onApprove: onApprove,
              onCancel: onCancel,
              onSpend: onSpend,
              onDelete: onDelete,
              onAttachments: onAttachments,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReservationActionsMenu extends StatelessWidget {
  const _ReservationActionsMenu({
    required this.item,
    required this.onDetails,
    this.onEdit,
    this.onSubmit,
    this.onApprove,
    this.onCancel,
    this.onSpend,
    this.onDelete,
    required this.onAttachments,
  });

  final ReservationItem item;
  final Future<void> Function(ReservationItem item) onDetails;
  final Future<void> Function(ReservationItem item)? onEdit;
  final Future<void> Function(ReservationItem item)? onSubmit;
  final Future<void> Function(ReservationItem item)? onApprove;
  final Future<void> Function(ReservationItem item)? onCancel;
  final void Function(ReservationItem item)? onSpend;
  final Future<void> Function(ReservationItem item)? onDelete;
  final Future<void> Function(ReservationItem item) onAttachments;

  @override
  Widget build(BuildContext context) {
    final canSpend =
        item.remainingAmount > 0 && item.workflowStatus == 'approved';
    final actions = <PopupMenuEntry<_ReservationAction>>[
      const PopupMenuItem(
        value: _ReservationAction.details,
        child: _ActionLabel(icon: Icons.visibility_outlined, label: 'تفاصيل'),
      ),
      const PopupMenuItem(
        value: _ReservationAction.attachments,
        child: _ActionLabel(icon: Icons.attach_file, label: 'مرفقات'),
      ),
      if (onEdit != null &&
          (item.workflowStatus == 'draft' ||
              item.workflowStatus == 'under_review'))
        const PopupMenuItem(
          value: _ReservationAction.edit,
          child: _ActionLabel(icon: Icons.edit_outlined, label: 'تعديل'),
        ),
      if (onApprove != null &&
          (item.workflowStatus == 'draft' ||
              item.workflowStatus == 'under_review'))
        const PopupMenuItem(
          value: _ReservationAction.approve,
          child: _ActionLabel(icon: Icons.verified_outlined, label: 'اعتماد'),
        ),
      if (onSpend != null && canSpend)
        const PopupMenuItem(
          value: _ReservationAction.spend,
          child: _ActionLabel(icon: Icons.payments_outlined, label: 'صرف'),
        ),
      if (onCancel != null &&
          (item.workflowStatus == 'draft' ||
              item.workflowStatus == 'under_review' ||
              item.workflowStatus == 'approved'))
        const PopupMenuItem(
          value: _ReservationAction.cancel,
          child: _ActionLabel(icon: Icons.cancel_outlined, label: 'إلغاء'),
        ),
      if (onDelete != null && item.workflowStatus == 'cancelled')
        const PopupMenuItem(
          value: _ReservationAction.delete,
          child: _ActionLabel(icon: Icons.delete_outline, label: 'حذف'),
        ),
    ];

    return PopupMenuButton<_ReservationAction>(
      tooltip: 'إجراءات الحجز',
      onSelected: (value) {
        switch (value) {
          case _ReservationAction.details:
            onDetails(item);
          case _ReservationAction.edit:
            onEdit?.call(item);
          case _ReservationAction.submit:
            onSubmit?.call(item);
          case _ReservationAction.approve:
            onApprove?.call(item);
          case _ReservationAction.spend:
            onSpend?.call(item);
          case _ReservationAction.cancel:
            onCancel?.call(item);
          case _ReservationAction.delete:
            onDelete?.call(item);
          case _ReservationAction.attachments:
            onAttachments(item);
        }
      },
      itemBuilder: (_) => actions,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFC9D6DF)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 18),
            SizedBox(width: 6),
            Text('إجراءات'),
          ],
        ),
      ),
    );
  }
}

enum _ReservationAction {
  details,
  edit,
  submit,
  approve,
  spend,
  cancel,
  delete,
  attachments,
}

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

class ReservationGridHeader extends StatelessWidget {
  const ReservationGridHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
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
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
