import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_topbar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.currentLocation,
    required this.child,
  });

  final String currentLocation;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).asData?.value;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(currentLocation: currentLocation, user: session?.user),
          Expanded(
            child: Column(
              children: [
                AppTopBar(
                  fullName: session?.user.fullName ?? 'مستخدم النظام',
                  roleName: session?.user.roleName ?? '',
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
