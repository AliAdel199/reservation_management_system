import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/paged_result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/users_repository.dart';
import '../../models/managed_user_item.dart';

class UsersState {
  const UsersState({
    required this.result,
    required this.search,
    required this.roleId,
    required this.isActive,
  });

  final PagedResult<ManagedUserItem> result;
  final String search;
  final String? roleId;
  final bool? isActive;
}

final usersRepositoryProvider = Provider<UsersRepository>(
  (ref) => UsersRepository(ref.watch(apiClientProvider)),
);

final userRolesProvider = FutureProvider<List<UserRoleItem>>(
  (ref) => ref.watch(usersRepositoryProvider).fetchRoles(),
);

final usersControllerProvider =
    AsyncNotifierProvider<UsersController, UsersState>(UsersController.new);

class UsersController extends AsyncNotifier<UsersState> {
  static const _pageSize = 10;

  UsersRepository get _repository => ref.read(usersRepositoryProvider);

  @override
  Future<UsersState> build() =>
      _fetch(search: '', roleId: null, isActive: null, page: 1);

  Future<UsersState> _fetch({
    required String search,
    required String? roleId,
    required bool? isActive,
    required int page,
  }) async {
    final result = await _repository.fetchUsers(
      search: search,
      roleId: roleId,
      isActive: isActive,
      page: page,
      pageSize: _pageSize,
    );
    return UsersState(
      result: result,
      search: search,
      roleId: roleId,
      isActive: isActive,
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current?.search ?? '',
        roleId: current?.roleId,
        isActive: current?.isActive,
        page: current?.result.pagination.page ?? 1,
      ),
    );
  }

  Future<void> search(String value) async {
    final current = state.asData?.value;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: value,
        roleId: current?.roleId,
        isActive: current?.isActive,
        page: 1,
      ),
    );
  }

  Future<void> changePage(int page) async {
    final current = state.asData?.value;
    if (current == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(
        search: current.search,
        roleId: current.roleId,
        isActive: current.isActive,
        page: page,
      ),
    );
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await _repository.createUser(payload);
    ref.invalidate(userRolesProvider);
    await refresh();
  }

  Future<void> updateUser(String id, Map<String, dynamic> payload) async {
    await _repository.updateUser(id, payload);
    await refresh();
  }

  Future<void> setStatus(String id, bool isActive) async {
    await _repository.setStatus(id, isActive);
    await refresh();
  }

  Future<void> updatePassword(String id, String password) async {
    await _repository.updatePassword(id, password);
  }
}
