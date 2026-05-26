import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/models/auth_user.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.currentLocation, this.user});

  final String currentLocation;
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManageUsers = user?.canManageUsers ?? false;
    final canManageBackups = user?.canManageBackups ?? false;
    final canViewAuditLogs = user?.canViewAuditLogs ?? false;
    final canUseDataExchange = user?.canUseDataExchange ?? false;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1F33), Color(0xFF123B56)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المنظومة المالية',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نظام إدارة الحجوزات المالية',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NavItem(
                  title: 'لوحة التحكم',
                  icon: Icons.dashboard_outlined,
                  selected: currentLocation == '/dashboard',
                  onTap: () => context.go('/dashboard'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'التنبيهات',
                  icon: Icons.notifications_active_outlined,
                  selected: currentLocation == '/alerts',
                  onTap: () => context.go('/alerts'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'البرامج',
                  icon: Icons.grid_view_rounded,
                  selected: currentLocation == '/programs',
                  onTap: () => context.go('/programs'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'السنوات المالية',
                  icon: Icons.event_note_outlined,
                  selected: currentLocation == '/fiscal-years',
                  onTap: () => context.go('/fiscal-years'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'الأبواب',
                  icon: Icons.account_tree_outlined,
                  selected: currentLocation == '/budget-sections',
                  onTap: () => context.go('/budget-sections'),
                ),
                // تعليق عربي: التمويل الشهري معلّق حالياً لأن الدورة المعتمدة
                // تعتمد على التخصيص السنوي للأبواب وليس تمويلاً شهرياً منفصلاً.
                const SizedBox(height: 12),
                _NavItem(
                  title: 'الحجوزات',
                  icon: Icons.assignment_outlined,
                  selected: currentLocation == '/reservations',
                  onTap: () => context.go('/reservations'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'الصرف',
                  icon: Icons.payments_outlined,
                  selected: currentLocation == '/expenses',
                  onTap: () => context.go('/expenses'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'التقارير',
                  icon: Icons.summarize_outlined,
                  selected: currentLocation == '/reports',
                  onTap: () => context.go('/reports'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'معلومات المؤسسة',
                  icon: Icons.account_balance_outlined,
                  selected: currentLocation == '/institution',
                  onTap: () => context.go('/institution'),
                ),
                const SizedBox(height: 12),
                _NavItem(
                  title: 'إعداد الاتصال',
                  icon: Icons.settings_ethernet_outlined,
                  selected: currentLocation == '/api-settings',
                  onTap: () => context.go('/api-settings'),
                ),
                const SizedBox(height: 12),
                if (canManageUsers) ...[
                  _NavItem(
                    title: 'المستخدمون',
                    icon: Icons.people_alt_outlined,
                    selected: currentLocation == '/users',
                    onTap: () => context.go('/users'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canManageBackups) ...[
                  _NavItem(
                    title: 'Backup واسترجاع',
                    icon: Icons.backup_outlined,
                    selected: currentLocation == '/backups',
                    onTap: () => context.go('/backups'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canViewAuditLogs) ...[
                  _NavItem(
                    title: 'سجل الإجراءات',
                    icon: Icons.history_edu_outlined,
                    selected: currentLocation == '/audit-logs',
                    onTap: () => context.go('/audit-logs'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (canUseDataExchange)
                  _NavItem(
                    title: 'استيراد/تصدير',
                    icon: Icons.import_export_outlined,
                    selected: currentLocation == '/data-exchange',
                    onTap: () => context.go('/data-exchange'),
                  ),
              ],
            ),
          ),
          // const SizedBox(height: 16),
          // Text(
          //   'الدورة المالية الآن تربط التخصيص والحجز والصرف والتقارير عبر السجل المالي.',
          //   style: theme.textTheme.bodySmall?.copyWith(
          //     color: Colors.white.withValues(alpha: 0.7),
          //     height: 1.8,
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
