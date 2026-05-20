import 'package:logging/logging.dart';
import 'package:postgres/postgres.dart';

import '../config/app_config.dart';
import '../repositories/auth_repository.dart';
import '../services/audit_service.dart';
import '../services/password_service.dart';
import 'database_service.dart';

class DatabaseSeeder {
  DatabaseSeeder({
    required AppConfig config,
    required DatabaseService database,
    required AuthRepository authRepository,
    required PasswordService passwordService,
    required AuditService auditService,
    required Logger logger,
  }) : _config = config,
       _database = database,
       _authRepository = authRepository,
       _passwordService = passwordService,
       _auditService = auditService,
       _logger = logger;

  final AppConfig _config;
  final DatabaseService _database;
  final AuthRepository _authRepository;
  final PasswordService _passwordService;
  final AuditService _auditService;
  final Logger _logger;

  Future<void> seedFoundation() async {
    await _database.runTx((session) async {
      await _seedRoles(session);
      await _seedAdmin(session);
    });

    _logger.info('Foundation seed completed.');
  }

  Future<void> _seedRoles(Session session) async {
    // تعليق عربي: نستخدم upsert حتى تبقى التهيئة قابلة لإعادة التشغيل بأمان.
    const roles = [
      {
        'code': 'SUPER_ADMIN',
        'name': 'سوبر أدمن',
        'description': 'كل الصلاحيات مع الحذف وإدارة المستخدمين',
      },
      {
        'code': 'ADMIN',
        'name': 'مدير نظام',
        'description': 'معاينة وإضافة وتعديل بدون حذف',
      },
      {
        'code': 'FINANCE_MANAGER',
        'name': 'مدير مالي',
        'description': 'إدارة الاعتماد والمتابعة والتقارير',
      },
      {
        'code': 'REVIEWER',
        'name': 'مدقق مالي',
        'description': 'مراجعة العمليات واعتمادها',
      },
      {
        'code': 'DATA_ENTRY',
        'name': 'إدخال بيانات',
        'description': 'إدخال البرامج والأبواب والحجوزات الأولية',
      },
      {
        'code': 'VIEWER',
        'name': 'معاينة فقط',
        'description': 'عرض البيانات والتقارير بدون تعديل',
      },
    ];

    for (final role in roles) {
      await session.execute(
        Sql.named('''
          INSERT INTO roles (code, name, description)
          VALUES (@code, @name, @description)
          ON CONFLICT (code) DO UPDATE
          SET name = EXCLUDED.name,
              description = EXCLUDED.description,
              updated_at = NOW()
        '''),
        parameters: role,
      );
    }
  }

  Future<void> _seedAdmin(Session session) async {
    final existingAdmin = await session.execute(
      Sql.named('''
      SELECT id
      FROM users
      WHERE LOWER(email) = LOWER(@email)
      LIMIT 1
    '''),
      parameters: {'email': _config.defaultAdminEmail},
    );

    if (existingAdmin.isNotEmpty) {
      final existingId = existingAdmin.first[0].toString();

      // Update existing admin to match configured defaults (safe to re-run)
      final roleId = await _authRepository.findRoleIdByCode(
        session,
        'SUPER_ADMIN',
      );

      final passwordHash = _passwordService.hashPassword(
        _config.defaultAdminPassword,
      );

      await session.execute(
        Sql.named('''
          UPDATE users
          SET username = @username,
              full_name = @full_name,
              password_hash = @password_hash,
              role_id = @role_id,
              updated_at = NOW()
          WHERE id = @id
        '''),
        parameters: {
          'id': existingId,
          'username': _config.defaultAdminUsername,
          'full_name': _config.defaultAdminFullName,
          'password_hash': passwordHash,
          'role_id': roleId,
        },
      );

      _logger.info('Default admin already existed — updated credentials.');
      return;
    }

    final roleId = await _authRepository.findRoleIdByCode(
      session,
      'SUPER_ADMIN',
    );

    final passwordHash = _passwordService.hashPassword(
      _config.defaultAdminPassword,
    );

    final userId = await _authRepository.createUser(
      session: session,
      username: _config.defaultAdminUsername,
      fullName: _config.defaultAdminFullName,
      email: _config.defaultAdminEmail,
      passwordHash: passwordHash,
      roleId: roleId,
    );

    await _auditService.log(
      session: session,
      action: 'SYSTEM_SEED_ADMIN',
      entityName: 'users',
      entityId: userId,
      description: 'Default administrator account created during bootstrap.',
      newValues: {
        'username': _config.defaultAdminUsername,
        'role_code': 'SUPER_ADMIN',
      },
    );

    _logger.info('Default admin created.');
  }

  // Future<void> _seedAdmin(Session session) async {
  //   final existingUser = await _authRepository.findByIdentity(
  //     session,
  //     _config.defaultAdminEmail,
  //   );

  //   if (existingUser != null) {
  //     return;
  //   }

  //   final roleId = await _authRepository.findRoleIdByCode(
  //     session,
  //     'super_admin',
  //   );
  //   final passwordHash = _passwordService.hashPassword(
  //     _config.defaultAdminPassword,
  //   );

  //   final userId = await _authRepository.createUser(
  //     session: session,
  //     username: _config.defaultAdminUsername,
  //     fullName: _config.defaultAdminFullName,
  //     email: _config.defaultAdminEmail,
  //     passwordHash: passwordHash,
  //     roleId: roleId,
  //   );

  //   await _auditService.log(
  //     session: session,
  //     action: 'SYSTEM_SEED_ADMIN',
  //     entityName: 'users',
  //     entityId: userId,
  //     description: 'Default administrator account created during bootstrap.',
  //     newValues: {
  //       'username': _config.defaultAdminUsername,
  //       'role_code': 'super_admin',
  //     },
  //   );
  // }
}
