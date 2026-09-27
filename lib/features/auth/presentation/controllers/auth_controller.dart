import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/auth_session.dart';
import '../providers/auth_providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// رسالة تظهر في شاشة الدخول عند إنهاء الجلسة من الخادم.
final sessionNoticeProvider = NotifierProvider<SessionNotice, String?>(
  SessionNotice.new,
);

class SessionNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;

  void clear() => state = null;
}

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    return ref.read(authRepositoryProvider).restoreSession();
  }

  Future<void> login({
    required String identity,
    required String password,
  }) async {
    ref.read(sessionNoticeProvider.notifier).clear();
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

  // تعليق عربي: يُستدعى عند رفض الخادم للجلسة؛ نخرج المستخدم لشاشة الدخول مع السبب.
  // عدة طلبات قد تفشل معاً، لذلك نتصرف مرة واحدة فقط ما دامت هناك جلسة قائمة.
  Future<void> endSession(String? code) async {
    if (state.asData?.value == null) return;
    // تعليق عربي: نغيّر الحالة قبل أي انتظار حتى لا تمر الاستدعاءات المتزامنة من الشرط أعلاه.
    state = const AsyncData(null);
    ref
        .read(sessionNoticeProvider.notifier)
        .show(
          code == 'ACCOUNT_DISABLED'
              ? 'تم تعطيل حسابك أو حذفه. يرجى مراجعة مدير النظام.'
              : 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.',
        );
    await ref.read(authRepositoryProvider).clearSession();
  }
}
