import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/reservation_item.dart';
import 'reservation_status.dart';
import 'reservation_formatting.dart';

class ReservationDetailsDialog extends StatelessWidget {
  const ReservationDetailsDialog({
    super.key,
    required this.item,
    required this.formatter,
  });

  final ReservationItem item;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    final status = ReservationStatusStyle.fromStatus(item.workflowStatus);

    return AlertDialog(
      title: Text('تفاصيل الحجز ${item.reservationNumber}'),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DetailsPill(
                    label: 'الحالة',
                    value: status.label,
                    color: status.foreground,
                    background: status.background,
                  ),
                  _DetailsPill(
                    label: 'المبلغ',
                    value: formatter.format(item.reservedAmount),
                    color: const Color(0xFF123B56),
                    background: const Color(0xFFEFF6FA),
                  ),
                  _DetailsPill(
                    label: 'المتبقي',
                    value: formatter.format(item.remainingAmount),
                    color: const Color(0xFF0F7B49),
                    background: const Color(0xFFDEF7EC),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _DetailsRow(label: 'العنوان', value: item.title),
              _DetailsRow(
                label: 'الجهة المحجوز لها',
                value: displayOrDash(item.beneficiary),
              ),
              _DetailsRow(
                label: 'القسم',
                value: displayOrDash(item.requesterDepartment),
              ),
              _DetailsRow(
                label: 'رقم الهاتف',
                value: displayOrDash(item.contactPhone),
              ),
              _DetailsRow(label: 'البرنامج', value: item.programName),
              _DetailsRow(label: 'رمز الباب', value: item.budgetSectionCode),
              _DetailsRow(label: 'اسم الباب', value: item.budgetSectionName),
              _DetailsRow(
                label: 'مصدر التخصيص',
                value: 'التخصيص السنوي للباب المختار',
              ),
              _DetailsRow(label: 'تاريخ الحجز', value: item.reservationDate),
              _DetailsRow(
                label: 'المصروف',
                value: formatter.format(item.spentAmount),
              ),
              _DetailsRow(
                label: 'الرصيد المتاح عند القراءة',
                value: formatter.format(item.fundingAvailableBalance),
              ),
              if (item.approvedAt != null)
                _DetailsRow(label: 'تاريخ الاعتماد', value: item.approvedAt!),
              if (item.cancelledAt != null)
                _DetailsRow(label: 'تاريخ الإلغاء', value: item.cancelledAt!),
              if (item.closedAt != null)
                _DetailsRow(label: 'تاريخ الإغلاق', value: item.closedAt!),
              _DetailsRow(label: 'تاريخ الإنشاء', value: item.createdAt),
              if ((item.executionNote ?? '').trim().isNotEmpty)
                _DetailsRow(
                  label: 'ملاحظة تنفيذ المحجوز',
                  value: item.executionNote!,
                ),
              if ((item.description ?? '').trim().isNotEmpty)
                _DetailsRow(label: 'الوصف', value: item.description!),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _DetailsPill extends StatelessWidget {
  const _DetailsPill({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
