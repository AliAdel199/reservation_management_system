import 'package:dotenv/dotenv.dart';

/// رابط قاعدة الاختبار: TEST_DATABASE_URL إن وُجد، وإلا DATABASE_URL من .env مع إضافة _test لاسم القاعدة.
String testDatabaseUrl() {
  final env = DotEnv(includePlatformEnvironment: true, quiet: true)..load();
  final explicit = env['TEST_DATABASE_URL'];
  final url =
      explicit ??
      () {
        final uri = Uri.parse(env['DATABASE_URL']!);
        return uri.replace(path: '${uri.path}_test').toString();
      }();

  // تعليق عربي: حماية من تشغيل الاختبارات على قاعدة العمل الفعلية بالخطأ.
  final databaseName = Uri.parse(url).pathSegments.last;
  if (!databaseName.endsWith('_test')) {
    throw StateError(
      'Refusing to run tests on "$databaseName": name must end with _test.',
    );
  }
  return url;
}
