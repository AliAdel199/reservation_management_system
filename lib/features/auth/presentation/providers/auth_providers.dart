import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/app_storage.dart';
import '../../data/auth_repository.dart';
import '../controllers/auth_controller.dart';

final appStorageProvider = Provider<AppStorage>((ref) => AppStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(appStorageProvider));
  client.onUnauthorized = (code) =>
      ref.read(authControllerProvider.notifier).endSession(code);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(appStorageProvider),
  ),
);
