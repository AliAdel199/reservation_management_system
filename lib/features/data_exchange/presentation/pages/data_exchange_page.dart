import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../budget_sections/presentation/controllers/budget_sections_controller.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../../reservations/presentation/controllers/reservations_controller.dart';
import '../../services/excel_sheet_helpers.dart';
import '../../services/import_value_parsers.dart';
import '../../services/import_matching.dart';

class DataExchangePage extends ConsumerStatefulWidget {
  const DataExchangePage({super.key});

  @override
  ConsumerState<DataExchangePage> createState() => _DataExchangePageState();
}

class _DataExchangePageState extends ConsumerState<DataExchangePage> {
  bool _isWorking = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).asData?.value?.user;
    final canImport = currentUser?.canImportData ?? false;
    final canExport = currentUser?.canExportData ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: double.infinity),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'استيراد وتصدير البيانات',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'تبادل البيانات مع Excel مع الحفاظ على التحقق المالي وسجل الإجراءات عبر الـ API.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ActionCard(
                  title: 'قالب البرامج والأبواب',
                  description:
                      'ينشئ ملف Excel بشيت للبرامج وشيت لشجرة الأبواب مع الباب الأب والكود الكامل ونوع الباب.',
                  icon: Icons.apps_outlined,
                  actionLabel: 'تصدير القالب',
                  onPressed: _isWorking || !canExport
                      ? null
                      : _exportProgramsTemplate,
                ),
                _ActionCard(
                  title: 'استيراد البرامج والأبواب',
                  description:
                      'يقرأ شيت البرامج أولاً ثم يبني شجرة الأبواب من الأعلى إلى الأسفل حسب الباب الأب والكود الكامل.',
                  icon: Icons.upload_file_outlined,
                  actionLabel: 'اختيار ملف Excel',
                  onPressed: _isWorking || !canImport ? null : _importPrograms,
                ),
                _ActionCard(
                  title: 'تصدير البرامج',
                  description:
                      'يصدّر البرامج الحالية مع شيت تفصيلي للأبواب الهرمية والتخصيص السنوي لكل باب نهائي.',
                  icon: Icons.download_outlined,
                  actionLabel: 'تصدير Excel',
                  onPressed: _isWorking || !canExport
                      ? null
                      : _exportProgramsData,
                ),
                _ActionCard(
                  title: 'قالب الحجوزات',
                  description:
                      'ينشئ ملف Excel للحجوزات يحتوي البرنامج والباب والمبلغ وحالة الحجز المبسطة.',
                  icon: Icons.assignment_outlined,
                  actionLabel: 'تصدير القالب',
                  onPressed: _isWorking || !canExport
                      ? null
                      : _exportReservationsTemplate,
                ),
                _ActionCard(
                  title: 'استيراد الحجوزات',
                  description:
                      'يضيف الحجوزات من Excel كحجوزات محجوزة أو معتمدة مع تطبيق قواعد الرصيد.',
                  icon: Icons.playlist_add_check_outlined,
                  actionLabel: 'اختيار ملف Excel',
                  onPressed: _isWorking || !canImport
                      ? null
                      : _importReservations,
                ),
                _ActionCard(
                  title: 'تصدير الحجوزات',
                  description:
                      'يصدّر الحجوزات الحالية مع الحالة والمصروف والمتبقي إلى ملف Excel للمتابعة والأرشفة.',
                  icon: Icons.download_for_offline_outlined,
                  actionLabel: 'تصدير Excel',
                  onPressed: _isWorking || !canExport
                      ? null
                      : _exportReservationsData,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'تعليمات مهمة',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 12),
                    _InstructionLine(
                      'لا تغيّر أسماء الأعمدة داخل القالب حتى يقرأها النظام بشكل صحيح.',
                    ),
                    _InstructionLine(
                      'السنة تقبل رقم السنة مثل 2026 أو اسم السنة المالية كما يظهر بالنظام.',
                    ),
                    _InstructionLine(
                      'رمز البرنامج داخلي حالياً؛ يكفي إدخال اسم البرنامج والسنة المالية.',
                    ),
                    _InstructionLine(
                      'قالب البرامج يحتوي شيتين: البرامج ثم الأبواب. في شيت الأبواب استخدم رمز الباب الأب أو الكود الكامل لبناء الشجرة.',
                    ),
                    _InstructionLine(
                      'نوع الباب يكون تجميعي أو نهائي. التخصيص السنوي يكتب فقط للأبواب النهائية التي تقبل الحجز والصرف.',
                    ),
                    _InstructionLine(
                      'أي سجل مكرر أو ناقص البيانات سيتم رفضه برسالة واضحة بدون حذف البيانات القديمة.',
                    ),
                    _InstructionLine(
                      'استيراد الحجوزات يقبل كود الباب النهائي أو الكود الكامل، ولا يقبل الحجز على باب تجميعي.',
                    ),
                    _InstructionLine(
                      'حالة الحجز في القالب تقبل فقط: محجوز أو معتمد. المصروف والملغي يتمان من داخل النظام للحفاظ على السجل المالي.',
                    ),
                    _InstructionLine(
                      'التخصيص السنوي يقرأ من الباب مباشرة؛ لذلك لا تحتاج إلى مرجع تخصيص داخل ملف الحجوزات.',
                    ),
                  ],
                ),
              ),
            ),
            if (_isWorking) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportProgramsTemplate() async {
    await _runSafely(() async {
      final fiscalYears = await ref.read(fiscalYearsLookupProvider.future);
      final activeYear = fiscalYears.where((item) => item.isActive).firstOrNull;
      final file = await buildDownloadsFile(
        prefix: 'programs_template',
        extension: 'xlsx',
      );
      final excel = Excel.createExcel();
      const sheetName = 'البرامج';
      final sheet = excel[sheetName];
      const sectionsSheetName = 'الأبواب';
      final sectionsSheet = excel[sectionsSheetName];
      final headers = ['السنة', 'اسم البرنامج', 'الوصف'];
      final sectionHeaders = [
        'السنة',
        'اسم البرنامج',
        'رمز الباب الأب',
        'رمز الباب',
        'الكود الكامل',
        'اسم الباب',
        'نوع الباب',
        'التخصيص السنوي',
        'ترتيب العرض',
        'الوصف',
        'فعال',
      ];

      writeRow(sheet, 0, headers.map((value) => TextCellValue(value)).toList());
      writeRow(sheet, 1, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('التشغيلية'),
        TextCellValue('برنامج الموازنة التشغيلية'),
      ]);
      writeRow(
        sectionsSheet,
        0,
        sectionHeaders.map((value) => TextCellValue(value)).toList(),
      );
      writeRow(sectionsSheet, 1, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('التشغيلية'),
        TextCellValue(''),
        TextCellValue('02'),
        TextCellValue('02'),
        TextCellValue('نفقات'),
        TextCellValue('تجميعي'),
        DoubleCellValue(0),
        IntCellValue(1),
        TextCellValue('باب تجميعي رئيسي'),
        TextCellValue('نعم'),
      ]);
      writeRow(sectionsSheet, 2, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('التشغيلية'),
        TextCellValue('02'),
        TextCellValue('0201'),
        TextCellValue('02 0201'),
        TextCellValue('تعويضات الموظفين'),
        TextCellValue('تجميعي'),
        DoubleCellValue(0),
        IntCellValue(1),
        TextCellValue('باب فرعي تجميعي'),
        TextCellValue('نعم'),
      ]);
      writeRow(sectionsSheet, 3, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('التشغيلية'),
        TextCellValue('02 0201'),
        TextCellValue('0101'),
        TextCellValue('02 0201 0101'),
        TextCellValue('وقود'),
        TextCellValue('نهائي'),
        DoubleCellValue(5000000),
        IntCellValue(1),
        TextCellValue('باب نهائي يقبل التخصيص والحجز والصرف'),
        TextCellValue('نعم'),
      ]);

      for (var index = 0; index < headers.length; index++) {
        sheet.setColumnWidth(index, index == 1 || index == 2 ? 28 : 18);
      }
      for (var index = 0; index < sectionHeaders.length; index++) {
        sectionsSheet.setColumnWidth(
          index,
          index == 1 || index == 5 || index == 9 ? 30 : 18,
        );
      }
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw const AppException(message: 'تعذر إنشاء قالب البرامج.');
      }
      await file.writeAsBytes(bytes, flush: true);
      await openFile(file.path);
      _showSuccessMessage('تم إنشاء قالب البرامج بنجاح: ${file.path}');
    });
  }

  Future<void> _importPrograms() async {
    await _runSafely(() async {
      final pickedFile = await picker.FilePicker.pickFiles(
        type: picker.FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );
      final path = pickedFile?.files.single.path;
      if (path == null) return;

      final fiscalYears = await ref.read(fiscalYearsLookupProvider.future);
      final programsRepository = ref.read(programsRepositoryProvider);
      final budgetSectionsRepository = ref.read(
        budgetSectionsRepositoryProvider,
      );
      final bytes = await File(path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      var programsSheet = findSheet(excel, const ['البرامج', 'برامج']);
      final sectionsSheet = findSheet(excel, const [
        'الأبواب',
        'الابواب',
        'أبواب',
        'ابواب',
        'budget_sections',
      ]);
      programsSheet ??= sectionsSheet == null
          ? excel.tables.values.firstOrNull
          : null;
      if ((programsSheet == null || programsSheet.rows.length < 2) &&
          (sectionsSheet == null || sectionsSheet.rows.length < 2)) {
        throw const AppException(
          message: 'ملف Excel لا يحتوي برامج أو أبواب للاستيراد.',
        );
      }

      var imported = 0;
      final errors = <String>[];

      if (programsSheet != null && programsSheet.rows.length >= 2) {
        final headers = headerMap(programsSheet.rows.first);
        for (
          var rowIndex = 1;
          rowIndex < programsSheet.rows.length;
          rowIndex++
        ) {
          final row = programsSheet.rows[rowIndex];
          if (rowIsEmpty(row)) continue;

          try {
            final fiscalYear = findFiscalYear(
              fiscalYears,
              cellByHeaders(row, headers, const [
                'السنة',
                'السنة المالية',
                'fiscal year',
                'year',
              ], fallbackIndex: 0),
            );
            final code = cellByHeaders(row, headers, const [
              'رمز البرنامج',
              'كود البرنامج',
              'code',
              'program code',
            ], fallbackIndex: -1);
            final name = cellByHeaders(row, headers, const [
              'اسم البرنامج',
              'البرنامج',
              'name',
              'program name',
            ], fallbackIndex: 1);
            final description = cellByHeaders(row, headers, const [
              'الوصف',
              'description',
            ], fallbackIndex: 2);

            if (name.isEmpty) {
              throw const AppException(message: 'اسم البرنامج مطلوب.');
            }

            await programsRepository.createProgram({
              // تعليق عربي: الرمز داخلي فقط لدعم قواعد البيانات أو النسخ القديمة التي ما زالت تتطلبه.
              'code': code.isEmpty
                  ? buildInternalProgramCode(fiscalYear.year, rowIndex)
                  : code,
              'fiscal_year_id': fiscalYear.id,
              'fiscal_year': fiscalYear.year,
              'name': name,
              'description': description,
            });
            imported++;
          } on AppException catch (exception) {
            errors.add(
              'شيت البرامج - السطر ${rowIndex + 1}: ${exception.message}',
            );
          } catch (exception) {
            errors.add('شيت البرامج - السطر ${rowIndex + 1}: $exception');
          }
        }
      }

      final refreshedPrograms = await programsRepository.fetchProgramLookup();

      if (sectionsSheet != null && sectionsSheet.rows.length >= 2) {
        final headers = headerMap(sectionsSheet.rows.first);
        final existingSections = await ref.read(
          allBudgetSectionsLookupProvider.future,
        );
        final sectionLookup = buildSectionLookup(existingSections);
        final parsedRows = <SectionImportRow>[];

        for (
          var rowIndex = 1;
          rowIndex < sectionsSheet.rows.length;
          rowIndex++
        ) {
          final row = sectionsSheet.rows[rowIndex];
          if (rowIsEmpty(row)) continue;

          try {
            final fiscalYear = findFiscalYear(
              fiscalYears,
              cellByHeaders(row, headers, const [
                'السنة',
                'السنة المالية',
                'fiscal year',
                'year',
              ], fallbackIndex: 0),
            );
            final program = findProgram(
              refreshedPrograms,
              code: '',
              name: cellByHeaders(row, headers, const [
                'اسم البرنامج',
                'البرنامج',
                'الميزانية',
                'program name',
                'program',
              ], fallbackIndex: 1),
              fiscalYearId: fiscalYear.id,
            );
            final parentCode = cellByHeaders(row, headers, const [
              'رمز الباب الأب',
              'كود الباب الأب',
              'الباب الأب',
              'parent code',
              'parent_code',
            ], fallbackIndex: -1);
            final sectionCode = cellByHeaders(row, headers, const [
              'رمز الباب',
              'كود الباب',
              'section code',
              'code',
            ], fallbackIndex: 3);
            final fullCode = cellByHeaders(row, headers, const [
              'الكود الكامل',
              'full code',
              'full_code',
              'path code',
            ], fallbackIndex: -1);
            final sectionName = cellByHeaders(row, headers, const [
              'اسم الباب',
              'الباب',
              'section name',
              'name',
            ], fallbackIndex: 5);
            final sectionType = cellByHeaders(row, headers, const [
              'نوع الباب',
              'النوع',
              'section type',
              'type',
              'is postable',
              'is_postable',
            ], fallbackIndex: -1);
            final allocatedAmount = parseAmount(
              cellByHeaders(row, headers, const [
                'التخصيص السنوي',
                'التخصيص',
                'annual allocation',
                'allocated amount',
              ], fallbackIndex: 7),
            );
            final sortOrder = parseInt(
              cellByHeaders(row, headers, const [
                'ترتيب العرض',
                'الترتيب',
                'sort order',
                'sort_order',
              ], fallbackIndex: -1),
            );
            final description = cellByHeaders(row, headers, const [
              'الوصف',
              'description',
            ], fallbackIndex: 9);
            final isActive = parseBool(
              cellByHeaders(row, headers, const [
                'فعال',
                'الحالة',
                'active',
                'is active',
              ], fallbackIndex: 10),
            );
            final isPostable = parsePostableSectionType(sectionType);

            if (sectionCode.isEmpty) {
              throw const AppException(message: 'رمز الباب مطلوب.');
            }
            if (sectionName.isEmpty) {
              throw const AppException(message: 'اسم الباب مطلوب.');
            }
            if (allocatedAmount < 0) {
              throw const AppException(
                message: 'التخصيص السنوي لا يمكن أن يكون سالباً.',
              );
            }

            parsedRows.add(
              SectionImportRow(
                rowNumber: rowIndex + 1,
                fiscalYear: fiscalYear,
                program: program,
                parentCode: parentCode,
                code: sectionCode,
                fullCode: fullCode.isEmpty
                    ? composeFullCode(parentCode, sectionCode)
                    : fullCode,
                name: sectionName,
                isPostable: isPostable,
                allocatedAmount: allocatedAmount,
                sortOrder: sortOrder,
                description: description,
                isActive: isActive,
              ),
            );
          } on AppException catch (exception) {
            errors.add(
              'شيت الأبواب - السطر ${rowIndex + 1}: ${exception.message}',
            );
          } catch (exception) {
            errors.add('شيت الأبواب - السطر ${rowIndex + 1}: $exception');
          }
        }

        final parentKeys = <String>{};
        for (final row in parsedRows) {
          final parentCode = row.parentCode.trim().isNotEmpty
              ? row.parentCode
              : parentCodeFromFullCode(row.fullCode);
          if (parentCode.trim().isNotEmpty) {
            parentKeys.add(sectionCodeKey(parentCode));
          }
        }

        parsedRows.sort((left, right) {
          final depthCompare = sectionCodeDepth(
            left.fullCode,
          ).compareTo(sectionCodeDepth(right.fullCode));
          if (depthCompare != 0) return depthCompare;
          final orderCompare = left.sortOrder.compareTo(right.sortOrder);
          if (orderCompare != 0) return orderCompare;
          return left.rowNumber.compareTo(right.rowNumber);
        });

        for (final row in parsedRows) {
          try {
            final inferredPostable =
                row.isPostable ??
                !parentKeys.contains(sectionCodeKey(row.fullCode));
            final parent = findImportedParentSection(row, sectionLookup);

            final created = await budgetSectionsRepository.createBudgetSection({
              'program_id': row.program.id,
              'fiscal_year_id': row.fiscalYear.id,
              'parent_id': parent?.id,
              'code': row.code,
              'name': row.name,
              'description': row.description,
              'allocated_amount': inferredPostable ? row.allocatedAmount : 0,
              'is_active': row.isActive,
              'is_postable': inferredPostable,
              'sort_order': row.sortOrder,
            });
            addSectionToLookup(sectionLookup, created);
            imported++;
          } on AppException catch (exception) {
            errors.add(
              'شيت الأبواب - السطر ${row.rowNumber}: ${exception.message}',
            );
          } catch (exception) {
            errors.add('شيت الأبواب - السطر ${row.rowNumber}: $exception');
          }
        }
      }

      ref.invalidate(programsControllerProvider);
      ref.invalidate(programLookupProvider);
      ref.invalidate(budgetSectionsControllerProvider);
      ref.invalidate(allBudgetSectionsLookupProvider);
      await _showImportResult(imported: imported, errors: errors);
    });
  }

  Future<void> _exportProgramsData() async {
    await _runSafely(() async {
      final programsRepository = ref.read(programsRepositoryProvider);
      final result = await programsRepository.fetchPrograms(
        search: '',
        fiscalYearId: null,
        page: 1,
        pageSize: 5000,
      );
      final sections = await ref.read(allBudgetSectionsLookupProvider.future);
      final sectionsById = {
        for (final section in sections) section.id: section,
      };
      final programsById = {
        for (final program in result.items) program.id: program,
      };

      final file = await buildDownloadsFile(
        prefix: 'programs_export',
        extension: 'xlsx',
      );
      final excel = Excel.createExcel();
      const sheetName = 'البرامج';
      final sheet = excel[sheetName];
      const sectionsSheetName = 'الأبواب';
      final sectionsSheet = excel[sectionsSheetName];
      final headers = [
        'السنة',
        'اسم البرنامج',
        'الوصف',
        'الأبواب',
        'مجموع التخصيص السنوي',
        'الحالة',
      ];
      final sectionHeaders = [
        'السنة',
        'اسم البرنامج',
        'رمز الباب الأب',
        'رمز الباب',
        'الكود الكامل',
        'اسم الباب',
        'نوع الباب',
        'التخصيص السنوي',
        'ترتيب العرض',
        'الوصف',
        'فعال',
      ];

      writeRow(sheet, 0, headers.map((value) => TextCellValue(value)).toList());
      writeRow(
        sectionsSheet,
        0,
        sectionHeaders.map((value) => TextCellValue(value)).toList(),
      );

      for (var index = 0; index < result.items.length; index++) {
        final program = result.items[index];
        writeRow(sheet, index + 1, [
          TextCellValue(
            program.fiscalYearName ?? program.fiscalYear.toString(),
          ),
          TextCellValue(program.name),
          TextCellValue(program.description ?? ''),
          IntCellValue(program.budgetSectionsCount),
          DoubleCellValue(program.totalAllocations),
          TextCellValue(program.isActive ? 'فعال' : 'غير فعال'),
        ]);
      }

      for (var index = 0; index < sections.length; index++) {
        final section = sections[index];
        final parent = sectionsById[section.parentId];
        final program = programsById[section.programId];
        writeRow(sectionsSheet, index + 1, [
          TextCellValue(
            section.fiscalYearName ?? program?.fiscalYear.toString() ?? '',
          ),
          TextCellValue(section.programName),
          TextCellValue(parent?.fullCode ?? parent?.code ?? ''),
          TextCellValue(section.code),
          TextCellValue(section.fullCode),
          TextCellValue(section.name),
          TextCellValue(section.isPostable ? 'نهائي' : 'تجميعي'),
          DoubleCellValue(section.allocatedAmount),
          IntCellValue(section.sortOrder),
          TextCellValue(section.description ?? ''),
          TextCellValue(section.isActive ? 'نعم' : 'لا'),
        ]);
      }

      for (var index = 0; index < headers.length; index++) {
        sheet.setColumnWidth(index, index == 2 || index == 3 ? 28 : 18);
      }
      for (var index = 0; index < sectionHeaders.length; index++) {
        sectionsSheet.setColumnWidth(
          index,
          index == 1 || index == 5 || index == 9 ? 30 : 18,
        );
      }
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw const AppException(message: 'تعذر إنشاء ملف تصدير البرامج.');
      }
      await file.writeAsBytes(bytes, flush: true);
      await openFile(file.path);
      _showSuccessMessage(
        'تم تصدير ${result.items.length} برنامج و ${sections.length} باب بنجاح: ${file.path}',
      );
    });
  }

  Future<void> _exportReservationsTemplate() async {
    await _runSafely(() async {
      final fiscalYears = await ref.read(fiscalYearsLookupProvider.future);
      final programs = await ref.read(programLookupProvider.future);
      final sections = await ref.read(allBudgetSectionsLookupProvider.future);
      final activeYear = fiscalYears.where((item) => item.isActive).firstOrNull;
      final firstProgram = programs.firstOrNull;
      final firstSection = sections
          .where(
            (section) =>
                section.programId == firstProgram?.id && section.isPostable,
          )
          .firstOrNull;

      final file = await buildDownloadsFile(
        prefix: 'reservations_template',
        extension: 'xlsx',
      );
      final excel = Excel.createExcel();
      const sheetName = 'الحجوزات';
      final sheet = excel[sheetName];
      final headers = [
        'السنة',
        'رقم الحجز',
        'الميزانية',
        'رمز الباب',
        'الباب',
        'الجهة المحجوز لها',
        'القسم',
        'رقم الهاتف',
        'المبلغ المحجوز',
        'تاريخ الحجز',
        'ملاحظة تنفيذ المحجوز',
        'حالة الحجز',
        'الوصف',
      ];

      writeRow(sheet, 0, headers.map((value) => TextCellValue(value)).toList());
      writeRow(sheet, 1, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('RES-${DateTime.now().millisecondsSinceEpoch}'),
        TextCellValue(firstProgram?.name ?? 'التشغيلية'),
        TextCellValue(firstSection?.fullCode ?? firstSection?.code ?? '0101'),
        TextCellValue(firstSection?.name ?? 'وقود'),
        TextCellValue('الجهة المحجوز لها'),
        TextCellValue('القسم'),
        TextCellValue('07700000000'),
        DoubleCellValue(0),
        TextCellValue(DateFormat('yyyy-MM-dd').format(DateTime.now())),
        TextCellValue(''),
        TextCellValue('محجوز'),
        TextCellValue(''),
      ]);

      for (var index = 0; index < headers.length; index++) {
        sheet.setColumnWidth(index, index == 6 || index == 11 ? 30 : 18);
      }
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw const AppException(message: 'تعذر إنشاء قالب الحجوزات.');
      }
      await file.writeAsBytes(bytes, flush: true);
      await openFile(file.path);
      _showSuccessMessage('تم إنشاء قالب الحجوزات بنجاح: ${file.path}');
    });
  }

  Future<void> _importReservations() async {
    await _runSafely(() async {
      final pickedFile = await picker.FilePicker.pickFiles(
        type: picker.FileType.custom,
        allowedExtensions: ['xlsx'],
        allowMultiple: false,
      );
      final path = pickedFile?.files.single.path;
      if (path == null) return;

      final fiscalYears = await ref.read(fiscalYearsLookupProvider.future);
      final programs = await ref.read(programLookupProvider.future);
      final sections = await ref.read(allBudgetSectionsLookupProvider.future);
      final reservationsRepository = ref.read(reservationsRepositoryProvider);
      final bytes = await File(path).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet =
          findSheet(excel, const [
            'الحجوزات',
            'حجوزات',
            'reservations',
            'reservation',
          ]) ??
          excel.tables.values.firstOrNull;
      if (sheet == null || sheet.rows.length < 2) {
        throw const AppException(
          message: 'ملف Excel لا يحتوي حجوزات للاستيراد.',
        );
      }

      var imported = 0;
      final errors = <String>[];
      final headers = headerMap(sheet.rows.first);

      for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        if (rowIsEmpty(row)) continue;

        try {
          final fiscalYear = findFiscalYear(
            fiscalYears,
            cellByHeaders(row, headers, const [
              'السنة',
              'السنة المالية',
              'fiscal year',
              'year',
            ], fallbackIndex: 0),
          );
          final reservationNumber = cellByHeaders(row, headers, const [
            'رقم الحجز',
            'reservation number',
          ], fallbackIndex: 1);
          final programCode = cellByHeaders(row, headers, const [
            'رمز الميزانية',
            'رمز البرنامج',
            'program code',
          ], fallbackIndex: -1);
          final programName = cellByHeaders(row, headers, const [
            'الميزانية',
            'اسم البرنامج',
            'البرنامج',
            'program name',
          ], fallbackIndex: 2);
          final program = findProgram(
            programs,
            code: programCode,
            name: programName,
            fiscalYearId: fiscalYear.id,
          );
          final section = findSection(
            sections,
            programId: program.id,
            fiscalYearId: fiscalYear.id,
            code: cellByHeaders(row, headers, const [
              'رمز الباب',
              'كود الباب',
              'section code',
            ], fallbackIndex: programCode.isEmpty ? 3 : 4),
            name: cellByHeaders(row, headers, const [
              'الباب',
              'اسم الباب',
              'section name',
            ], fallbackIndex: programCode.isEmpty ? 4 : 5),
          );
          final beneficiary = cellByHeaders(row, headers, const [
            'الجهة المحجوز لها',
            'المستفيد',
            'beneficiary',
          ], fallbackIndex: programCode.isEmpty ? 5 : 6);
          final requesterDepartment = cellByHeaders(row, headers, const [
            'القسم',
            'requester department',
            'department',
          ], fallbackIndex: programCode.isEmpty ? 6 : 7);
          final contactPhone = cellByHeaders(row, headers, const [
            'رقم الهاتف',
            'الهاتف',
            'phone',
          ], fallbackIndex: programCode.isEmpty ? 7 : 8);
          final amount = parseAmount(
            cellByHeaders(row, headers, const [
              'المبلغ المحجوز',
              'المبلغ',
              'amount',
            ], fallbackIndex: programCode.isEmpty ? 8 : 9),
          );
          final reservationDate =
              normalizeDate(
                cellByHeaders(row, headers, const [
                  'تاريخ الحجز',
                  'reservation date',
                  'date',
                ], fallbackIndex: programCode.isEmpty ? 9 : 10),
              ) ??
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          final executionNote = cellByHeaders(row, headers, const [
            'ملاحظة تنفيذ المحجوز',
            'ملاحظة التنفيذ',
            'execution note',
          ], fallbackIndex: programCode.isEmpty ? 10 : 11);
          final importStatus = parseReservationImportStatus(
            cellByHeaders(row, headers, const [
              'حالة الحجز',
              'status',
            ], fallbackIndex: programCode.isEmpty ? 11 : 12),
          );
          final description = cellByHeaders(row, headers, const [
            'الوصف',
            'description',
          ], fallbackIndex: programCode.isEmpty ? 12 : 13);

          if (reservationNumber.isEmpty) {
            throw const AppException(message: 'رقم الحجز مطلوب.');
          }
          if (beneficiary.isEmpty) {
            throw const AppException(message: 'الجهة المحجوز لها مطلوبة.');
          }
          if (amount <= 0) {
            throw const AppException(
              message: 'مبلغ الحجز يجب أن يكون أكبر من صفر.',
            );
          }

          final created = await reservationsRepository.createReservation({
            'reservation_number': reservationNumber,
            'program_id': program.id,
            'budget_section_id': section.id,
            'title': beneficiary,
            'beneficiary': beneficiary,
            'requester_department': requesterDepartment,
            'contact_phone': contactPhone,
            'execution_note': executionNote,
            'description': description,
            'reserved_amount': amount,
            'reservation_date': reservationDate,
          });

          // تعليق عربي: المعتمد يسمح بالصرف، أما المحجوز يبقى محجوزاً فقط.
          if (importStatus == ReservationImportStatus.approved) {
            await reservationsRepository.approve(created.id);
          }
          imported++;
        } on AppException catch (exception) {
          errors.add('السطر ${rowIndex + 1}: ${exception.message}');
        } catch (exception) {
          errors.add('السطر ${rowIndex + 1}: $exception');
        }
      }

      ref.invalidate(reservationsControllerProvider);
      await _showImportResult(imported: imported, errors: errors);
    });
  }

  Future<void> _exportReservationsData() async {
    await _runSafely(() async {
      final reservationsRepository = ref.read(reservationsRepositoryProvider);
      final sections = await ref.read(allBudgetSectionsLookupProvider.future);
      final sectionsById = {
        for (final section in sections) section.id: section,
      };
      final result = await reservationsRepository.fetchReservations(
        search: '',
        status: null,
        programId: null,
        budgetSectionId: null,
        fundingId: null,
        executionStatus: null,
        page: 1,
        pageSize: 5000,
        dateFrom: '',
        dateTo: '',
      );

      final file = await buildDownloadsFile(
        prefix: 'reservations_export',
        extension: 'xlsx',
      );
      final excel = Excel.createExcel();
      const sheetName = 'الحجوزات';
      final sheet = excel[sheetName];
      final headers = [
        'السنة',
        'رقم الحجز',
        'الميزانية',
        'رمز الباب',
        'الباب',
        'الجهة المحجوز لها',
        'القسم',
        'رقم الهاتف',
        'المبلغ المحجوز',
        'المصروف',
        'المتبقي',
        'حالة الحجز',
        'حالة التنفيذ',
        'تاريخ الحجز',
        'تاريخ الاعتماد',
        'تاريخ الإلغاء',
        'ملاحظة تنفيذ المحجوز',
        'الوصف',
      ];

      writeRow(sheet, 0, headers.map((value) => TextCellValue(value)).toList());

      for (var index = 0; index < result.items.length; index++) {
        final reservation = result.items[index];
        final section = sectionsById[reservation.budgetSectionId];
        writeRow(sheet, index + 1, [
          TextCellValue(yearFromDate(reservation.reservationDate)),
          TextCellValue(reservation.reservationNumber),
          TextCellValue(reservation.programName),
          TextCellValue(section?.fullCode ?? reservation.budgetSectionCode),
          TextCellValue(reservation.budgetSectionName),
          TextCellValue(reservation.beneficiary ?? ''),
          TextCellValue(reservation.requesterDepartment ?? ''),
          TextCellValue(reservation.contactPhone ?? ''),
          DoubleCellValue(reservation.reservedAmount),
          DoubleCellValue(reservation.spentAmount),
          DoubleCellValue(reservation.remainingAmount),
          TextCellValue(reservationStatusLabel(reservation.workflowStatus)),
          TextCellValue(executionStatusLabel(reservation.executionStatus)),
          TextCellValue(dateOnly(reservation.reservationDate)),
          TextCellValue(dateOnly(reservation.approvedAt)),
          TextCellValue(dateOnly(reservation.cancelledAt)),
          TextCellValue(reservation.executionNote ?? ''),
          TextCellValue(reservation.description ?? ''),
        ]);
      }

      for (var index = 0; index < headers.length; index++) {
        sheet.setColumnWidth(index, index == 6 || index == 16 ? 30 : 18);
      }
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw const AppException(message: 'تعذر إنشاء ملف تصدير الحجوزات.');
      }
      await file.writeAsBytes(bytes, flush: true);
      await openFile(file.path);
      _showSuccessMessage(
        'تم تصدير ${result.items.length} حجز بنجاح: ${file.path}',
      );
    });
  }

  Future<void> _runSafely(Future<void> Function() action) async {
    setState(() => _isWorking = true);
    try {
      await action();
    } on AppException catch (exception) {
      _showErrorMessage(exception.message);
    } catch (exception) {
      _showErrorMessage('تعذر تنفيذ العملية: $exception');
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _showImportResult({
    required int imported,
    required List<String> errors,
  }) async {
    if (!mounted) return;
    final hasErrors = errors.isNotEmpty;
    final title = hasErrors
        ? (imported > 0 ? 'اكتمل الاستيراد جزئياً' : 'فشل الاستيراد')
        : 'تم الاستيراد بنجاح';
    final statusColor = hasErrors
        ? (imported > 0 ? const Color(0xFFAC7B12) : const Color(0xFF9F2D2D))
        : const Color(0xFF1A7F5A);

    _showMessage(
      hasErrors
          ? 'تم استيراد $imported سجل، وتعذر استيراد ${errors.length} سجل.'
          : 'تم استيراد $imported سجل بنجاح.',
      backgroundColor: statusColor,
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasErrors
                  ? (imported > 0
                        ? Icons.warning_amber_rounded
                        : Icons.error_outline_rounded)
                  : Icons.check_circle_outline_rounded,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasErrors
                      ? 'تم استيراد $imported سجل، وتعذر استيراد ${errors.length} سجل.'
                      : 'تم استيراد $imported سجل بنجاح.',
                ),
                if (errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'السجلات غير المستوردة:',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  ...errors.take(20).map((error) => Text('• $error')),
                  if (errors.length > 20)
                    Text('و ${errors.length - 20} أخطاء إضافية.'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) =>
      _showMessage(message, backgroundColor: const Color(0xFF1A7F5A));

  void _showErrorMessage(String message) =>
      _showMessage(message, backgroundColor: const Color(0xFF9F2D2D));

  void _showMessage(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final IconData icon;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 34, color: const Color(0xFF0D4A73)),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(height: 1.7)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.table_chart_outlined),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionLine extends StatelessWidget {
  const _InstructionLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
