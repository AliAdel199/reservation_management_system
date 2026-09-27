import 'dart:io';

import 'package:test/test.dart';

// تعليق عربي: رسائل الخطأ تُعرض كما هي لموظفي المؤسسة في الواجهة، لذلك يجب أن تكون عربية.
// هذا الاختبار يمنع إضافة رسالة خطأ إنجليزية جديدة دون انتباه.
void main() {
  test('رسائل الأخطاء في الخادم عربية', () {
    final literal = RegExp(r"message:\s*((?:'(?:[^'\\]|\\.)*'\s*)+)");
    final englishStart = RegExp(r'^[A-Za-z]');
    final offenders = <String>[];

    for (final file in Directory(
      'src',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final match in literal.allMatches(text)) {
        // رسائل النجاح (jsonResponse 2xx) لا تعرضها الواجهة؛ نفحص رسائل الأخطاء فقط.
        final before = text.substring(
          match.start < 300 ? 0 : match.start - 300,
          match.start,
        );
        final isSuccess = RegExp(r'jsonResponse\(\s*2\d\d').hasMatch(
          before.substring(
            before
                .lastIndexOf(
                  RegExp(r'jsonResponse\(|AppException\(|LicenseStatus\('),
                )
                .clamp(0, before.length),
          ),
        );
        final value = RegExp(
          r"'((?:[^'\\]|\\.)*)'",
        ).allMatches(match.group(1)!).map((m) => m.group(1)).join();
        if (!isSuccess && englishStart.hasMatch(value.trim())) {
          offenders.add('${file.path}: $value');
        }
      }
    }

    expect(offenders, isEmpty);
  });
}
