import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../shared/widgets/async_value_view.dart';
import '../../models/institution_settings_item.dart';
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
                    initialValue: _initialValue(settings),
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
                            _Field(name: 'section_name', label: 'اسم القسم'),
                            _Field(name: 'division_name', label: 'اسم الشعبة'),
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
                            labelText: 'وصف/ترويسة التقارير',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _Field(
                          name: 'report_title',
                          label: 'عنوان التقرير',
                          width: 420,
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
                        Card(
                          color: const Color(0xFFF5F8FB),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تواقيع التقارير',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'اختياري: تظهر هذه التواقيع في نهاية آخر ورقة من تقرير HTML/الطباعة. الحد الأعلى 5 تواقيع.',
                                ),
                                const SizedBox(height: 12),
                                FormBuilderSwitch(
                                  name: 'show_report_signatures',
                                  title: const Text(
                                    'إظهار التواقيع في التقارير',
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(5, (index) {
                                  final number = index + 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _Field(
                                          name: 'signature_${index}_title',
                                          label: 'العنوان الوظيفي $number',
                                          width: 260,
                                        ),
                                        _Field(
                                          name: 'signature_${index}_name',
                                          label: 'اسم صاحب التوقيع $number',
                                          width: 260,
                                        ),
                                        _Field(
                                          name: 'signature_${index}_location',
                                          label: 'موقع/ملاحظة التوقيع $number',
                                          width: 260,
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
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
    final payload = Map<String, dynamic>.from(form.value);
    payload['report_signatures'] = _signaturesPayload(payload);
    await ref.read(institutionControllerProvider.notifier).save(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ معلومات المؤسسة')));
  }

  Map<String, dynamic> _initialValue(InstitutionSettingsItem settings) {
    final value = <String, dynamic>{
      'name': settings.name,
      'ministry_name': settings.ministryName,
      'department_name': settings.departmentName,
      'section_name': settings.sectionName,
      'division_name': settings.divisionName,
      'address': settings.address,
      'phone': settings.phone,
      'email': settings.email,
      'website': settings.website,
      'logo_path': settings.logoPath,
      'document_header': settings.documentHeader,
      'report_title': settings.reportTitle,
      'document_footer': settings.documentFooter,
      'show_report_signatures': settings.showReportSignatures,
    };

    for (var index = 0; index < 5; index++) {
      final signature = index < settings.reportSignatures.length
          ? settings.reportSignatures[index]
          : null;
      value['signature_${index}_title'] = signature?.title;
      value['signature_${index}_name'] = signature?.name;
      value['signature_${index}_location'] = signature?.location;
    }

    return value;
  }

  List<Map<String, dynamic>> _signaturesPayload(
    Map<String, dynamic> formValue,
  ) {
    final signatures = <Map<String, dynamic>>[];
    String? optional(String key) {
      final text = formValue[key]?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    for (var index = 0; index < 5; index++) {
      final signature = {
        'title': optional('signature_${index}_title'),
        'name': optional('signature_${index}_name'),
        'location': optional('signature_${index}_location'),
      };
      if (signature.values.any((value) => value != null)) {
        signatures.add(signature);
      }
      formValue.remove('signature_${index}_title');
      formValue.remove('signature_${index}_name');
      formValue.remove('signature_${index}_location');
    }

    return signatures;
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.name,
    required this.label,
    this.required = false,
    this.width = 320,
  });

  final String name;
  final String label;
  final bool required;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
