import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../budget_sections/models/budget_section_item.dart';
import '../../../budget_sections/presentation/controllers/budget_sections_controller.dart';
import '../../../fiscal_years/models/fiscal_year_item.dart';
import '../../../fiscal_years/presentation/controllers/fiscal_years_controller.dart';
import '../../../programs/models/program_item.dart';
import '../../../programs/presentation/controllers/programs_controller.dart';
import '../../../reservations/presentation/controllers/reservations_controller.dart';

enum _ReservationImportStatus { reserved, approved }

class DataExchangePage extends ConsumerStatefulWidget {
  const DataExchangePage({super.key});

  @override
  ConsumerState<DataExchangePage> createState() => _DataExchangePageState();
}

class _DataExchangePageState extends ConsumerState<DataExchangePage> {
  bool _isWorking = false;

  @override
  Widget build(BuildContext context) {
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
                      'ينشئ ملف Excel بشيت للبرامج وشيت للأبواب مع التخصيص السنوي لكل باب.',
                  icon: Icons.apps_outlined,
                  actionLabel: 'تصدير القالب',
                  onPressed: _isWorking ? null : _exportProgramsTemplate,
                ),
                _ActionCard(
                  title: 'استيراد البرامج والأبواب',
                  description:
                      'يقرأ شيت البرامج أولاً ثم يضيف الأبواب المرتبطة بها حسب اسم البرنامج والسنة.',
                  icon: Icons.upload_file_outlined,
                  actionLabel: 'اختيار ملف Excel',
                  onPressed: _isWorking ? null : _importPrograms,
                ),
                _ActionCard(
                  title: 'تصدير البرامج',
                  description:
                      'يصدّر البرامج الحالية مع عدد الأبواب ومجموع التخصيص السنوي.',
                  icon: Icons.download_outlined,
                  actionLabel: 'تصدير Excel',
                  onPressed: _isWorking ? null : _exportProgramsData,
                ),
                _ActionCard(
                  title: 'قالب الحجوزات',
                  description:
                      'ينشئ ملف Excel للحجوزات يحتوي البرنامج والباب والمبلغ وحالة الحجز المبسطة.',
                  icon: Icons.assignment_outlined,
                  actionLabel: 'تصدير القالب',
                  onPressed: _isWorking ? null : _exportReservationsTemplate,
                ),
                _ActionCard(
                  title: 'استيراد الحجوزات',
                  description:
                      'يضيف الحجوزات من Excel كحجوزات محجوزة أو معتمدة مع تطبيق قواعد الرصيد.',
                  icon: Icons.playlist_add_check_outlined,
                  actionLabel: 'اختيار ملف Excel',
                  onPressed: _isWorking ? null : _importReservations,
                ),
                _ActionCard(
                  title: 'تصدير الحجوزات',
                  description:
                      'يصدّر الحجوزات الحالية مع الحالة والمصروف والمتبقي إلى ملف Excel للمتابعة والأرشفة.',
                  icon: Icons.download_for_offline_outlined,
                  actionLabel: 'تصدير Excel',
                  onPressed: _isWorking ? null : _exportReservationsData,
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
                      'قالب البرامج يحتوي شيتين: البرامج ثم الأبواب. الأبواب تعتمد على اسم البرنامج والسنة المالية.',
                    ),
                    _InstructionLine(
                      'أي سجل مكرر أو ناقص البيانات سيتم رفضه برسالة واضحة بدون حذف البيانات القديمة.',
                    ),
                    _InstructionLine(
                      'استيراد الحجوزات لا يتجاوز قواعد الرصيد؛ إذا المبلغ أكبر من المتاح سيرفضه الخادم.',
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
      final file = await _buildDownloadsFile(
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
        'رمز الباب',
        'اسم الباب',
        'التخصيص السنوي',
        'الوصف',
        'فعال',
      ];

      _writeRow(
        sheet,
        0,
        headers.map((value) => TextCellValue(value)).toList(),
      );
      _writeRow(sheet, 1, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('التشغيلية'),
        TextCellValue('برنامج الموازنة التشغيلية'),
      ]);
      _writeRow(
        sectionsSheet,
        0,
        sectionHeaders.map((value) => TextCellValue(value)).toList(),
      );
      _writeRow(sectionsSheet, 1, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('التشغيلية'),
        TextCellValue('0101'),
        TextCellValue('وقود'),
        DoubleCellValue(0),
        TextCellValue('باب الوقود ضمن البرنامج التشغيلي'),
        TextCellValue('نعم'),
      ]);

      for (var index = 0; index < headers.length; index++) {
        sheet.setColumnWidth(index, index == 1 || index == 2 ? 28 : 18);
      }
      for (var index = 0; index < sectionHeaders.length; index++) {
        sectionsSheet.setColumnWidth(
          index,
          index == 1 || index == 3 || index == 5 ? 28 : 18,
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
      await _openFile(file.path);
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
      var programsSheet = _findSheet(excel, const ['البرامج', 'برامج']);
      final sectionsSheet = _findSheet(excel, const [
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
        final headers = _headerMap(programsSheet.rows.first);
        for (
          var rowIndex = 1;
          rowIndex < programsSheet.rows.length;
          rowIndex++
        ) {
          final row = programsSheet.rows[rowIndex];
          if (_rowIsEmpty(row)) continue;

          try {
            final fiscalYear = _findFiscalYear(
              fiscalYears,
              _cellByHeaders(row, headers, const [
                'السنة',
                'السنة المالية',
                'fiscal year',
                'year',
              ], fallbackIndex: 0),
            );
            final code = _cellByHeaders(row, headers, const [
              'رمز البرنامج',
              'كود البرنامج',
              'code',
              'program code',
            ], fallbackIndex: -1);
            final name = _cellByHeaders(row, headers, const [
              'اسم البرنامج',
              'البرنامج',
              'name',
              'program name',
            ], fallbackIndex: 1);
            final description = _cellByHeaders(row, headers, const [
              'الوصف',
              'description',
            ], fallbackIndex: 2);

            if (name.isEmpty) {
              throw const AppException(message: 'اسم البرنامج مطلوب.');
            }

            await programsRepository.createProgram({
              // تعليق عربي: الرمز داخلي فقط لدعم قواعد البيانات أو النسخ القديمة التي ما زالت تتطلبه.
              'code': code.isEmpty
                  ? _buildInternalProgramCode(fiscalYear.year, rowIndex)
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
        final headers = _headerMap(sectionsSheet.rows.first);
        for (
          var rowIndex = 1;
          rowIndex < sectionsSheet.rows.length;
          rowIndex++
        ) {
          final row = sectionsSheet.rows[rowIndex];
          if (_rowIsEmpty(row)) continue;

          try {
            final fiscalYear = _findFiscalYear(
              fiscalYears,
              _cellByHeaders(row, headers, const [
                'السنة',
                'السنة المالية',
                'fiscal year',
                'year',
              ], fallbackIndex: 0),
            );
            final program = _findProgram(
              refreshedPrograms,
              code: '',
              name: _cellByHeaders(row, headers, const [
                'اسم البرنامج',
                'البرنامج',
                'program name',
                'program',
              ], fallbackIndex: 1),
              fiscalYearId: fiscalYear.id,
            );
            final sectionCode = _cellByHeaders(row, headers, const [
              'رمز الباب',
              'كود الباب',
              'section code',
              'code',
            ], fallbackIndex: 2);
            final sectionName = _cellByHeaders(row, headers, const [
              'اسم الباب',
              'الباب',
              'section name',
              'name',
            ], fallbackIndex: 3);
            final allocatedAmount = _parseAmount(
              _cellByHeaders(row, headers, const [
                'التخصيص السنوي',
                'التخصيص',
                'annual allocation',
                'allocated amount',
              ], fallbackIndex: 4),
            );
            final description = _cellByHeaders(row, headers, const [
              'الوصف',
              'description',
            ], fallbackIndex: 5);
            final isActive = _parseBool(
              _cellByHeaders(row, headers, const [
                'فعال',
                'الحالة',
                'active',
                'is active',
              ], fallbackIndex: 6),
            );

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

            await budgetSectionsRepository.createBudgetSection({
              'program_id': program.id,
              'fiscal_year_id': fiscalYear.id,
              'code': sectionCode,
              'name': sectionName,
              'description': description,
              'allocated_amount': allocatedAmount,
              'is_active': isActive,
            });
            imported++;
          } on AppException catch (exception) {
            errors.add(
              'شيت الأبواب - السطر ${rowIndex + 1}: ${exception.message}',
            );
          } catch (exception) {
            errors.add('شيت الأبواب - السطر ${rowIndex + 1}: $exception');
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

      final file = await _buildDownloadsFile(
        prefix: 'programs_export',
        extension: 'xlsx',
      );
      final excel = Excel.createExcel();
      const sheetName = 'البرامج';
      final sheet = excel[sheetName];
      final headers = [
        'السنة',
        'اسم البرنامج',
        'الوصف',
        'الأبواب',
        'مجموع التخصيص السنوي',
        'الحالة',
      ];

      _writeRow(
        sheet,
        0,
        headers.map((value) => TextCellValue(value)).toList(),
      );

      for (var index = 0; index < result.items.length; index++) {
        final program = result.items[index];
        _writeRow(sheet, index + 1, [
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

      for (var index = 0; index < headers.length; index++) {
        sheet.setColumnWidth(index, index == 2 || index == 3 ? 28 : 18);
      }
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw const AppException(message: 'تعذر إنشاء ملف تصدير البرامج.');
      }
      await file.writeAsBytes(bytes, flush: true);
      await _openFile(file.path);
      _showSuccessMessage(
        'تم تصدير ${result.items.length} برنامج بنجاح: ${file.path}',
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
          .where((section) => section.programId == firstProgram?.id)
          .firstOrNull;

      final file = await _buildDownloadsFile(
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

      _writeRow(
        sheet,
        0,
        headers.map((value) => TextCellValue(value)).toList(),
      );
      _writeRow(sheet, 1, [
        TextCellValue((activeYear?.year ?? DateTime.now().year).toString()),
        TextCellValue('RES-${DateTime.now().millisecondsSinceEpoch}'),
        TextCellValue(firstProgram?.name ?? 'التشغيلية'),
        TextCellValue(firstSection?.code ?? '0101'),
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
      await _openFile(file.path);
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
      final sheet = excel.tables.values.firstOrNull;
      if (sheet == null || sheet.rows.length < 2) {
        throw const AppException(
          message: 'ملف Excel لا يحتوي حجوزات للاستيراد.',
        );
      }

      var imported = 0;
      final errors = <String>[];

      for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final headers = _headerMap(sheet.rows.first);
        final row = sheet.rows[rowIndex];
        if (_rowIsEmpty(row)) continue;

        try {
          final fiscalYear = _findFiscalYear(
            fiscalYears,
            _cellByHeaders(row, headers, const [
              'السنة',
              'السنة المالية',
              'fiscal year',
              'year',
            ], fallbackIndex: 0),
          );
          final reservationNumber = _cellByHeaders(row, headers, const [
            'رقم الحجز',
            'reservation number',
          ], fallbackIndex: 1);
          final programCode = _cellByHeaders(row, headers, const [
            'رمز الميزانية',
            'رمز البرنامج',
            'program code',
          ], fallbackIndex: -1);
          final programName = _cellByHeaders(row, headers, const [
            'الميزانية',
            'اسم البرنامج',
            'البرنامج',
            'program name',
          ], fallbackIndex: 2);
          final program = _findProgram(
            programs,
            code: programCode,
            name: programName,
            fiscalYearId: fiscalYear.id,
          );
          final section = _findSection(
            sections,
            programId: program.id,
            fiscalYearId: fiscalYear.id,
            code: _cellByHeaders(row, headers, const [
              'رمز الباب',
              'كود الباب',
              'section code',
            ], fallbackIndex: programCode.isEmpty ? 3 : 4),
            name: _cellByHeaders(row, headers, const [
              'الباب',
              'اسم الباب',
              'section name',
            ], fallbackIndex: programCode.isEmpty ? 4 : 5),
          );
          final beneficiary = _cellByHeaders(row, headers, const [
            'الجهة المحجوز لها',
            'المستفيد',
            'beneficiary',
          ], fallbackIndex: programCode.isEmpty ? 5 : 6);
          final requesterDepartment = _cellByHeaders(row, headers, const [
            'القسم',
            'requester department',
            'department',
          ], fallbackIndex: programCode.isEmpty ? 6 : 7);
          final contactPhone = _cellByHeaders(row, headers, const [
            'رقم الهاتف',
            'الهاتف',
            'phone',
          ], fallbackIndex: programCode.isEmpty ? 7 : 8);
          final amount = _parseAmount(
            _cellByHeaders(row, headers, const [
              'المبلغ المحجوز',
              'المبلغ',
              'amount',
            ], fallbackIndex: programCode.isEmpty ? 8 : 9),
          );
          final reservationDate =
              _normalizeDate(
                _cellByHeaders(row, headers, const [
                  'تاريخ الحجز',
                  'reservation date',
                  'date',
                ], fallbackIndex: programCode.isEmpty ? 9 : 10),
              ) ??
              DateFormat('yyyy-MM-dd').format(DateTime.now());
          final executionNote = _cellByHeaders(row, headers, const [
            'ملاحظة تنفيذ المحجوز',
            'ملاحظة التنفيذ',
            'execution note',
          ], fallbackIndex: programCode.isEmpty ? 10 : 11);
          final importStatus = _parseReservationImportStatus(
            _cellByHeaders(row, headers, const [
              'حالة الحجز',
              'status',
            ], fallbackIndex: programCode.isEmpty ? 11 : 12),
          );
          final description = _cellByHeaders(row, headers, const [
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
          if (importStatus == _ReservationImportStatus.approved) {
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
      final result = await reservationsRepository.fetchReservations(
        search: '',
        status: null,
        programId: null,
        budgetSectionId: null,
        fundingId: null,
        executionStatus: null,
        page: 1,
        pageSize: 5000,
      );

      final file = await _buildDownloadsFile(
        prefix: 'reservations_export',
        extension: 'xlsx',
      );
      final excel = Excel.createExcel();
      const sheetName = 'الحجوزات';
      final sheet = excel[sheetName];
      final headers = [
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

      _writeRow(
        sheet,
        0,
        headers.map((value) => TextCellValue(value)).toList(),
      );

      for (var index = 0; index < result.items.length; index++) {
        final reservation = result.items[index];
        _writeRow(sheet, index + 1, [
          TextCellValue(reservation.reservationNumber),
          TextCellValue(reservation.programName),
          TextCellValue(reservation.budgetSectionCode),
          TextCellValue(reservation.budgetSectionName),
          TextCellValue(reservation.beneficiary ?? ''),
          TextCellValue(reservation.requesterDepartment ?? ''),
          TextCellValue(reservation.contactPhone ?? ''),
          DoubleCellValue(reservation.reservedAmount),
          DoubleCellValue(reservation.spentAmount),
          DoubleCellValue(reservation.remainingAmount),
          TextCellValue(_reservationStatusLabel(reservation.workflowStatus)),
          TextCellValue(_executionStatusLabel(reservation.executionStatus)),
          TextCellValue(_dateOnly(reservation.reservationDate)),
          TextCellValue(_dateOnly(reservation.approvedAt)),
          TextCellValue(_dateOnly(reservation.cancelledAt)),
          TextCellValue(reservation.executionNote ?? ''),
          TextCellValue(reservation.description ?? ''),
        ]);
      }

      for (var index = 0; index < headers.length; index++) {
        sheet.setColumnWidth(index, index == 5 || index == 15 ? 30 : 18);
      }
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      final bytes = excel.encode();
      if (bytes == null) {
        throw const AppException(message: 'تعذر إنشاء ملف تصدير الحجوزات.');
      }
      await file.writeAsBytes(bytes, flush: true);
      await _openFile(file.path);
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

  Future<File> _buildDownloadsFile({
    required String prefix,
    required String extension,
  }) async {
    final home =
        Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final directory = Directory('$home\\Downloads\\reservation_import_export');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return File('${directory.path}\\${prefix}_$timestamp.$extension');
  }

  Future<void> _openFile(String path) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [path]);
      return;
    }
    await Process.run('xdg-open', [path]);
  }

  Sheet? _findSheet(Excel excel, List<String> names) {
    for (final name in names) {
      final sheet = excel.tables[name];
      if (sheet != null) {
        return sheet;
      }
    }
    return null;
  }

  void _writeRow(Sheet sheet, int rowIndex, List<CellValue> values) {
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: columnIndex,
                  rowIndex: rowIndex,
                ),
              )
              .value =
          values[columnIndex];
    }
  }

  bool _rowIsEmpty(List<Data?> row) {
    return row.every((cell) => _cellText(cell).trim().isEmpty);
  }

  String _cellText(Data? cell) {
    final value = cell?.value;
    return switch (value) {
      null => '',
      TextCellValue() => (value.value.text ?? '').trim(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value ? 'true' : 'false',
      DateCellValue() => DateFormat(
        'yyyy-MM-dd',
      ).format(value.asDateTimeLocal()),
      DateTimeCellValue() => DateFormat(
        'yyyy-MM-dd',
      ).format(value.asDateTimeLocal()),
      FormulaCellValue() => value.formula,
      TimeCellValue() => value.asDuration().toString(),
    };
  }

  Map<String, int> _headerMap(List<Data?> row) {
    final headers = <String, int>{};
    for (var index = 0; index < row.length; index++) {
      final value = _normalizeHeader(_cellText(row.elementAtOrNull(index)));
      if (value.isNotEmpty) {
        headers[value] = index;
      }
    }
    return headers;
  }

  String _cellByHeaders(
    List<Data?> row,
    Map<String, int> headers,
    List<String> names, {
    required int fallbackIndex,
  }) {
    for (final name in names) {
      final index = headers[_normalizeHeader(name)];
      if (index != null) {
        return _cellText(row.elementAtOrNull(index));
      }
    }

    if (fallbackIndex < 0) {
      return '';
    }
    return _cellText(row.elementAtOrNull(fallbackIndex));
  }

  String _normalizeHeader(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  String _buildInternalProgramCode(int fiscalYear, int rowIndex) =>
      'AUTO-$fiscalYear-${DateTime.now().microsecondsSinceEpoch}-$rowIndex';

  FiscalYearItem _findFiscalYear(List<FiscalYearItem> items, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const AppException(message: 'السنة المالية مطلوبة.');
    }
    return items.firstWhere(
      (item) => item.year.toString() == normalized || item.name == normalized,
      orElse: () =>
          throw AppException(message: 'السنة المالية غير موجودة: $normalized'),
    );
  }

  ProgramItem _findProgram(
    List<ProgramItem> items, {
    required String code,
    required String name,
    String? fiscalYearId,
  }) {
    final normalizedCode = code.trim();
    final normalizedName = name.trim();
    if (normalizedCode.isEmpty && normalizedName.isEmpty) {
      throw const AppException(message: 'البرنامج مطلوب.');
    }
    return items.firstWhere(
      (item) =>
          _sameFiscalYear(item.fiscalYearId, fiscalYearId) &&
          ((normalizedCode.isNotEmpty && item.code == normalizedCode) ||
              (normalizedName.isNotEmpty &&
                  _sameBusinessName(item.name, normalizedName))),
      orElse: () => throw AppException(
        message:
            'البرنامج غير موجود: ${normalizedCode.isEmpty ? normalizedName : normalizedCode}',
      ),
    );
  }

  bool _sameFiscalYear(String? itemFiscalYearId, String? selectedFiscalYearId) {
    if (selectedFiscalYearId == null || selectedFiscalYearId.isEmpty) {
      return true;
    }

    // تعليق عربي: بعض البيانات القديمة قد لا تحمل معرف السنة، لذلك لا نرفضها إذا الاسم مطابق.
    return itemFiscalYearId == null ||
        itemFiscalYearId.isEmpty ||
        itemFiscalYearId == selectedFiscalYearId;
  }

  bool _sameBusinessName(String left, String right) {
    final normalizedLeft = _normalizeBusinessName(left);
    final normalizedRight = _normalizeBusinessName(right);
    if (normalizedLeft == normalizedRight) {
      return true;
    }

    final leftWithoutArticle = _removeArabicArticle(normalizedLeft);
    final rightWithoutArticle = _removeArabicArticle(normalizedRight);
    return leftWithoutArticle == rightWithoutArticle ||
        normalizedLeft.contains(normalizedRight) ||
        normalizedRight.contains(normalizedLeft) ||
        leftWithoutArticle.contains(rightWithoutArticle) ||
        rightWithoutArticle.contains(leftWithoutArticle);
  }

  String _normalizeBusinessName(String value) {
    final withoutPrefix = value
        .trim()
        .replaceFirst(RegExp(r'^\d+\s*[-ـ–]\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    return withoutPrefix
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '')
        .toLowerCase()
        .trim();
  }

  String _removeArabicArticle(String value) =>
      value.startsWith('ال') ? value.substring(2) : value;

  BudgetSectionItem _findSection(
    List<BudgetSectionItem> items, {
    required String programId,
    required String fiscalYearId,
    required String code,
    required String name,
  }) {
    final normalizedCode = code.trim();
    final normalizedName = name.trim();
    if (normalizedCode.isEmpty && normalizedName.isEmpty) {
      throw const AppException(message: 'الباب مطلوب.');
    }
    return items.firstWhere(
      (item) =>
          item.programId == programId &&
          item.fiscalYearId == fiscalYearId &&
          ((normalizedCode.isNotEmpty && item.code == normalizedCode) ||
              (normalizedName.isNotEmpty && item.name == normalizedName)),
      orElse: () => throw AppException(
        message:
            'الباب غير موجود: ${normalizedCode.isEmpty ? normalizedName : normalizedCode}',
      ),
    );
  }

  double _parseAmount(String value) {
    final cleaned = value.replaceAll(',', '').replaceAll('د.ع', '').trim();
    return double.tryParse(cleaned) ?? 0;
  }

  bool _parseBool(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'نعم' ||
        normalized == 'فعال' ||
        normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes') {
      return true;
    }
    if (normalized == 'لا' ||
        normalized == 'غير فعال' ||
        normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }
    throw AppException(message: 'قيمة فعال غير صحيحة: $value');
  }

  _ReservationImportStatus _parseReservationImportStatus(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'محجوز' ||
        normalized == 'reserved' ||
        normalized == 'draft' ||
        normalized == 'حجز') {
      return _ReservationImportStatus.reserved;
    }
    if (normalized == 'معتمد' || normalized == 'approved') {
      return _ReservationImportStatus.approved;
    }
    if (normalized == 'مصروف' ||
        normalized == 'spent' ||
        normalized == 'completed') {
      throw const AppException(
        message:
            'لا يمكن استيراد حجز بحالة مصروف؛ استورده كمعتمد ثم سجّل الصرف من شاشة الصرف.',
      );
    }
    if (normalized == 'ملغي' ||
        normalized == 'cancelled' ||
        normalized == 'canceled') {
      throw const AppException(
        message:
            'لا يمكن استيراد حجز ملغي؛ الإلغاء يجب أن يتم من داخل النظام حتى يعكس السجل المالي الحركة.',
      );
    }
    throw AppException(message: 'حالة الحجز غير مدعومة: $value');
  }

  String? _normalizeDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) {
      throw AppException(message: 'التاريخ غير صحيح: $normalized');
    }
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  String _dateOnly(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  String _reservationStatusLabel(String status) {
    return switch (status) {
      'approved' => 'معتمد',
      'partially_spent' || 'fully_spent' || 'completed' => 'مصروف',
      'cancelled' => 'ملغي',
      _ => 'محجوز',
    };
  }

  String _executionStatusLabel(String status) {
    return switch (status) {
      'executed' => 'منفذ',
      'partially_executed' => 'منفذ جزئياً',
      _ => 'غير منفذ',
    };
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
