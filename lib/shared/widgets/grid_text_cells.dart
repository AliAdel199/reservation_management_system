import 'package:flutter/material.dart';

/// نص عنوان عمود في جداول SfDataGrid، محاذى لليمين.
class GridHeaderText extends StatelessWidget {
  const GridHeaderText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(alignment: Alignment.centerRight, child: Text(text)),
    );
  }
}

/// نص خلية في جداول SfDataGrid، محاذى لليمين.
class GridCellText extends StatelessWidget {
  const GridCellText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(alignment: Alignment.centerRight, child: Text(text)),
    );
  }
}
