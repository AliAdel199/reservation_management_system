import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/auth_session.dart';
import '../providers/auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> login({
    required String identity,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(identity: identity, password: password),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).clearSession();
    state = const AsyncData(null);
  }
}
