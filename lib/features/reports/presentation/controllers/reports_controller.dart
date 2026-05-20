import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/reports_repository.dart';
import '../../models/section_summary_item.dart';

class SectionSummaryFilters {
  const SectionSummaryFilters({
    this.fiscalYearId,
    this.budgetTypeId,
    this.programId,
    this.sectionId,
    this.dateFrom,
    this.dateTo,
  });

  final String? fiscalYearId;
  final String? budgetTypeId;
  final String? programId;
  final String? sectionId;
  final String? dateFrom;
  final String? dateTo;

  @override
  bool operator ==(Object other) {
    return other is SectionSummaryFilters &&
        other.fiscalYearId == fiscalYearId &&
        other.budgetTypeId == budgetTypeId &&
        other.programId == programId &&
        other.sectionId == sectionId &&
        other.dateFrom == dateFrom &&
        other.dateTo == dateTo;
  }

  @override
  int get hashCode => Object.hash(
    fiscalYearId,
    budgetTypeId,
    programId,
    sectionId,
    dateFrom,
    dateTo,
  );
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(apiClientProvider)),
);

final sectionSummaryProvider = FutureProvider.autoDispose
    .family<List<SectionSummaryItem>, SectionSummaryFilters>((ref, filters) {
      return ref
          .watch(reportsRepositoryProvider)
          .fetchSectionSummary(
            fiscalYearId: filters.fiscalYearId,
            budgetTypeId: filters.budgetTypeId,
            programId: filters.programId,
            sectionId: filters.sectionId,
            dateFrom: filters.dateFrom,
            dateTo: filters.dateTo,
          );
    });
