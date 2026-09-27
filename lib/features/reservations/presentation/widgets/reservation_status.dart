import 'package:flutter/material.dart';

class ReservationStatusBadge extends StatelessWidget {
  const ReservationStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = ReservationStatusStyle.fromStatus(status);

    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: style.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ReservationStatusStyle {
  const ReservationStatusStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  factory ReservationStatusStyle.fromStatus(String status) {
    switch (status) {
      case 'draft':
      case 'under_review':
        return const ReservationStatusStyle(
          label: 'محجوز',
          background: Color(0xFFE9EEF5),
          foreground: Color(0xFF35536B),
        );
      case 'approved':
        return const ReservationStatusStyle(
          label: 'معتمد',
          background: Color(0xFFDEF7EC),
          foreground: Color(0xFF0F7B49),
        );
      case 'partially_spent':
      case 'completed':
      case 'fully_spent':
        return const ReservationStatusStyle(
          label: 'مصروف',
          background: Color(0xFFE7F6E7),
          foreground: Color(0xFF256029),
        );
      case 'cancelled':
        return const ReservationStatusStyle(
          label: 'ملغي',
          background: Color(0xFFFDE8E8),
          foreground: Color(0xFFB42318),
        );
      default:
        return const ReservationStatusStyle(
          label: 'غير معروف',
          background: Color(0xFFE9EEF5),
          foreground: Color(0xFF35536B),
        );
    }
  }
}
