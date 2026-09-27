import 'package:flutter/material.dart';

class CancelExpenseDialog extends StatefulWidget {
  const CancelExpenseDialog({super.key});

  @override
  State<CancelExpenseDialog> createState() => _CancelExpenseDialogState();
}

class _CancelExpenseDialogState extends State<CancelExpenseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إلغاء الصرف'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('تراجع'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('تأكيد الإلغاء'),
        ),
      ],
    );
  }
}
