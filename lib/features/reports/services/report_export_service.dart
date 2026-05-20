import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/section_summary_item.dart';

class ReportExportService {
  const ReportExportService();

  Future<String> exportSectionSummaryHtml({
    required List<SectionSummaryItem> items,
    required Map<String, String> filters,
    required int selectedMonth,
    Set<String>? visibleColumns,
    required bool openAfterExport,
  }) async {
    final file = await _buildReportFile('section_summary', 'html');
    await file.writeAsString(
      _buildHtml(
        items: items,
        filters: filters,
        selectedMonth: selectedMonth,
        visibleColumns: visibleColumns,
      ),
      encoding: utf8,
    );

    if (openAfterExport) {
      await _openFile(file.path);
    }
    return file.path;
  }

  Future<String> exportSectionSummaryCsv({
    required List<SectionSummaryItem> items,
    required Map<String, String> filters,
    required int selectedMonth,
  }) async {
    final file = await _buildReportFile('section_summary', 'csv');
    final buffer = StringBuffer();
    final monthName = _reportMonthName(filters);
    // تعليق عربي: BOM يساعد Excel على قراءة العربية بشكل صحيح داخل CSV.
    buffer.write('\uFEFF');
    buffer.writeln(
      [
        'رمز الباب',
        'اسم الباب',
        'البرنامج',
        'السنة المالية',
        'التخصيص',
        'المحجوز من التخصيصات',
        'المتبقي من التخصيصات غير محجوز',
        'المصروف الفعلي',
        'المتبقي من التخصيصات حسب المصروف',
        'نسبة الحجز 1/12',
        'الحجز لغاية $monthName',
        'المبلغ القابل للصرف',
        'نسبة الحجز',
        'نسبة الصرف',
      ].map(_csvCell).join(','),
    );

    for (final item in items) {
      buffer.writeln(
        [
          item.sectionCode,
          item.sectionName,
          item.programName,
          item.fiscalYearName ?? '',
          item.allocatedAmount,
          item.totalReserved,
          item.remainingAllocation,
          item.totalSpent,
          item.effectiveRemainingBySpent(),
          item.effectiveMonthlyQuota(),
          item.effectivePeriodAllowed(selectedMonth),
          item.effectivePeriodDisposable(selectedMonth),
          item.reservationRate,
          item.spendingRate,
        ].map((value) => _csvCell(value.toString())).join(','),
      );
    }

    await file.writeAsString(buffer.toString(), encoding: utf8);
    await _openFile(file.path);
    return file.path;
  }

  Future<String> exportSectionSummaryXlsx({
    required List<SectionSummaryItem> items,
    required Map<String, String> filters,
    required int selectedMonth,
    Set<String>? visibleColumns,
  }) async {
    final file = await _buildReportFile('section_summary', 'xlsx');
    final excel = Excel.createExcel();
    const sheetName = 'ملخص الباب';
    final sheet = excel[sheetName];
    final monthName = _reportMonthName(filters);
    final totals = _ReportTotals.fromItems(items, selectedMonth);
    final columns = _visibleExportColumns(visibleColumns);

    // تعليق عربي: التصدير يتبع الأعمدة الظاهرة في الشاشة حتى لا يختلف التقرير.
    final headers = columns
        .map((column) => _columnHeader(column, monthName))
        .toList();

    _writeRow(sheet, 0, headers.map(_textValue).toList());
    for (var index = 0; index < headers.length; index++) {
      sheet.setColumnWidth(index, _columnWidth(columns[index]));
    }

    for (var rowIndex = 0; rowIndex < items.length; rowIndex++) {
      final item = items[rowIndex];
      _writeRow(
        sheet,
        rowIndex + 1,
        columns
            .map((column) => _xlsxCellValue(column, item, selectedMonth))
            .toList(),
      );
    }

    _writeRow(
      sheet,
      items.length + 1,
      List.generate(columns.length, (index) {
        if (index == 0) return _textValue('المجاميع النهائية');
        return _xlsxTotalCellValue(columns[index], totals);
      }),
    );

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('تعذر إنشاء ملف Excel.');
    }
    await file.writeAsBytes(bytes, flush: true);
    await _openFile(file.path);
    return file.path;
  }

  String _buildHtml({
    required List<SectionSummaryItem> items,
    required Map<String, String> filters,
    required int selectedMonth,
    Set<String>? visibleColumns,
  }) {
    final currency = NumberFormat.decimalPattern('ar_IQ');
    final printedAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final totals = _ReportTotals.fromItems(items, selectedMonth);
    final monthName = _reportMonthName(filters);
    final columns = _visibleExportColumns(visibleColumns);
    final filterBadges = filters.entries
        // تعليق عربي: الترويسة الرسمية للطباعة تعرض فقط السنة والشهر،
        // أما بقية خيارات العرض فهي للتحكم بالجدول داخل النظام.
        .where(
          (entry) =>
              entry.value.trim().isNotEmpty &&
              (entry.key == 'السنة المالية' || entry.key == 'الشهر'),
        )
        .map(
          (entry) =>
              '<span class="badge">${_escape(entry.key)}: ${_escape(entry.value)}</span>',
        )
        .join('');

    final headerCells = columns
        .map(
          (column) => '<th>${_escape(_columnHeader(column, monthName))}</th>',
        )
        .join('');
    final rows = items
        .map((item) {
          final cells = columns
              .map((column) {
                final value = _htmlCellValue(
                  column,
                  item,
                  currency,
                  selectedMonth,
                );
                final cssClass =
                    column == 'periodDisposable' &&
                        item.effectivePeriodDisposable(selectedMonth) < 0
                    ? ' class="negative"'
                    : '';
                return '<td$cssClass>${_escape(value)}</td>';
              })
              .join('');
          return '<tr>$cells</tr>';
        })
        .join('');
    final footerCells = List.generate(columns.length, (index) {
      if (index == 0) return '<td>المجاميع النهائية</td>';
      return '<td>${_escape(_htmlTotalCellValue(columns[index], totals, currency))}</td>';
    }).join('');

    return '''
<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <title>تقرير ملخص الباب</title>
  <style>
    @page { size: A4 landscape; margin: 12mm; }
    body {
      font-family: "Segoe UI", Tahoma, Arial, sans-serif;
      direction: rtl;
      color: #17212b;
      background: #ffffff;
      margin: 0;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      border-bottom: 3px solid #0f4c75;
      padding-bottom: 12px;
      margin-bottom: 14px;
    }
    .title h1 { margin: 0 0 6px; font-size: 24px; color: #0b2d45; }
    .title p { margin: 0; color: #52616f; }
    .meta { text-align: left; font-size: 12px; color: #52616f; line-height: 1.8; }
    .print-note {
      margin: 0 12px 12px;
      color: #7a4b00;
      background: #fff7df;
      border: 1px solid #f0c36a;
      border-radius: 10px;
      padding: 8px 12px;
      font-size: 12px;
    }
    .filters { margin: 10px 0 14px; }
    .badge {
      display: inline-block;
      border: 1px solid #c9d6df;
      background: #f5f8fb;
      border-radius: 999px;
      padding: 5px 10px;
      margin: 3px;
      font-size: 12px;
    }
    table { width: 100%; border-collapse: collapse; font-size: 11px; }
    th {
      background: #fff200;
      border: 1px solid #222;
      padding: 7px 5px;
      text-align: center;
      font-weight: 700;
    }
    td {
      border: 1px solid #333;
      padding: 6px 5px;
      text-align: center;
      white-space: nowrap;
    }
    td { text-align: center; }
    tfoot td { font-weight: 800; background: #eef5f9; }
    .negative { color: #b42318; background: #fde8e8; }
    .footer {
      margin-top: 18px;
      display: flex;
      justify-content: space-between;
      color: #52616f;
      font-size: 12px;
    }
    @media print {
      .no-print { display: none; }
      body { print-color-adjust: exact; -webkit-print-color-adjust: exact; }
    }
  </style>
</head>
<body>
  <button class="no-print" onclick="window.print()" style="margin: 12px; padding: 8px 18px;">طباعة التقرير</button>
  <div class="no-print print-note">إذا ظهر مسار الملف أسفل الورقة من نافذة الطباعة، ألغِ خيار Headers and footers في إعدادات Chrome.</div>
  <section class="header">
    <div class="title">
      <h1>تقرير ملخص الباب</h1>
      <p>نظام إدارة الحجوزات المالية الحكومية</p>
    </div>
    <div class="meta">
      <div>تاريخ الطباعة: $printedAt</div>
      <div>عدد السجلات: ${items.length}</div>
    </div>
  </section>
  <section class="filters">$filterBadges</section>
  <table>
    <thead>
      <tr>
        $headerCells
      </tr>
    </thead>
    <tbody>$rows</tbody>
    <tfoot>
      <tr>
        $footerCells
      </tr>
    </tfoot>
  </table>
  <section class="footer">
    <span>إعداد النظام المالي الحكومي</span>
    <span>يعتمد التقرير على سجل الحركات المالية Ledger</span>
  </section>
</body>
</html>
''';
  }

  Future<File> _buildReportFile(String name, String extension) async {
    final directory = await _reportsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return File('${directory.path}\\${name}_$timestamp.$extension');
  }

  List<String> _visibleExportColumns(Set<String>? visibleColumns) {
    const ordered = [
      'program',
      'section',
      'allocation',
      'reserved',
      'unreserved',
      'spent',
      'remainingBySpent',
      'monthlyQuota',
      'periodAllowed',
      'periodDisposable',
      'rates',
    ];
    final result = ordered
        .where(
          (column) => visibleColumns == null || visibleColumns.contains(column),
        )
        .toList();
    return result.isEmpty ? ordered : result;
  }

  String _columnHeader(String column, String monthName) {
    switch (column) {
      case 'program':
        return 'البرنامج';
      case 'section':
        return 'الباب';
      case 'allocation':
        return 'التخصيص';
      case 'reserved':
        return 'المحجوز من التخصيصات';
      case 'unreserved':
        return 'المتبقي من التخصيصات غير محجوز';
      case 'spent':
        return 'المصروف الفعلي';
      case 'remainingBySpent':
        return 'المتبقي من التخصيصات حسب المصروف';
      case 'monthlyQuota':
        return 'نسبة الحجز 1/12';
      case 'periodAllowed':
        return 'الحجز لغاية $monthName';
      case 'periodDisposable':
        return 'المبلغ القابل للصرف';
      case 'rates':
        return 'النسب';
      default:
        return column;
    }
  }

  double _columnWidth(String column) {
    switch (column) {
      case 'program':
        return 24;
      case 'section':
        return 34;
      case 'unreserved':
      case 'remainingBySpent':
        return 28;
      case 'rates':
        return 24;
      default:
        return 20;
    }
  }

  String _htmlCellValue(
    String column,
    SectionSummaryItem item,
    NumberFormat currency,
    int selectedMonth,
  ) {
    switch (column) {
      case 'program':
        return item.programName;
      case 'section':
        return '${item.sectionCode} - ${item.sectionName}';
      case 'allocation':
        return currency.format(item.allocatedAmount);
      case 'reserved':
        return currency.format(item.totalReserved);
      case 'unreserved':
        return currency.format(item.remainingAllocation);
      case 'spent':
        return currency.format(item.totalSpent);
      case 'remainingBySpent':
        return currency.format(item.effectiveRemainingBySpent());
      case 'monthlyQuota':
        return currency.format(item.effectiveMonthlyQuota());
      case 'periodAllowed':
        return currency.format(item.effectivePeriodAllowed(selectedMonth));
      case 'periodDisposable':
        return currency.format(item.effectivePeriodDisposable(selectedMonth));
      case 'rates':
        return 'حجز ${item.reservationRate.toStringAsFixed(1)}% / صرف ${item.spendingRate.toStringAsFixed(1)}%';
      default:
        return '';
    }
  }

  CellValue _xlsxCellValue(
    String column,
    SectionSummaryItem item,
    int selectedMonth,
  ) {
    switch (column) {
      case 'program':
        return _textValue(item.programName);
      case 'section':
        return _textValue('${item.sectionCode} - ${item.sectionName}');
      case 'allocation':
        return _numberValue(item.allocatedAmount);
      case 'reserved':
        return _numberValue(item.totalReserved);
      case 'unreserved':
        return _numberValue(item.remainingAllocation);
      case 'spent':
        return _numberValue(item.totalSpent);
      case 'remainingBySpent':
        return _numberValue(item.effectiveRemainingBySpent());
      case 'monthlyQuota':
        return _numberValue(item.effectiveMonthlyQuota());
      case 'periodAllowed':
        return _numberValue(item.effectivePeriodAllowed(selectedMonth));
      case 'periodDisposable':
        return _numberValue(item.effectivePeriodDisposable(selectedMonth));
      case 'rates':
        return _textValue(
          'حجز ${item.reservationRate.toStringAsFixed(1)}% / صرف ${item.spendingRate.toStringAsFixed(1)}%',
        );
      default:
        return _textValue('');
    }
  }

  String _htmlTotalCellValue(
    String column,
    _ReportTotals totals,
    NumberFormat currency,
  ) {
    switch (column) {
      case 'allocation':
        return currency.format(totals.allocated);
      case 'reserved':
        return currency.format(totals.reserved);
      case 'unreserved':
        return currency.format(totals.remainingAllocation);
      case 'spent':
        return currency.format(totals.spent);
      case 'remainingBySpent':
        return currency.format(totals.remainingBySpent);
      case 'monthlyQuota':
        return currency.format(totals.monthlyQuota);
      case 'periodAllowed':
        return currency.format(totals.periodAllowed);
      case 'periodDisposable':
        return currency.format(totals.periodDisposable);
      default:
        return '';
    }
  }

  CellValue _xlsxTotalCellValue(String column, _ReportTotals totals) {
    switch (column) {
      case 'allocation':
        return _numberValue(totals.allocated);
      case 'reserved':
        return _numberValue(totals.reserved);
      case 'unreserved':
        return _numberValue(totals.remainingAllocation);
      case 'spent':
        return _numberValue(totals.spent);
      case 'remainingBySpent':
        return _numberValue(totals.remainingBySpent);
      case 'monthlyQuota':
        return _numberValue(totals.monthlyQuota);
      case 'periodAllowed':
        return _numberValue(totals.periodAllowed);
      case 'periodDisposable':
        return _numberValue(totals.periodDisposable);
      default:
        return _textValue('');
    }
  }

  Future<Directory> _reportsDirectory() async {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final directory = Directory('$home\\Downloads\\reservation_reports');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> _openFile(String path) async {
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

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  TextCellValue _textValue(String value) => TextCellValue(value);

  DoubleCellValue _numberValue(double value) => DoubleCellValue(value);

  void _writeRow(Sheet sheet, int rowIndex, List<CellValue> values) {
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
      );
      cell.value = values[columnIndex];
    }
  }

  String _reportMonthName(Map<String, String> filters) {
    final month = filters['الشهر']?.trim();
    return month == null || month.isEmpty ? 'الشهر' : month;
  }

  String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

class _ReportTotals {
  const _ReportTotals({
    required this.allocated,
    required this.reserved,
    required this.spent,
    required this.remainingAllocation,
    required this.remainingBySpent,
    required this.monthlyQuota,
    required this.periodAllowed,
    required this.periodDisposable,
  });

  final double allocated;
  final double reserved;
  final double spent;
  final double remainingAllocation;
  final double remainingBySpent;
  final double monthlyQuota;
  final double periodAllowed;
  final double periodDisposable;

  factory _ReportTotals.fromItems(
    List<SectionSummaryItem> items,
    int selectedMonth,
  ) {
    return _ReportTotals(
      allocated: items.fold(0, (sum, item) => sum + item.allocatedAmount),
      reserved: items.fold(0, (sum, item) => sum + item.totalReserved),
      spent: items.fold(0, (sum, item) => sum + item.totalSpent),
      remainingAllocation: items.fold(
        0,
        (sum, item) => sum + item.remainingAllocation,
      ),
      remainingBySpent: items.fold(
        0,
        (sum, item) => sum + item.effectiveRemainingBySpent(),
      ),
      monthlyQuota: items.fold(
        0,
        (sum, item) => sum + item.effectiveMonthlyQuota(),
      ),
      periodAllowed: items.fold(
        0,
        (sum, item) => sum + item.effectivePeriodAllowed(selectedMonth),
      ),
      periodDisposable: items.fold(
        0,
        (sum, item) => sum + item.effectivePeriodDisposable(selectedMonth),
      ),
    );
  }
}
