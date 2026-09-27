import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

import '../../institution/models/institution_settings_item.dart';
import '../models/expense_item.dart';

class ExpenseDocumentPrintService {
  const ExpenseDocumentPrintService();

  Future<String> printPaymentVoucher({
    required ExpenseItem expense,
    InstitutionSettingsItem? institutionSettings,
  }) {
    return _buildAndOpenDocument(
      filePrefix: 'payment_voucher',
      title: 'سند صرف',
      expense: expense,
      institutionSettings: institutionSettings,
      isPaymentVoucher: true,
    );
  }

  Future<String> printJournalVoucher({
    required ExpenseItem expense,
    InstitutionSettingsItem? institutionSettings,
  }) {
    return _buildAndOpenDocument(
      filePrefix: 'journal_voucher',
      title: 'مستند قيد',
      expense: expense,
      institutionSettings: institutionSettings,
      isPaymentVoucher: false,
    );
  }

  Future<String> _buildAndOpenDocument({
    required String filePrefix,
    required String title,
    required ExpenseItem expense,
    required InstitutionSettingsItem? institutionSettings,
    required bool isPaymentVoucher,
  }) async {
    final directory = await _documentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final path = '${directory.path}\\${filePrefix}_$timestamp.html';
    final html = _buildHtml(
      title: title,
      expense: expense,
      institutionSettings: institutionSettings,
      isPaymentVoucher: isPaymentVoucher,
    );

    await File(path).writeAsString(html, encoding: utf8);
    await _openFile(path);
    return path;
  }

  String _buildHtml({
    required String title,
    required ExpenseItem expense,
    required InstitutionSettingsItem? institutionSettings,
    required bool isPaymentVoucher,
  }) {
    final currency = NumberFormat.currency(
      locale: 'ar_IQ',
      symbol: 'د.ع',
      decimalDigits: 0,
    );
    final amount = currency.format(expense.amount);
    final documentDate = _displayDate(
      expense.documentDate ?? expense.expenseDate,
    );
    final expenseDate = _displayDate(expense.expenseDate);
    final documentNumber = _safeValue(
      expense.documentNumber,
      expense.expenseNumber,
    );
    final description = _safeValue(
      expense.description,
      'صرف مرتبط بالحجز ${expense.reservationNumber}',
    );
    final payee = _payeeName(expense);
    final reservationNote = _reservationNote(expense);
    final purpose = _paymentPurpose(expense, description);
    final accountingGuide = _accountingGuide(expense);
    final sectionLabel = _sectionLabel(expense);
    final paymentMethod = _paymentMethodLabel(expense.paymentMethod);

    return '''
<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <title>${_escape(title)} - ${_escape(expense.expenseNumber)}</title>
  <style>
    @page { size: A4 portrait; margin: 12mm; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Arial", "Tahoma", sans-serif;
      color: #111827;
      background: #f4f6f8;
      direction: rtl;
    }
    .toolbar {
      padding: 14px 20px;
      background: #fff;
      border-bottom: 1px solid #d8dee6;
      text-align: left;
    }
    .print-button {
      border: 1px solid #0d4a73;
      color: #0d4a73;
      background: #fff;
      border-radius: 8px;
      padding: 8px 18px;
      cursor: pointer;
      font-size: 14px;
    }
    .page {
      width: 210mm;
      min-height: 297mm;
      margin: 12px auto;
      padding: 12mm;
      background: #fff;
      border: 1px solid #d4d9e1;
    }
    .header {
      display: grid;
      grid-template-columns: 1fr 1.2fr 1fr;
      align-items: start;
      gap: 14px;
      border-bottom: 3px solid #0d4a73;
      padding-bottom: 12px;
      margin-bottom: 14px;
    }
    .org-lines {
      line-height: 1.8;
      font-size: 13px;
    }
    .doc-title {
      text-align: center;
    }
    h1 {
      margin: 0;
      font-size: 28px;
      color: #0b3551;
      font-weight: 800;
    }
    .sub-title {
      margin-top: 6px;
      color: #4b5563;
      font-size: 13px;
    }
    .meta-box {
      border: 1px solid #111827;
      padding: 8px;
      min-height: 88px;
      line-height: 1.9;
      font-size: 13px;
    }
    .summary-line {
      display: grid;
      grid-template-columns: 120px 1fr;
      gap: 8px;
      margin: 8px 0;
      font-size: 14px;
    }
    .dotted {
      border-bottom: 1px dotted #444;
      min-height: 22px;
      padding: 0 6px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 14px;
      font-size: 13px;
    }
    th, td {
      border: 1px solid #111827;
      padding: 7px 6px;
      text-align: center;
      vertical-align: middle;
    }
    th {
      background: #eef2f6;
      font-weight: 800;
    }
    .details {
      text-align: right;
      line-height: 1.7;
    }
    .total-row td {
      font-weight: 800;
      background: #f8fafc;
    }
    .amount-words {
      margin-top: 10px;
      border-top: 1px solid #111827;
      padding-top: 8px;
      font-weight: 700;
    }
    .signatures {
      display: grid;
      grid-template-columns: repeat(${_signatureColumnCount(institutionSettings)}, 1fr);
      gap: 18px;
      margin-top: 34px;
      direction: ltr;
    }
    .signature {
      min-height: 82px;
      text-align: center;
      direction: rtl;
    }
    .signature-line {
      border-top: 1px solid #111827;
      margin-bottom: 8px;
    }
    .signature-title {
      font-weight: 800;
      min-height: 22px;
    }
    .signature-name {
      margin-top: 8px;
    }
    .receiver {
      margin-top: 28px;
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
      font-size: 13px;
    }
    @media print {
      body { background: #fff; }
      .toolbar { display: none; }
      .page { margin: 0; border: none; width: auto; min-height: auto; }
    }
  </style>
</head>
<body>
  <div class="toolbar">
    <button class="print-button" onclick="window.print()">طباعة المستند</button>
  </div>
  <main class="page">
    <section class="header">
      <div class="org-lines">
        ${_institutionLine('الوزارة', institutionSettings?.ministryName)}
        ${_institutionLine('الدائرة', institutionSettings?.departmentName)}
        ${_institutionLine('القسم', institutionSettings?.sectionName)}
        ${_institutionLine('الشعبة', institutionSettings?.divisionName)}
      </div>
      <div class="doc-title">
        <h1>${_escape(title)}</h1>
        <div class="sub-title">${_escape(institutionSettings?.documentHeader ?? institutionSettings?.name ?? 'نظام إدارة الحجوزات المالية')}</div>
        <div class="sub-title">رقم الصرف: ${_escape(expense.expenseNumber)}</div>
      </div>
      <div class="meta-box">
        <div>رقم المستند: ${_escape(documentNumber)}</div>
        <div>تاريخ المستند: ${_escape(documentDate)}</div>
        <div>تاريخ الصرف: ${_escape(expenseDate)}</div>
        <div>صفحة اليومية: ........................</div>
      </div>
    </section>

    ${isPaymentVoucher ? _paymentIntro(payee, amount, purpose, paymentMethod, expense) : _journalIntro(expense, amount, purpose, accountingGuide)}

    <table>
      <thead>
        <tr>
          <th colspan="2">مدين</th>
          <th colspan="2">دائن</th>
          <th rowspan="2">اسم الحساب / التفاصيل</th>
          <th rowspan="2">الدليل المحاسبي</th>
        </tr>
        <tr>
          <th>دينار</th>
          <th>فلس</th>
          <th>دينار</th>
          <th>فلس</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>${_escape(_plainAmount(expense.amount))}</td>
          <td>000</td>
          <td></td>
          <td></td>
          <td class="details">
            ${isPaymentVoucher ? 'مصروف على الباب' : 'من حساب الباب'}: ${_escape(sectionLabel)}<br>
            البرنامج: ${_escape(expense.programName)}<br>
            المدفوع له: ${_escape(payee)}<br>
            الحجز: ${_escape(expense.reservationNumber)}<br>
            ${_optionalDetail('القسم', expense.requesterDepartment)}
            ${_optionalDetail('الهاتف', expense.contactPhone)}
            ${_optionalDetail('الملاحظة', reservationNote)}
          </td>
          <td>${_escape(accountingGuide)}</td>
        </tr>
        <tr>
          <td></td>
          <td></td>
          <td>${_escape(_plainAmount(expense.amount))}</td>
          <td>000</td>
          <td class="details">
            ${isPaymentVoucher ? 'إلى حساب الصندوق / المصرف' : 'إلى حساب المصروفات'}<br>
            طريقة الدفع: ${_escape(paymentMethod)}<br>
            البيان: ${_escape(purpose)}<br>
            ${_optionalDetail('مرجع التخصيص', expense.fundingReference)}
          </td>
          <td>${isPaymentVoucher ? '' : _escape(accountingGuide)}</td>
        </tr>
        <tr>
          <td colspan="6" style="height: 150px;"></td>
        </tr>
        <tr class="total-row">
          <td>${_escape(_plainAmount(expense.amount))}</td>
          <td>000</td>
          <td>${_escape(_plainAmount(expense.amount))}</td>
          <td>000</td>
          <td colspan="2">المجموع</td>
        </tr>
      </tbody>
    </table>

    <div class="amount-words">المجموع فقط: ${_escape(amount)} لا غير</div>
    ${isPaymentVoucher ? _receiverBlock() : ''}
    ${_signatures(institutionSettings)}
    ${_documentFooter(institutionSettings)}
  </main>
</body>
</html>
''';
  }

  String _paymentIntro(
    String payee,
    String amount,
    String purpose,
    String paymentMethod,
    ExpenseItem expense,
  ) {
    return '''
    <div class="summary-line">
      <strong>المدفوع له:</strong>
      <div class="dotted">${_escape(payee)}</div>
    </div>
    <div class="summary-line">
      <strong>المبلغ:</strong>
      <div class="dotted">${_escape(amount)}</div>
    </div>
    <div class="summary-line">
      <strong>وذلك عن:</strong>
      <div class="dotted">${_escape(purpose)}</div>
    </div>
    <div class="summary-line">
      <strong>طريقة الدفع:</strong>
      <div class="dotted">${_escape(paymentMethod)}</div>
    </div>
    <div class="summary-line">
      <strong>الحجز:</strong>
      <div class="dotted">${_escape(expense.reservationNumber)} - ${_escape(_safeValue(expense.reservationTitle, 'بدون عنوان'))}</div>
    </div>
''';
  }

  String _journalIntro(
    ExpenseItem expense,
    String amount,
    String purpose,
    String accountingGuide,
  ) {
    return '''
    <div class="summary-line">
      <strong>البيان:</strong>
      <div class="dotted">${_escape(purpose)}</div>
    </div>
    <div class="summary-line">
      <strong>المبلغ:</strong>
      <div class="dotted">${_escape(amount)}</div>
    </div>
    <div class="summary-line">
      <strong>مرجع العملية:</strong>
      <div class="dotted">صرف ${_escape(expense.expenseNumber)} للحجز ${_escape(expense.reservationNumber)}</div>
    </div>
    <div class="summary-line">
      <strong>الدليل المحاسبي:</strong>
      <div class="dotted">${_escape(accountingGuide)}</div>
    </div>
''';
  }

  String _receiverBlock() {
    return '''
    <section class="receiver">
      <div>إني الموقع أدناه المستلم من ...........................................</div>
      <div>مبلغاً قدره فقط .......................................................</div>
      <div>اسم المستلم: ............................................................</div>
      <div>التوقيع: ...................................................................</div>
    </section>
''';
  }

  String _signatures(InstitutionSettingsItem? settings) {
    final signatures = _signatureItems(settings);
    if (signatures.isEmpty) return '';
    return '''
    <section class="signatures">
      ${signatures.map((item) => '''
      <div class="signature">
        <div class="signature-line"></div>
        <div class="signature-title">${_escape(item.title ?? '')}</div>
        <div class="signature-name">${_escape(item.name ?? '')}</div>
      </div>
      ''').join()}
    </section>
''';
  }

  List<ReportSignatureItem> _signatureItems(InstitutionSettingsItem? settings) {
    if (settings != null &&
        settings.showReportSignatures &&
        settings.reportSignatures.isNotEmpty) {
      return settings.reportSignatures.take(5).toList();
    }

    return const [
      ReportSignatureItem(title: 'المحاسب', name: '', location: null),
      ReportSignatureItem(title: 'مدقق', name: '', location: null),
      ReportSignatureItem(title: 'مدير الحسابات', name: '', location: null),
      ReportSignatureItem(title: 'المصادقة', name: '', location: null),
    ];
  }

  int _signatureColumnCount(InstitutionSettingsItem? settings) {
    final count = _signatureItems(settings).length;
    return count == 0 ? 4 : count;
  }

  String _institutionLine(String label, String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return '';
    return '<div><strong>${_escape(label)}:</strong> ${_escape(clean)}</div>';
  }

  String _documentFooter(InstitutionSettingsItem? settings) {
    final footer = settings?.documentFooter?.trim();
    if (footer == null || footer.isEmpty) return '';
    return '<div class="sub-title" style="margin-top: 24px; text-align: left;">${_escape(footer)}</div>';
  }

  String _paymentMethodLabel(String? value) {
    switch (value) {
      case 'cash':
        return 'نقدي';
      case 'bank_transfer':
        return 'حوالة مصرفية';
      case 'check':
        return 'صك';
      case 'electronic':
        return 'دفع إلكتروني';
      case 'other':
        return 'أخرى';
      default:
        return _safeValue(value, '-');
    }
  }

  String _safeValue(String? value, String fallback) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? fallback : clean;
  }

  String _payeeName(ExpenseItem expense) {
    return _firstFilled([
      expense.reservationBeneficiary,
      expense.requesterDepartment,
      expense.reservationTitle,
      expense.description,
      expense.reservationNumber,
    ]);
  }

  String _paymentPurpose(ExpenseItem expense, String description) {
    return _firstFilled([
      expense.description,
      expense.reservationExecutionNote,
      expense.reservationDescription,
      expense.reservationTitle,
      'صرف على ${expense.budgetSectionName}',
      description,
    ]);
  }

  String _reservationNote(ExpenseItem expense) {
    return _firstFilled([
      expense.description,
      expense.reservationExecutionNote,
      expense.reservationDescription,
      expense.reservationTitle,
    ]);
  }

  String _accountingGuide(ExpenseItem expense) {
    return _firstFilled([
      expense.budgetSectionFullCode,
      expense.budgetSectionCode,
      expense.budgetSectionName,
    ]);
  }

  String _sectionLabel(ExpenseItem expense) {
    final guide = _accountingGuide(expense);
    if (guide == expense.budgetSectionName) return expense.budgetSectionName;
    return '$guide - ${expense.budgetSectionName}';
  }

  String _optionalDetail(String label, String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty || clean == '-') return '';
    return '$label: ${_escape(clean)}<br>';
  }

  String _firstFilled(List<String?> values) {
    for (final value in values) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty && clean != '-') return clean;
    }
    return '-';
  }

  String _displayDate(String value) {
    if (value.trim().isEmpty) return '-';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  String _plainAmount(double value) {
    return NumberFormat('#,##0', 'en_US').format(value);
  }

  String _escape(String value) => const HtmlEscape().convert(value);

  Future<Directory> _documentsDirectory() async {
    final userProfile = Platform.environment['USERPROFILE'];
    final base = userProfile == null || userProfile.isEmpty
        ? Directory.current.path
        : '$userProfile\\Downloads';
    final directory = Directory('$base\\reservation_reports');
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
}
