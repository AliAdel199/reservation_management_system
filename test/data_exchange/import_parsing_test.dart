import 'package:flutter_test/flutter_test.dart';

import 'package:reservation_management_system/core/errors/app_exception.dart';
import 'package:reservation_management_system/features/data_exchange/services/import_matching.dart';
import 'package:reservation_management_system/features/data_exchange/services/import_value_parsers.dart';
import 'package:reservation_management_system/features/budget_sections/models/budget_section_item.dart';
import 'package:reservation_management_system/features/programs/models/program_item.dart';

ProgramItem _program(String id, String code, String name) =>
    ProgramItem.fromJson({
      'id': id,
      'code': code,
      'name': name,
      'fiscal_year_id': 'fy',
      'fiscal_year': 2026,
      'is_active': true,
    });

BudgetSectionItem _section(
  String id,
  String code,
  String fullCode,
  String name,
) => BudgetSectionItem.fromJson({
  'id': id,
  'program_id': 'p',
  'program_code': 'P',
  'program_name': 'برنامج',
  'fiscal_year_id': 'fy',
  'fiscal_year': 2026,
  'code': code,
  'full_code': fullCode,
  'name': name,
  'is_postable': true,
  'level': fullCode.split(' ').length,
});

// قواعد تحليل خلايا Excel ومطابقتها مع بيانات النظام في الاستيراد.
void main() {
  group('parseAmount', () {
    test('يقبل الفواصل والعملة والأرقام العربية', () {
      expect(parseAmount('1,250,000'), 1250000);
      expect(parseAmount('١٬٢٥٠٬٠٠٠ د.ع'), 1250000);
      expect(parseAmount('۱۲۵۰۰۰۰ دينار'), 1250000);
      expect(parseAmount('2,500.75 IQD'), 2500.75);
    });

    test('يفهم صيغ السالب المحاسبية', () {
      expect(parseAmount('(500)'), -500);
      expect(parseAmount('500-'), -500);
      expect(parseAmount('-500'), -500);
    });

    test('الخلية الفارغة أو الشرطة تعني صفراً', () {
      expect(parseAmount(''), 0);
      expect(parseAmount('-'), 0);
    });

    test('نص غير مفهوم يُرفض بدل أن يصبح صفراً', () {
      expect(() => parseAmount('1.250.000'), throwsA(isA<AppException>()));
      expect(() => parseAmount('مليون'), throwsA(isA<AppException>()));
      expect(() => parseAmount('12a'), throwsA(isA<AppException>()));
    });

    test('يقبل الفاصلة العشرية العربية وصيغة د.ع.', () {
      expect(parseAmount('١٢٥٠٫٥'), 1250.5);
      expect(parseAmount('100 د.ع.'), 100);
    });
  });

  group('normalizeDate', () {
    test('يوحد صيغ التاريخ الشائعة إلى yyyy-MM-dd', () {
      expect(normalizeDate('2026-01-05'), '2026-01-05');
      expect(normalizeDate('2026/1/5'), '2026-01-05');
      expect(normalizeDate('05/01/2026'), '2026-01-05');
      expect(normalizeDate('5-1-2026'), '2026-01-05');
      expect(normalizeDate('٢٠٢٦-٠١-٠٥'), '2026-01-05');
    });

    test('الخلية الفارغة تعطي null والتاريخ الخاطئ يرفض', () {
      expect(normalizeDate(''), isNull);
      expect(() => normalizeDate('غير معروف'), throwsA(isA<AppException>()));
    });
  });

  group('parseBool و parseInt', () {
    test('يقبل القيم العربية والإنجليزية', () {
      expect(parseBool('نعم'), isTrue);
      expect(parseBool('غير فعال'), isFalse);
      expect(parseBool(''), isTrue);
      expect(() => parseBool('ربما'), throwsA(isA<AppException>()));
      expect(parseInt('١٬٢٠٠'), 1200);
    });
  });

  group('أكواد الأبواب', () {
    test('بناء الكود الكامل وتفكيكه', () {
      expect(composeFullCode('1 2', '3'), '1 2 3');
      expect(composeFullCode('', '3'), '3');
      expect(parentCodeFromFullCode('1 2 3'), '1 2');
      expect(parentCodeFromFullCode('1'), '');
      expect(sectionCodeDepth('1  2 3'), 3);
    });
  });

  group('مطابقة الأسماء', () {
    test('يتجاهل الهمزات والتاء المربوطة وأل التعريف', () {
      expect(sameBusinessName('الإدارة العامة', 'اداره عامة'), isFalse);
      expect(sameBusinessName('الرواتب', 'رواتب'), isTrue);
      expect(sameBusinessName('إدارة المشاريع', 'ادارة المشاريع'), isTrue);
      expect(sameBusinessName('1 - صيانة الأبنية', 'صيانة الابنية'), isTrue);
    });

    test('اسم قصير لا يطابق أسماء أطول تحتويه', () {
      expect(sameBusinessName('نقل', 'مصاريف النقل'), isFalse);
      expect(sameBusinessName('نقل', 'نقل الأثاث'), isFalse);
      expect(sameBusinessName('النقل', 'نقل'), isTrue);
    });
  });

  group('مطابقة البرامج والأبواب', () {
    final programs = [
      _program('1', 'P1', 'مصاريف النقل'),
      _program('2', 'P2', 'نقل الأثاث'),
      _program('3', 'P3', 'الرواتب'),
    ];
    final sections = [
      _section('a', '3', '1 2 3', 'رواتب الموظفين'),
      _section('b', '3', '4 5 3', 'مكافآت'),
      _section('c', '7', '1 2 7', 'صيانة'),
    ];

    test('البرنامج يطابق بالكود أولاً ثم بالاسم التام', () {
      expect(findProgram(programs, code: 'P2', name: '').id, '2');
      expect(findProgram(programs, code: '', name: 'رواتب').id, '3');
      expect(
        () => findProgram(programs, code: '', name: 'نقل'),
        throwsA(isA<AppException>()),
      );
    });

    test('اسم يطابق أكثر من برنامج يُرفض بدل أخذ الأول', () {
      final duplicated = [...programs, _program('4', 'P4', 'الرواتب')];
      expect(
        () => findProgram(duplicated, code: '', name: 'الرواتب'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('أكثر من'),
          ),
        ),
      );
    });

    test('الباب يطابق بالكود الكامل، والكود الجزئي المشترك يُرفض', () {
      BudgetSectionItem find(String code) => findSection(
        sections,
        programId: 'p',
        fiscalYearId: 'fy',
        code: code,
        name: '',
      );
      expect(find('1 2 3').id, 'a');
      expect(find('4 5 3').id, 'b');
      expect(find('1 2 7 - صيانة').id, 'c');
      expect(find('7').id, 'c');
      expect(() => find('3'), throwsA(isA<AppException>()));
    });
  });
}
