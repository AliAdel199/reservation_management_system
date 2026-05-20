import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/app_storage.dart';
import '../../data/auth_repository.dart';

final appStorageProvider = Provider<AppStorage>((ref) => AppStorage());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(appStorageProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(appStorageProvider),
  ),
);
