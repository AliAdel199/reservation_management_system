import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../models/managed_user_item.dart';
import '../controllers/users_controller.dart';

class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersControllerProvider);

    ref.listen(usersControllerProvider, (previous, next) {
      if (next.hasError && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'المستخدمون والصلاحيات',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'إدارة حسابات الدخول وربط كل مستخدم بدوره الرقابي.',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openUserDialog(),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('إضافة مستخدم'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'بحث بالاسم أو المستخدم أو البريد',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (value) =>
                      ref.read(usersControllerProvider.notifier).search(value),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => ref
                    .read(usersControllerProvider.notifier)
                    .search(_searchController.text),
                child: const Text('بحث'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: AsyncValueView(
                value: state,
                onRetry: () =>
                    ref.read(usersControllerProvider.notifier).refresh(),
                data: (data) => Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 1120,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('اسم المستخدم')),
                                DataColumn(label: Text('الاسم الكامل')),
                                DataColumn(label: Text('البريد')),
                                DataColumn(label: Text('الدور')),
                                DataColumn(label: Text('الحالة')),
                                DataColumn(label: Text('إجراءات')),
                              ],
                              rows: data.result.items.map((user) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(user.username)),
                                    DataCell(Text(user.fullName)),
                                    DataCell(Text(user.email)),
                                    DataCell(Text(user.roleName)),
                                    DataCell(
                                      Text(user.isActive ? 'فعال' : 'معطل'),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () =>
                                                _openUserDialog(user: user),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            tooltip: 'تعديل',
                                          ),
                                          IconButton(
                                            onPressed: () => _setStatus(user),
                                            icon: Icon(
                                              user.isActive
                                                  ? Icons.block_outlined
                                                  : Icons.check_circle_outline,
                                            ),
                                            tooltip: user.isActive
                                                ? 'تعطيل'
                                                : 'تفعيل',
                                          ),
                                          IconButton(
                                            onPressed: () =>
                                                _openPasswordDialog(user),
                                            icon: const Icon(Icons.lock_reset),
                                            tooltip: 'تغيير كلمة المرور',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _PaginationBar(
                      page: data.result.pagination.page,
                      totalPages: data.result.pagination.totalPages,
                      total: data.result.pagination.total,
                      onPrevious: data.result.pagination.page > 1
                          ? () => ref
                                .read(usersControllerProvider.notifier)
                                .changePage(data.result.pagination.page - 1)
                          : null,
                      onNext:
                          data.result.pagination.page <
                              data.result.pagination.totalPages
                          ? () => ref
                                .read(usersControllerProvider.notifier)
                                .changePage(data.result.pagination.page + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUserDialog({ManagedUserItem? user}) async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserDialog(user: user),
    );
    if (payload == null || !mounted) return;
    if (user == null) {
      await ref.read(usersControllerProvider.notifier).create(payload);
    } else {
      await ref
          .read(usersControllerProvider.notifier)
          .updateUser(user.id, payload);
    }
  }

  Future<void> _setStatus(ManagedUserItem user) async {
    await ref
        .read(usersControllerProvider.notifier)
        .setStatus(user.id, !user.isActive);
  }

  Future<void> _openPasswordDialog(ManagedUserItem user) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _PasswordDialog(),
    );
    if (password == null || !mounted) return;
    await ref
        .read(usersControllerProvider.notifier)
        .updatePassword(user.id, password);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور')));
  }
}

class _UserDialog extends ConsumerStatefulWidget {
  const _UserDialog({this.user});

  final ManagedUserItem? user;

  @override
  ConsumerState<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends ConsumerState<_UserDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(userRolesProvider);
    final user = widget.user;

    return AlertDialog(
      title: Text(user == null ? 'إضافة مستخدم' : 'تعديل مستخدم'),
      content: SizedBox(
        width: 520,
        child: roles.when(
          data: (items) => FormBuilder(
            key: _formKey,
            initialValue: {
              'username': user?.username,
              'full_name': user?.fullName,
              'email': user?.email,
              'role_id': user?.roleId,
              'is_active': user?.isActive ?? true,
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TextField(name: 'username', label: 'اسم المستخدم'),
                const SizedBox(height: 12),
                _TextField(name: 'full_name', label: 'الاسم الكامل'),
                const SizedBox(height: 12),
                _TextField(name: 'email', label: 'البريد الإلكتروني'),
                const SizedBox(height: 12),
                if (user == null) ...[
                  FormBuilderTextField(
                    name: 'password',
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    validator: FormBuilderValidators.minLength(
                      8,
                      errorText: '8 أحرف على الأقل',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FormBuilderDropdown<String>(
                  name: 'role_id',
                  decoration: const InputDecoration(labelText: 'الدور'),
                  validator: FormBuilderValidators.required(
                    errorText: 'الحقل مطلوب',
                  ),
                  items: items
                      .map(
                        (role) => DropdownMenuItem(
                          value: role.id,
                          child: Text(role.name),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                FormBuilderSwitch(
                  name: 'is_active',
                  title: const Text('حساب فعال'),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(error.toString()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    Navigator.of(context).pop(Map<String, dynamic>.from(form.value));
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تغيير كلمة المرور'),
      content: FormBuilder(
        key: _formKey,
        child: FormBuilderTextField(
          name: 'password',
          obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
          validator: FormBuilderValidators.minLength(
            8,
            errorText: '8 أحرف على الأقل',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('حفظ')),
      ],
    );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    Navigator.of(context).pop(form.value['password'].toString());
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.name, required this.label});

  final String name;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FormBuilderTextField(
      name: name,
      decoration: InputDecoration(labelText: label),
      validator: FormBuilderValidators.required(errorText: 'الحقل مطلوب'),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Text('إجمالي السجلات: $total'),
          const Spacer(),
          OutlinedButton(onPressed: onPrevious, child: const Text('السابق')),
          const SizedBox(width: 8),
          Text('الصفحة $page من $totalPages'),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onNext, child: const Text('التالي')),
        ],
      ),
    );
  }
}
