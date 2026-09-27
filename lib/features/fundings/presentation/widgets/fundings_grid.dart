import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../../models/funding_item.dart';
import '../../../../shared/widgets/grid_text_cells.dart';

class FundingsDataSource extends DataGridSource {
  FundingsDataSource({
    required this.items,
    required this.formatter,
    required this.onEdit,
  });

  final List<FundingItem> items;
  final NumberFormat formatter;
  final Future<void> Function(FundingItem item) onEdit;

  @override
  List<DataGridRow> get rows => items
      .map(
        (item) => DataGridRow(
          cells: [
            DataGridCell<FundingItem>(columnName: 'reference', value: item),
            DataGridCell<FundingItem>(columnName: 'program', value: item),
            DataGridCell<FundingItem>(columnName: 'section', value: item),
            DataGridCell<FundingItem>(columnName: 'year', value: item),
            DataGridCell<FundingItem>(
              columnName: 'initial_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(
              columnName: 'current_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(
              columnName: 'reserved_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(columnName: 'spent_amount', value: item),
            DataGridCell<FundingItem>(
              columnName: 'available_amount',
              value: item,
            ),
            DataGridCell<FundingItem>(columnName: 'actions', value: item),
          ],
        ),
      )
      .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final item = row.getCells().first.value as FundingItem;
    return DataGridRowAdapter(
      cells: [
        GridCellText(item.fundingReference),
        GridCellText(item.programName),
        GridCellText('${item.budgetSectionCode} - ${item.budgetSectionName}'),
        GridCellText(item.fiscalYear.toString()),
        GridCellText(formatter.format(item.allocatedAmount)),
        GridCellText(formatter.format(item.currentAllocatedAmount)),
        GridCellText(formatter.format(item.reservedAmount)),
        GridCellText(formatter.format(item.spentAmount)),
        GridCellText(formatter.format(item.availableAmount)),
        Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            onPressed: () => onEdit(item),
            icon: const Icon(Icons.edit_outlined),
          ),
        ),
      ],
    );
  }
}
