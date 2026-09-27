import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reservation_management_system/core/network/api_client.dart';
import 'package:reservation_management_system/core/storage/app_storage.dart';
import 'package:reservation_management_system/features/auth/data/auth_repository.dart';
import 'package:reservation_management_system/features/auth/presentation/controllers/auth_controller.dart';
import 'package:reservation_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:reservation_management_system/shared/models/auth_session.dart';
import 'package:reservation_management_system/shared/models/auth_user.dart';

const _session = AuthSession(
  token: 'token',
  user: AuthUser(
    id: '1',
    username: 'user',
    fullName: 'مستخدم',
    email: 'user@test',
    roleCode: 'VIEWER',
    roleName: 'معاينة',
  ),
);

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(AppStorage storage) : super(ApiClient(storage), storage);

  var cleared = 0;

  @override
  Future<AuthSession?> restoreSession() async => _session;

  @override
  Future<void> clearSession() async => cleared++;
}

void main() {
  late ProviderContainer container;
  late _FakeAuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeAuthRepository(AppStorage());
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    await container.read(authControllerProvider.future);
  });

  tearDown(() => container.dispose());

  test('تعطيل الحساب ينهي الجلسة ويعرض السبب', () async {
    await container
        .read(authControllerProvider.notifier)
        .endSession('ACCOUNT_DISABLED');

    expect(container.read(authControllerProvider).asData?.value, isNull);
    expect(container.read(sessionNoticeProvider), contains('تعطيل حسابك'));
    expect(repository.cleared, 1);
  });

  test('طلبات فاشلة متعددة تنهي الجلسة مرة واحدة', () async {
    final controller = container.read(authControllerProvider.notifier);
    await Future.wait([
      controller.endSession('TOKEN_EXPIRED'),
      controller.endSession('TOKEN_EXPIRED'),
    ]);

    expect(repository.cleared, 1);
    expect(container.read(sessionNoticeProvider), contains('انتهت الجلسة'));
  });
}
