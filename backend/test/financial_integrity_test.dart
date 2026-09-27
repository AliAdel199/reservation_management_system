// اختبارات تكامل لمنطق الأرصدة على قاعدة PostgreSQL حقيقية منفصلة.
//
// التشغيل (من مجلد backend):
//   dart test
//
// القاعدة: TEST_DATABASE_URL إن وُجد، وإلا نفس DATABASE_URL في .env مع إضافة _test لاسم القاعدة.
// تجهيزها مرة واحدة:
//   CREATE DATABASE reservation_management_test;
//   psql <url> -f ../deploy/sql/001_customer_database_setup.sql
@TestOn('vm')
library;

import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../src/config/app_config.dart';
import '../src/database/database_service.dart';
import '../src/main.dart';
import 'support/test_database.dart';

const _adminUsername = 'test_admin';
const _adminPassword = 'Test@12345';

late DatabaseService _database;
late Handler _handler;
late String _token;
late String _fiscalYearId;
final _runId = DateTime.now().millisecondsSinceEpoch.toString();
var _sequence = 0;

// تعليق عربي: كل اختبار تزامن يُكرر عدة جولات بعدة طلبات متوازية لرفع احتمال التداخل.
const _rounds = 5;
const _contenders = 4;

List<int> _sortedStatuses(List<(int, Map<String, dynamic>)> results) =>
    results.map((r) => r.$1).toList()..sort();

List<int> _oneWinner(int success) => [
  success,
  ...List.filled(_contenders - 1, 422),
];

String _unique(String prefix) => '$prefix-$_runId-${_sequence++}';

Future<(int, Map<String, dynamic>)> _call(
  String method,
  String path, [
  Map<String, dynamic>? body,
  String? token,
]) async {
  final response = await _handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer ${token ?? _token}',
      },
      body: body == null ? null : jsonEncode(body),
    ),
  );
  final text = await response.readAsString();
  return (
    response.statusCode,
    text.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(text) as Map<String, dynamic>,
  );
}

Future<String> _post(String path, Map<String, dynamic> body) async {
  final (status, json) = await _call('POST', path, body);
  expect(status, anyOf(200, 201), reason: '$path -> $json');
  return (json['data'] as Map<String, dynamic>)['id'].toString();
}

/// ينشئ برنامجاً وباباً قابلاً للصرف وحجزاً (معتمداً اختيارياً) ويعيد معرّف الحجز.
Future<String> _createReservation({
  required num amount,
  bool approve = true,
}) async {
  final programId = await _post('/api/programs', {
    'code': _unique('P'),
    'name': 'برنامج اختبار',
    'fiscal_year_id': _fiscalYearId,
  });
  final sectionId = await _post('/api/budget-sections', {
    'program_id': programId,
    'fiscal_year_id': _fiscalYearId,
    'code': _unique('S'),
    'name': 'باب اختبار',
    'allocated_amount': 1000000,
    'is_postable': true,
  });
  final reservationId = await _post('/api/reservations', {
    'reservation_number': _unique('R'),
    'program_id': programId,
    'budget_section_id': sectionId,
    'title': 'حجز اختبار',
    'beneficiary': 'جهة اختبار',
    'reserved_amount': amount,
    'reservation_date': '2026-01-15',
  });
  if (approve) {
    final (status, json) = await _call(
      'POST',
      '/api/reservations/$reservationId/approve',
    );
    expect(status, 200, reason: '$json');
  }
  return reservationId;
}

Map<String, dynamic> _expenseBody(String reservationId, num amount) => {
  'reservation_id': reservationId,
  'expense_number': _unique('E'),
  'amount': amount,
  'expense_date': '2026-02-01',
};

Future<int> _count(String sql, Map<String, dynamic> parameters) async {
  final result = await _database.connection.execute(
    Sql.named(sql),
    parameters: parameters,
  );
  return int.parse(result.first[0].toString());
}

Future<String> _login(String username, String password) async {
  final (status, json) = await _call('POST', '/api/auth/login', {
    'identity': username,
    'password': password,
  });
  expect(status, 200, reason: '$json');
  return (json['data'] as Map<String, dynamic>)['token'].toString();
}

Future<String> _roleId(String code) async {
  final (_, json) = await _call('GET', '/api/users/roles');
  final roles = (json['data'] as Map<String, dynamic>)['items'] as List;
  return (roles.firstWhere((role) => role['code'] == code) as Map)['id']
      .toString();
}

/// ينشئ مستخدماً بدور معيّن، وبصلاحيات مخصصة إن مُررت، ويعيد توكن دخوله.
Future<String> _userToken(String roleCode, {List<String>? permissions}) async =>
    (await _createUser(roleCode, permissions: permissions)).token;

Future<({String id, String token, Map<String, dynamic> data})> _createUser(
  String roleCode, {
  List<String>? permissions,
}) async {
  final username = _unique('u').replaceAll('-', '_');
  const password = 'Pass@12345';
  final (status, json) = await _call('POST', '/api/users', {
    'username': username,
    'full_name': 'مستخدم اختبار',
    'email': '$username@finance.test',
    'password': password,
    'role_id': await _roleId(roleCode),
    if (permissions != null) ...{
      'custom_permissions': true,
      'permissions': permissions,
    },
  });
  expect(status, 201, reason: '$json');
  final data = json['data'] as Map<String, dynamic>;
  return (
    id: data['id'].toString(),
    token: await _login(username, password),
    data: data,
  );
}

void main() {
  setUpAll(() async {
    final config = AppConfig(
      appName: 'test',
      host: 'localhost',
      port: 0,
      databaseUrl: testDatabaseUrl(),
      jwtSecret: 'integration-test-secret-integration-test-secret',
      jwtExpiresInHours: 1,
      defaultAdminUsername: _adminUsername,
      defaultAdminPassword: _adminPassword,
      defaultAdminFullName: 'Test Admin',
      defaultAdminEmail: 'test_admin@finance.test',
      resetDefaultAdminPassword: true,
      licenseEnforcementEnabled: false,
      licenseFilePath: 'license.json',
      licensePublicKeyPath: 'license_public.pem',
      backupDirectory: 'backups',
      attachmentDirectory: 'attachments',
      pgDumpPath: 'pg_dump',
      pgRestorePath: 'pg_restore',
      backupRetentionDays: 30,
    );
    final logger = Logger('test');
    _database = DatabaseService(config: config, logger: logger);
    await _database.connect();
    _handler = await buildServerHandler(
      config: config,
      database: _database,
      logger: logger,
    );

    final login = await _handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/auth/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'identity': _adminUsername,
          'password': _adminPassword,
        }),
      ),
    );
    final loginJson = jsonDecode(await login.readAsString());
    _token = loginJson['data']['token'].toString();

    final fiscalYear = await _database.connection.execute(
      'SELECT id FROM fiscal_years ORDER BY year DESC LIMIT 1',
    );
    _fiscalYearId = fiscalYear.first[0].toString();

    // تعليق عربي: نفتح اتصالات الـ Pool مسبقاً، وإلا ينتهي الطلب الأول قبل فتح اتصال للثاني
    // فلا يحدث تزامن حقيقي ولا يُختبر القفل.
    await Future.wait(
      List.generate(
        _contenders * 2,
        (_) => _database.connection.execute('SELECT pg_sleep(0.2)'),
      ),
    );
  });

  tearDownAll(() => _database.close());

  group('الصرف', () {
    test('صرف متزامن على نفس الحجز لا يتجاوز مبلغه', () async {
      for (var round = 0; round < _rounds; round++) {
        final reservationId = await _createReservation(amount: 1000);

        final results = await Future.wait([
          for (var i = 0; i < _contenders; i++)
            _call('POST', '/api/expenses', _expenseBody(reservationId, 800)),
        ]);
        expect(_sortedStatuses(results), _oneWinner(201));

        final spent = await _database.connection.execute(
          Sql.named('''
          SELECT COALESCE(SUM(amount), 0) FROM expenses
          WHERE reservation_id = @id::uuid AND expense_status::text <> 'cancelled'
        '''),
          parameters: {'id': reservationId},
        );
        expect(double.parse(spent.first[0].toString()), 800);
      }
    });

    test('صرف كامل مبلغ الحجز بكسور عشرية يُقبل', () async {
      // تعليق عربي: 0.1 + 0.2 في double = 0.30000000000000004؛ المقارنة بالفلس لا تتأثر بذلك.
      final reservationId = await _createReservation(amount: 0.1 + 0.2);
      final (status, json) = await _call(
        'POST',
        '/api/expenses',
        _expenseBody(reservationId, 0.30),
      );
      expect(status, 201, reason: '$json');
    });

    test('مبلغ بأكثر من خانتين عشريتين يُرفض', () async {
      final reservationId = await _createReservation(amount: 1000);
      final (status, json) = await _call(
        'POST',
        '/api/expenses',
        _expenseBody(reservationId, 10.005),
      );
      expect(status, 422);
      expect(json['code'], 'INVALID_EXPENSE_AMOUNT');
    });

    test('إلغاء متزامن لنفس مستند الصرف يعكسه مرة واحدة', () async {
      for (var round = 0; round < _rounds; round++) {
        final reservationId = await _createReservation(amount: 1000);
        final expenseId = await _post(
          '/api/expenses',
          _expenseBody(reservationId, 300),
        );

        final results = await Future.wait([
          for (var i = 0; i < _contenders; i++)
            _call('PATCH', '/api/expenses/$expenseId/cancel', {
              'cancel_reason': 'اختبار',
            }),
        ]);
        expect(_sortedStatuses(results), _oneWinner(200));

        expect(
          await _count(
            '''
          SELECT COUNT(*) FROM financial_transactions
          WHERE transaction_type::text = 'expense_reversal'
            AND reference_id = @id::uuid
          ''',
            {'id': expenseId},
          ),
          1,
        );
      }
    });
  });

  group('الحجز', () {
    test('اعتماد متزامن لنفس الحجز يحجز المبلغ مرة واحدة', () async {
      for (var round = 0; round < _rounds; round++) {
        final reservationId = await _createReservation(
          amount: 500,
          approve: false,
        );

        final results = await Future.wait([
          for (var i = 0; i < _contenders; i++)
            _call('POST', '/api/reservations/$reservationId/approve'),
        ]);
        expect(_sortedStatuses(results), _oneWinner(200));

        expect(
          await _count(
            '''
          SELECT COUNT(*) FROM financial_transactions
          WHERE reservation_id = @id::uuid
            AND transaction_type::text = 'reservation_hold'
          ''',
            {'id': reservationId},
          ),
          1,
        );
      }
    });
  });

  group('فصل المهام', () {
    test('مدخل البيانات لا يستطيع اعتماد الحجز عبر الـ API', () async {
      final token = await _userToken('DATA_ENTRY');
      final reservationId = await _createReservation(
        amount: 100,
        approve: false,
      );
      final (status, json) = await _call(
        'POST',
        '/api/reservations/$reservationId/approve',
        null,
        token,
      );
      expect(status, 403, reason: '$json');
    });

    test('الصلاحيات المخصصة تحل محل صلاحيات الدور', () async {
      // تعليق عربي: نفس الدور، لكن المستخدم مُنح الاعتماد فقط ولم يُمنح إنشاء الحجز.
      final approver = await _userToken(
        'DATA_ENTRY',
        permissions: ['reservations.view', 'reservations.approve'],
      );
      final reservationId = await _createReservation(
        amount: 100,
        approve: false,
      );

      final (approveStatus, approveJson) = await _call(
        'POST',
        '/api/reservations/$reservationId/approve',
        null,
        approver,
      );
      expect(approveStatus, 200, reason: '$approveJson');

      final (createStatus, _) = await _call('POST', '/api/reservations', {
        'title': 'x',
      }, approver);
      expect(createStatus, 403);
    });

    test('المستخدم يمكن منحه أكثر من صلاحية وإعادته لصلاحيات دوره', () async {
      final (_, created) = await _call('POST', '/api/users', {
        'username': _unique('multi').replaceAll('-', '_'),
        'full_name': 'متعدد الصلاحيات',
        'email': '${_unique('multi')}@finance.test',
        'password': 'Pass@12345',
        'role_id': await _roleId('VIEWER'),
        'custom_permissions': true,
        'permissions': [
          'reservations.add',
          'reservations.approve',
          'expenses.add',
        ],
      });
      final user = created['data'] as Map<String, dynamic>;
      expect(user['custom_permissions'], true);
      expect((user['permissions'] as List).toSet(), {
        'reservations.add',
        'reservations.approve',
        'expenses.add',
      });

      final (status, updated) = await _call('PUT', '/api/users/${user['id']}', {
        'username': user['username'],
        'full_name': user['full_name'],
        'email': user['email'],
        'role_id': user['role_id'],
        'is_active': true,
        'custom_permissions': false,
      });
      expect(status, 200, reason: '$updated');
      final reset = updated['data'] as Map<String, dynamic>;
      expect(reset['custom_permissions'], false);
      expect(reset['permissions'], isNot(contains('reservations.approve')));
    });

    test('رمز صلاحية غير معروف يُرفض', () async {
      final (status, json) = await _call('POST', '/api/users', {
        'username': _unique('bad').replaceAll('-', '_'),
        'full_name': 'x',
        'email': '${_unique('bad')}@finance.test',
        'password': 'Pass@12345',
        'role_id': await _roleId('VIEWER'),
        'custom_permissions': true,
        'permissions': ['not.a.permission'],
      });
      expect(status, 422);
      expect(json['code'], 'INVALID_PERMISSION_CODE');
    });

    test('سحب الصلاحية يسري فوراً دون إعادة تسجيل الدخول', () async {
      final user = await _createUser(
        'VIEWER',
        permissions: ['reservations.view'],
      );
      final (before, _) = await _call(
        'GET',
        '/api/reservations',
        null,
        user.token,
      );
      expect(before, 200);

      final (status, json) = await _call('PUT', '/api/users/${user.id}', {
        'username': user.data['username'],
        'full_name': user.data['full_name'],
        'email': user.data['email'],
        'role_id': user.data['role_id'],
        'is_active': true,
        'custom_permissions': true,
        'permissions': <String>[],
      });
      expect(status, 200, reason: '$json');

      final (after, _) = await _call(
        'GET',
        '/api/reservations',
        null,
        user.token,
      );
      expect(after, 403);
    });

    test('تعطيل الحساب يوقف التوكن الحالي فوراً', () async {
      final user = await _createUser(
        'VIEWER',
        permissions: ['reservations.view'],
      );
      final (status, _) = await _call('PATCH', '/api/users/${user.id}/status', {
        'is_active': false,
      });
      expect(status, 200);

      final (after, json) = await _call(
        'GET',
        '/api/reservations',
        null,
        user.token,
      );
      expect(after, 401);
      expect(json['code'], 'ACCOUNT_DISABLED');
    });

    test('قائمة الصلاحيات متاحة لشاشة المستخدمين', () async {
      final (status, json) = await _call('GET', '/api/users/permissions');
      expect(status, 200);
      final codes = ((json['data'] as Map)['items'] as List)
          .map((item) => item['code'])
          .toSet();
      expect(codes, containsAll(['reservations.approve', 'expenses.add']));
    });
  });

  group('قفل السنة المالية', () {
    test('القفل صلاحية مستقلة لا يملكها المدير ولا مدخل البيانات', () async {
      for (final role in ['ADMIN', 'DATA_ENTRY']) {
        final (status, json) = await _call(
          'PATCH',
          '/api/fiscal-years/$_fiscalYearId/lock',
          null,
          await _userToken(role),
        );
        expect(status, 403, reason: '$role -> $json');
      }
    });

    test('السنة المقفلة ترفض الإضافة والصرف والتعديل ثم تقبلها بعد الفتح', () async {
      final reservationId = await _createReservation(amount: 1000);

      final (lockStatus, lockJson) = await _call(
        'PATCH',
        '/api/fiscal-years/$_fiscalYearId/lock',
      );
      expect(lockStatus, 200, reason: '$lockJson');
      expect((lockJson['data'] as Map)['is_locked'], isTrue);
      // تعليق عربي: السنة مشتركة مع باقي الاختبارات، فنفتحها حتى لو فشل هذا الاختبار.
      addTearDown(
        () => _call('PATCH', '/api/fiscal-years/$_fiscalYearId/unlock'),
      );

      final (programStatus, programJson) = await _call('POST', '/api/programs', {
        'code': _unique('P'),
        'name': 'برنامج في سنة مقفلة',
        'fiscal_year_id': _fiscalYearId,
      });
      expect(programStatus, 409, reason: '$programJson');
      expect(programJson['code'], 'FISCAL_YEAR_LOCKED');

      final (expenseStatus, expenseJson) = await _call(
        'POST',
        '/api/expenses',
        _expenseBody(reservationId, 100),
      );
      expect(expenseStatus, 409, reason: '$expenseJson');
      expect(expenseJson['code'], 'FISCAL_YEAR_LOCKED');
      expect(
        await _count(
          'SELECT COUNT(*) FROM expenses WHERE reservation_id = @id::uuid',
          {'id': reservationId},
        ),
        0,
      );

      final year = (await _database.connection.execute(
        Sql.named(
          'SELECT year, start_date::text, end_date::text FROM fiscal_years WHERE id = @id::uuid',
        ),
        parameters: {'id': _fiscalYearId},
      )).first;
      final (renameStatus, renameJson) = await _call(
        'PUT',
        '/api/fiscal-years/$_fiscalYearId',
        {
          'year': year[0],
          'name': 'اسم جديد',
          'start_date': year[1],
          'end_date': year[2],
          'is_active': true,
        },
      );
      expect(renameStatus, 409, reason: '$renameJson');
      expect(renameJson['code'], 'FISCAL_YEAR_LOCKED');

      final (relockStatus, _) = await _call(
        'PATCH',
        '/api/fiscal-years/$_fiscalYearId/lock',
      );
      expect(relockStatus, 409);

      final (unlockStatus, unlockJson) = await _call(
        'PATCH',
        '/api/fiscal-years/$_fiscalYearId/unlock',
      );
      expect(unlockStatus, 200, reason: '$unlockJson');
      expect((unlockJson['data'] as Map)['is_locked'], isFalse);

      final (afterStatus, afterJson) = await _call(
        'POST',
        '/api/expenses',
        _expenseBody(reservationId, 100),
      );
      expect(afterStatus, 201, reason: '$afterJson');

      expect(
        await _count(
          '''
          SELECT COUNT(*) FROM audit_logs
          WHERE entity_id = @id::uuid
            AND action IN ('FISCAL_YEAR_LOCKED', 'FISCAL_YEAR_UNLOCKED')
          ''',
          {'id': _fiscalYearId},
        ),
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('سجل التدقيق', () {
    test('لا يمكن تعديل أو حذف سجل التدقيق', () async {
      final row = await _database.connection.execute(
        'SELECT id FROM audit_logs LIMIT 1',
      );
      final id = row.first[0].toString();

      await expectLater(
        _database.connection.execute(
          Sql.named(
            "UPDATE audit_logs SET description = 'x' WHERE id = @id::uuid",
          ),
          parameters: {'id': id},
        ),
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        _database.connection.execute(
          Sql.named('DELETE FROM audit_logs WHERE id = @id::uuid'),
          parameters: {'id': id},
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
