import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../controllers/institution_controller.dart';

class InstitutionPage extends ConsumerStatefulWidget {
  const InstitutionPage({super.key});

  @override
  ConsumerState<InstitutionPage> createState() => _InstitutionPageState();
}

class _InstitutionPageState extends ConsumerState<InstitutionPage> {
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(institutionControllerProvider);

    ref.listen(institutionControllerProvider, (previous, next) {
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
          Text(
            'معلومات المؤسسة',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'تستخدم هذه البيانات في الترويسة الرسمية للتقارير والطباعة.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AsyncValueView(
                  value: state,
                  onRetry: () => ref
                      .read(institutionControllerProvider.notifier)
                      .refresh(),
                  data: (settings) => FormBuilder(
                    key: _formKey,
                    initialValue: {
                      'name': settings.name,
                      'ministry_name': settings.ministryName,
                      'department_name': settings.departmentName,
                      'address': settings.address,
                      'phone': settings.phone,
                      'email': settings.email,
                      'website': settings.website,
                      'logo_path': settings.logoPath,
                      'document_header': settings.documentHeader,
                      'document_footer': settings.documentFooter,
                    },
                    child: ListView(
                      children: [
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _Field(
                              name: 'name',
                              label: 'اسم المؤسسة',
                              required: true,
                            ),
                            _Field(name: 'ministry_name', label: 'الوزارة'),
                            _Field(name: 'department_name', label: 'الدائرة'),
                            _Field(name: 'phone', label: 'الهاتف'),
                            _Field(name: 'email', label: 'البريد الإلكتروني'),
                            _Field(name: 'website', label: 'الموقع'),
                            _Field(name: 'logo_path', label: 'مسار الشعار'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FormBuilderTextField(
                          name: 'address',
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'العنوان',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FormBuilderTextField(
                          name: 'document_header',
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'ترويسة التقارير',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FormBuilderTextField(
                          name: 'document_footer',
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'تذييل التقارير',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('حفظ معلومات المؤسسة'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    await ref
        .read(institutionControllerProvider.notifier)
        .save(Map<String, dynamic>.from(form.value));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ معلومات المؤسسة')));
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.name,
    required this.label,
    this.required = false,
  });

  final String name;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: FormBuilderTextField(
        name: name,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? FormBuilderValidators.required(errorText: 'الحقل مطلوب')
            : null,
      ),
    );
  }
}
