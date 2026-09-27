import '../../../core/errors/app_exception.dart';
import '../../budget_sections/models/budget_section_item.dart';
import '../../fiscal_years/models/fiscal_year_item.dart';
import '../../programs/models/program_item.dart';
import 'import_value_parsers.dart';

// تعليق عربي: مطابقة صفوف Excel مع السنوات المالية والبرامج والأبواب الموجودة وبناء شجرة الأكواد.

class SectionImportRow {
  const SectionImportRow({
    required this.rowNumber,
    required this.fiscalYear,
    required this.program,
    required this.parentCode,
    required this.code,
    required this.fullCode,
    required this.name,
    required this.isPostable,
    required this.allocatedAmount,
    required this.sortOrder,
    required this.description,
    required this.isActive,
  });

  final int rowNumber;
  final FiscalYearItem fiscalYear;
  final ProgramItem program;
  final String parentCode;
  final String code;
  final String fullCode;
  final String name;
  final bool? isPostable;
  final double allocatedAmount;
  final int sortOrder;
  final String description;
  final bool isActive;
}

String buildInternalProgramCode(int fiscalYear, int rowIndex) =>
    'AUTO-$fiscalYear-${DateTime.now().microsecondsSinceEpoch}-$rowIndex';

FiscalYearItem findFiscalYear(List<FiscalYearItem> items, String value) {
  final normalized = normalizeDigits(value).trim();
  if (normalized.isEmpty) {
    throw const AppException(message: 'السنة المالية مطلوبة.');
  }
  return items.firstWhere(
    (item) => item.year.toString() == normalized || item.name == normalized,
    orElse: () =>
        throw AppException(message: 'السنة المالية غير موجودة: $normalized'),
  );
}

ProgramItem findProgram(
  List<ProgramItem> items, {
  required String code,
  required String name,
  String? fiscalYearId,
}) {
  final normalizedCode = code.trim();
  final normalizedName = name.trim();
  if (normalizedCode.isEmpty && normalizedName.isEmpty) {
    throw const AppException(message: 'البرنامج مطلوب.');
  }
  final scoped = items
      .where((item) => sameFiscalYear(item.fiscalYearId, fiscalYearId))
      .toList();
  // تعليق عربي: الكود أولاً، والاسم فقط إن لم يطابق الكود شيئاً.
  return _single(
    [
      if (normalizedCode.isNotEmpty)
        scoped.where((item) => item.code == normalizedCode).toList(),
      if (normalizedName.isNotEmpty)
        scoped
            .where((item) => sameBusinessName(item.name, normalizedName))
            .toList(),
    ],
    notFound:
        'البرنامج غير موجود: ${normalizedCode.isEmpty ? normalizedName : normalizedCode}',
    ambiguous: (matches) =>
        'البرنامج يطابق أكثر من سجل (${matches.map((p) => '${p.code} - ${p.name}').join('، ')}). حدد كود البرنامج.',
  );
}

/// يعيد التطابق الوحيد من أول مستوى فيه نتائج، ويرفض إن طابق الصف أكثر من سجل،
/// بدل أخذ أول نتيجة بصمت وربط الصف بسجل خاطئ.
T _single<T>(
  List<List<T>> tiers, {
  required String notFound,
  required String Function(List<T> matches) ambiguous,
}) {
  for (final matches in tiers) {
    if (matches.isEmpty) continue;
    if (matches.length > 1) {
      throw AppException(message: ambiguous(matches));
    }
    return matches.single;
  }
  throw AppException(message: notFound);
}

bool sameFiscalYear(String? itemFiscalYearId, String? selectedFiscalYearId) {
  if (selectedFiscalYearId == null || selectedFiscalYearId.isEmpty) {
    return true;
  }

  // تعليق عربي: بعض البيانات القديمة قد لا تحمل معرف السنة، لذلك لا نرفضها إذا الاسم مطابق.
  return itemFiscalYearId == null ||
      itemFiscalYearId.isEmpty ||
      itemFiscalYearId == selectedFiscalYearId;
}

bool sameBusinessName(String left, String right) {
  final normalizedLeft = normalizeBusinessName(left);
  final normalizedRight = normalizeBusinessName(right);
  if (normalizedLeft == normalizedRight) {
    return true;
  }

  // تعليق عربي: مطابقة تامة بعد التوحيد فقط. قبول احتواء اسم في آخر كان يربط
  // "نقل" بـ "مصاريف النقل" أو "نقل الأثاث" حسب ترتيب القائمة.
  return removeArabicArticle(normalizedLeft) ==
      removeArabicArticle(normalizedRight);
}

String normalizeBusinessName(String value) {
  final withoutPrefix = value
      .trim()
      .replaceFirst(RegExp(r'^\d+\s*[-ـ–]\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  return withoutPrefix
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
      .toLowerCase()
      .trim();
}

String removeArabicArticle(String value) =>
    value.startsWith('ال') ? value.substring(2) : value;

BudgetSectionItem findSection(
  List<BudgetSectionItem> items, {
  required String programId,
  required String fiscalYearId,
  required String code,
  required String name,
}) {
  final normalizedCode = code.trim();
  final normalizedName = name.trim();
  if (normalizedCode.isEmpty && normalizedName.isEmpty) {
    throw const AppException(message: 'الباب مطلوب.');
  }
  final scopedItems = items.where(
    (item) => item.programId == programId && item.fiscalYearId == fiscalYearId,
  );
  final codeKey = sectionCodeKey(normalizedCode);
  final section = _single(
    [
      if (normalizedCode.isNotEmpty) ...[
        scopedItems
            .where(
              (item) =>
                  sectionCodeKey(item.fullCode) == codeKey ||
                  sectionCodeKey(item.code) == codeKey,
            )
            .toList(),
        scopedItems
            .where(
              (item) =>
                  sameSectionCode(item.code, normalizedCode) ||
                  sameSectionCode(item.fullCode, normalizedCode),
            )
            .toList(),
      ],
      if (normalizedName.isNotEmpty)
        scopedItems
            .where((item) => sameBusinessName(item.name, normalizedName))
            .toList(),
    ],
    notFound:
        'الباب غير موجود: ${normalizedCode.isEmpty ? normalizedName : normalizedCode}',
    ambiguous: (matches) =>
        'الباب يطابق أكثر من باب (${matches.map((s) => '${s.fullCode} - ${s.name}').join('، ')}). اكتب الكود الكامل للباب.',
  );

  if (!section.isPostable) {
    throw AppException(
      message:
          'الباب ${section.fullCode} - ${section.name} تجميعي ولا يقبل الحجز. اختر باباً نهائياً من الشجرة.',
    );
  }

  return section;
}

Map<String, BudgetSectionItem> buildSectionLookup(
  List<BudgetSectionItem> sections,
) {
  final lookup = <String, BudgetSectionItem>{};
  for (final section in sections) {
    addSectionToLookup(lookup, section);
  }
  return lookup;
}

void addSectionToLookup(
  Map<String, BudgetSectionItem> lookup,
  BudgetSectionItem section,
) {
  for (final key in sectionLookupKeys(section)) {
    lookup[key] = section;
  }
}

Iterable<String> sectionLookupKeys(BudgetSectionItem section) sync* {
  final fiscalYearId = section.fiscalYearId ?? '';
  for (final code in [
    section.code,
    section.fullCode,
    section.name,
  ].whereType<String>()) {
    final normalized = sectionCodeKey(code);
    if (normalized.isNotEmpty) {
      yield sectionLookupKey(section.programId, fiscalYearId, normalized);
    }
  }
}

String sectionLookupKey(String programId, String fiscalYearId, String code) =>
    '$programId|$fiscalYearId|${sectionCodeKey(code)}';

BudgetSectionItem? findImportedParentSection(
  SectionImportRow row,
  Map<String, BudgetSectionItem> lookup,
) {
  final parentCode = row.parentCode.trim().isNotEmpty
      ? row.parentCode
      : parentCodeFromFullCode(row.fullCode);
  if (parentCode.isEmpty) return null;

  final key = sectionLookupKey(row.program.id, row.fiscalYear.id, parentCode);
  final parent = lookup[key];
  if (parent == null) {
    throw AppException(message: 'الباب الأب غير موجود: $parentCode');
  }
  return parent;
}

String composeFullCode(String parentCode, String code) {
  final parent = parentCode.trim();
  final child = code.trim();
  return parent.isEmpty ? child : '$parent $child';
}

String parentCodeFromFullCode(String fullCode) {
  final parts = fullCode
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.length <= 1) return '';
  return parts.take(parts.length - 1).join(' ');
}

int sectionCodeDepth(String fullCode) => fullCode
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .length;

bool sameSectionCode(String left, String right) {
  final leftCandidates = sectionCodeCandidates(left);
  final rightCandidates = sectionCodeCandidates(right);
  return leftCandidates.any(rightCandidates.contains);
}

Set<String> sectionCodeCandidates(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return const {};
  final beforeDash = trimmed.split(RegExp(r'\s[-–ـ]\s')).first.trim();
  final parts = beforeDash
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  return {
    sectionCodeKey(trimmed),
    sectionCodeKey(beforeDash),
    if (parts.isNotEmpty) sectionCodeKey(parts.last),
  }..removeWhere((item) => item.isEmpty);
}

String sectionCodeKey(String value) {
  final beforeDash = value.trim().split(RegExp(r'\s[-–ـ]\s')).first;
  return beforeDash
      .replaceAll(RegExp(r'[^0-9A-Za-z\u0600-\u06FF]+'), '')
      .toLowerCase();
}
