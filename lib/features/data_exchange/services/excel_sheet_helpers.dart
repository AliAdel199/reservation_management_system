import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

// تعليق عربي: أدوات قراءة وكتابة ملفات Excel المشتركة بين الاستيراد والتصدير.

Future<File> buildDownloadsFile({
  required String prefix,
  required String extension,
}) async {
  final home =
      Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final directory = Directory('$home\\Downloads\\reservation_import_export');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  return File('${directory.path}\\${prefix}_$timestamp.$extension');
}

Future<void> openFile(String path) async {
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', path]);
    return;
  }
  if (Platform.isMacOS) {
    await Process.run('open', [path]);
    return;
  }
  await Process.run('xdg-open', [path]);
}

Sheet? findSheet(Excel excel, List<String> names) {
  for (final name in names) {
    final sheet = excel.tables[name];
    if (sheet != null) {
      return sheet;
    }
  }
  return null;
}

void writeRow(Sheet sheet, int rowIndex, List<CellValue> values) {
  for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
    sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: columnIndex,
                rowIndex: rowIndex,
              ),
            )
            .value =
        values[columnIndex];
  }
}

bool rowIsEmpty(List<Data?> row) {
  return row.every((cell) => cellText(cell).trim().isEmpty);
}

String cellText(Data? cell) {
  final value = cell?.value;
  return switch (value) {
    null => '',
    TextCellValue() => (value.value.text ?? '').trim(),
    IntCellValue() => value.value.toString(),
    DoubleCellValue() => value.value.toString(),
    BoolCellValue() => value.value ? 'true' : 'false',
    DateCellValue() => DateFormat('yyyy-MM-dd').format(value.asDateTimeLocal()),
    DateTimeCellValue() => DateFormat(
      'yyyy-MM-dd',
    ).format(value.asDateTimeLocal()),
    FormulaCellValue() => value.formula,
    TimeCellValue() => value.asDuration().toString(),
  };
}

Map<String, int> headerMap(List<Data?> row) {
  final headers = <String, int>{};
  for (var index = 0; index < row.length; index++) {
    final value = normalizeHeader(cellText(row.elementAtOrNull(index)));
    if (value.isNotEmpty) {
      headers[value] = index;
    }
  }
  return headers;
}

String cellByHeaders(
  List<Data?> row,
  Map<String, int> headers,
  List<String> names, {
  required int fallbackIndex,
}) {
  for (final name in names) {
    final index = headers[normalizeHeader(name)];
    if (index != null) {
      return cellText(row.elementAtOrNull(index));
    }
  }

  if (fallbackIndex < 0) {
    return '';
  }
  return cellText(row.elementAtOrNull(fallbackIndex));
}

String normalizeHeader(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
