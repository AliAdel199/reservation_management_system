import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import 'import_matching.dart';

// تعليق عربي: تحويل قيم خلايا Excel (مبالغ، أرقام عربية، تواريخ، حالات) إلى قيم النظام.

enum ReservationImportStatus { reserved, approved }

double parseAmount(String value) {
  var cleaned = normalizeDigits(value)
      .replaceAll('٫', '.')
      .replaceAll('د.ع.', '')
      .replaceAll('د.ع', '')
      .replaceAll('دينار', '')
      .replaceAll('IQD', '')
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll('،', '')
      .replaceAll(RegExp(r'\s+'), '')
      .trim();
  if (cleaned.isEmpty || cleaned == '-' || cleaned == 'ـ') return 0;

  var isNegative = false;
  if (cleaned.startsWith('(') && cleaned.endsWith(')')) {
    isNegative = true;
    cleaned = cleaned.substring(1, cleaned.length - 1);
  }
  if (cleaned.endsWith('-')) {
    isNegative = true;
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  if (cleaned.startsWith('-')) {
    isNegative = true;
    cleaned = cleaned.substring(1);
  }

  // تعليق عربي: لا نحوّل النص غير المفهوم إلى صفر؛ خطأ كتابة في خلية مبلغ كان يُستورد
  // تخصيصاً صفرياً بلا تنبيه. الآن يُرفض السطر برسالة واضحة.
  final parsed = RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)
      ? double.parse(cleaned)
      : throw AppException(message: 'المبلغ غير مفهوم: ${value.trim()}');
  return isNegative ? -parsed : parsed;
}

int parseInt(String value) {
  final cleaned = normalizeDigits(
    value,
  ).replaceAll(',', '').replaceAll('٬', '').replaceAll('،', '').trim();
  return int.tryParse(cleaned) ?? 0;
}

bool parseBool(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'نعم' ||
      normalized == 'فعال' ||
      normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes') {
    return true;
  }
  if (normalized == 'لا' ||
      normalized == 'غير فعال' ||
      normalized == 'false' ||
      normalized == '0' ||
      normalized == 'no') {
    return false;
  }
  throw AppException(message: 'قيمة فعال غير صحيحة: $value');
}

String? normalizeDate(String value) {
  final normalized = normalizeDigits(value).trim();
  if (normalized.isEmpty) return null;
  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) {
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  for (final pattern in [
    'yyyy/MM/dd',
    'yyyy/M/d',
    'dd/MM/yyyy',
    'd/M/yyyy',
    'dd-MM-yyyy',
    'd-M-yyyy',
  ]) {
    try {
      final formatted = DateFormat(pattern).parseStrict(normalized);
      return DateFormat('yyyy-MM-dd').format(formatted);
    } catch (_) {
      // نجرب الصيغة التالية لأن ملفات Excel الحكومية تختلف بتنسيق التاريخ.
    }
  }

  throw AppException(message: 'التاريخ غير صحيح: $normalized');
}

String dateOnly(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  return value.length >= 10 ? value.substring(0, 10) : value;
}

String yearFromDate(String? value) {
  final date = dateOnly(value);
  if (date.length >= 4) return date.substring(0, 4);
  return DateTime.now().year.toString();
}

String normalizeDigits(String value) {
  const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const easternArabicIndic = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var normalized = value;
  for (var index = 0; index < 10; index++) {
    normalized = normalized
        .replaceAll(arabicIndic[index], index.toString())
        .replaceAll(easternArabicIndic[index], index.toString());
  }
  return normalized;
}

bool? parsePostableSectionType(String value) {
  final normalized = normalizeBusinessName(value);
  if (normalized.isEmpty) return null;
  if (normalized == 'نهائي' ||
      normalized == 'leaf' ||
      normalized == 'postable' ||
      normalized == 'نعم' ||
      normalized == 'true' ||
      normalized == '1') {
    return true;
  }
  if (normalized == 'تجميعي' ||
      normalized == 'رئيسي' ||
      normalized == 'parent' ||
      normalized == 'group' ||
      normalized == 'لا' ||
      normalized == 'false' ||
      normalized == '0') {
    return false;
  }
  throw AppException(message: 'نوع الباب غير صحيح: $value');
}

ReservationImportStatus parseReservationImportStatus(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'محجوز' ||
      normalized == 'reserved' ||
      normalized == 'draft' ||
      normalized == 'حجز') {
    return ReservationImportStatus.reserved;
  }
  if (normalized == 'معتمد' || normalized == 'approved') {
    return ReservationImportStatus.approved;
  }
  if (normalized == 'مصروف' ||
      normalized == 'spent' ||
      normalized == 'completed') {
    throw const AppException(
      message:
          'لا يمكن استيراد حجز بحالة مصروف؛ استورده كمعتمد ثم سجّل الصرف من شاشة الصرف.',
    );
  }
  if (normalized == 'ملغي' ||
      normalized == 'cancelled' ||
      normalized == 'canceled') {
    throw const AppException(
      message:
          'لا يمكن استيراد حجز ملغي؛ الإلغاء يجب أن يتم من داخل النظام حتى يعكس السجل المالي الحركة.',
    );
  }
  throw AppException(message: 'حالة الحجز غير مدعومة: $value');
}

String reservationStatusLabel(String status) {
  return switch (status) {
    'approved' => 'معتمد',
    'partially_spent' || 'fully_spent' || 'completed' => 'مصروف',
    'cancelled' => 'ملغي',
    _ => 'محجوز',
  };
}

String executionStatusLabel(String status) {
  return switch (status) {
    'executed' => 'منفذ',
    'partially_executed' => 'منفذ جزئياً',
    _ => 'غير منفذ',
  };
}
