import '../../models/section_summary_item.dart';

enum ReportGrouping {
  bySection('حسب الباب'),
  byProgram('حسب البرنامج');

  const ReportGrouping(this.label);

  final String label;
}

enum ReportActivityFilter { all, noMovement }

enum ReportSort {
  sectionCodeAsc('رمز الباب تصاعدي'),
  allocationDesc('التخصيص الأعلى أولاً'),
  reservedDesc('المحجوز الأعلى أولاً'),
  spentDesc('المصروف الأعلى أولاً'),
  disposableAsc('الأقل قابل للصرف أولاً'),
  programNameAsc('اسم البرنامج تصاعدي');

  const ReportSort(this.label);

  final String label;

  int compare(SectionSummaryItem a, SectionSummaryItem b, int selectedMonth) {
    switch (this) {
      case ReportSort.sectionCodeAsc:
        return a.sectionCode.compareTo(b.sectionCode);
      case ReportSort.allocationDesc:
        return b.allocatedAmount.compareTo(a.allocatedAmount);
      case ReportSort.reservedDesc:
        return b.totalReserved.compareTo(a.totalReserved);
      case ReportSort.spentDesc:
        return b.totalSpent.compareTo(a.totalSpent);
      case ReportSort.disposableAsc:
        return a
            .effectivePeriodDisposable(selectedMonth)
            .compareTo(b.effectivePeriodDisposable(selectedMonth));
      case ReportSort.programNameAsc:
        return a.programName.compareTo(b.programName);
    }
  }
}

enum ReportColumn {
  program('program', 230),
  section('section', 300),
  allocation('allocation', 170),
  reserved('reserved', 190),
  unreserved('unreserved', 230),
  spent('spent', 160),
  remainingBySpent('remainingBySpent', 230),
  monthlyQuota('monthlyQuota', 180),
  periodAllowed('periodAllowed', 190),
  periodDisposable('periodDisposable', 190),
  rates('rates', 240);

  const ReportColumn(this.key, this.width);

  final String key;
  final double width;

  String label({required String monthName, required ReportGrouping grouping}) {
    switch (this) {
      case ReportColumn.program:
        return 'البرنامج';
      case ReportColumn.section:
        return grouping == ReportGrouping.byProgram ? 'النطاق' : 'الباب';
      case ReportColumn.allocation:
        return 'التخصيص';
      case ReportColumn.reserved:
        return 'المحجوز من التخصيصات';
      case ReportColumn.unreserved:
        return 'المتبقي من التخصيصات غير محجوز';
      case ReportColumn.spent:
        return 'المصروف الفعلي';
      case ReportColumn.remainingBySpent:
        return 'المتبقي من التخصيصات حسب المصروف';
      case ReportColumn.monthlyQuota:
        return 'نسبة الحجز 1/12';
      case ReportColumn.periodAllowed:
        return 'الحجز لغاية $monthName';
      case ReportColumn.periodDisposable:
        return 'المبلغ القابل للصرف';
      case ReportColumn.rates:
        return 'النسب';
    }
  }
}
