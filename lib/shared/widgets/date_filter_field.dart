import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// حقل اختيار تاريخ لفلاتر القوائم، مع زر لمسح التاريخ.
class DateFilterField extends StatelessWidget {
  const DateFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.formatter,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(
          text: value == null ? '' : formatter.format(value!),
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.date_range_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(
                  tooltip: 'مسح التاريخ',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close),
                ),
        ),
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (selected != null) onChanged(selected);
        },
      ),
    );
  }
}
