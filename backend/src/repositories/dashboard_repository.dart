import 'package:postgres/postgres.dart';

import '../models/dashboard_summary.dart';

class DashboardRepository {
  const DashboardRepository();

  static const double lowFundingThreshold = 50000;

  Future<DashboardSummary> fetchSummary(
    Session session, {
    required String? fiscalYearId,
  }) async {
    final result = await session.execute(
      Sql.named('''
        WITH effective_year AS (
          -- تعليق عربي: الداشبورد يعمل على السنة المفتوحة افتراضياً،
          -- أو السنة المختارة من واجهة المستخدم إذا تم إرسالها.
          SELECT COALESCE(
            NULLIF(@fiscal_year_id, '')::uuid,
            (
              SELECT id
              FROM fiscal_years
              WHERE is_active = TRUE
              ORDER BY year DESC
              LIMIT 1
            )
          ) AS id
        ),
        allocation_fallback AS (
          SELECT
            f.budget_section_id AS section_id,
            COALESCE(SUM(f.allocated_amount), 0) AS total_allocation
          FROM fundings f
          WHERE f.deleted_at IS NULL
          GROUP BY f.budget_section_id
        ),
        annual_allocation AS (
          SELECT COALESCE(SUM(
            CASE
              WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
              ELSE COALESCE(af.total_allocation, 0)
            END
          ), 0) AS total_allocation
          FROM budget_sections bs
          CROSS JOIN effective_year ey
          LEFT JOIN allocation_fallback af ON af.section_id = bs.id
          WHERE bs.deleted_at IS NULL
            AND (ey.id IS NULL OR bs.fiscal_year_id = ey.id)
        ),
        ledger AS (
          SELECT
            COALESCE(SUM(CASE
              WHEN ft.transaction_type::text = 'reservation_hold' THEN ft.amount
              WHEN ft.transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -ft.amount
              ELSE 0
            END), 0) AS total_reserved,
            COALESCE(SUM(CASE
              WHEN ft.transaction_type::text = 'expense_disbursement' THEN ft.amount
              WHEN ft.transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -ft.amount
              ELSE 0
            END), 0) AS total_spent
          FROM financial_transactions ft
          CROSS JOIN effective_year ey
          LEFT JOIN budget_sections bs
            ON bs.id = COALESCE(ft.section_id, ft.budget_section_id)
          WHERE ey.id IS NULL
            OR COALESCE(ft.fiscal_year_id, bs.fiscal_year_id) = ey.id
        ),
        totals AS (
          SELECT
            -- تعليق عربي: التخصيص العام رجع لمصدره السنوي من الأبواب،
            -- والتمويل الشهري معلّق حالياً لحين تثبيت فكرته المحاسبية.
            aa.total_allocation AS total_allocation,
            l.total_reserved,
            l.total_spent
          FROM annual_allocation aa
          CROSS JOIN ledger l
        )
        SELECT
          total_allocation,
          total_reserved,
          total_spent,
          total_allocation - total_reserved AS remaining_balance,
          total_allocation - total_reserved AS disposable_balance,
          CASE
            WHEN total_allocation > 0 THEN ROUND((total_reserved / total_allocation) * 100, 2)
            ELSE 0
          END AS reservation_rate,
          CASE
            WHEN total_allocation > 0 THEN ROUND((total_spent / total_allocation) * 100, 2)
            ELSE 0
          END AS spending_rate
        FROM totals
        LIMIT 1
      '''),
      parameters: {'fiscal_year_id': fiscalYearId ?? ''},
    );

    if (result.isEmpty) {
      return const DashboardSummary(
        totalAllocation: 0,
        totalReserved: 0,
        totalSpent: 0,
        remainingBalance: 0,
        disposableBalance: 0,
        reservationRate: 0,
        spendingRate: 0,
      );
    }

    final row = result.first.toColumnMap();

    double parse(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    final alerts = await _fetchBalanceAlerts(
      session,
      fiscalYearId: fiscalYearId,
      threshold: lowFundingThreshold,
    );

    return DashboardSummary(
      totalAllocation: parse(row['total_allocation']),
      totalReserved: parse(row['total_reserved']),
      totalSpent: parse(row['total_spent']),
      remainingBalance: parse(row['remaining_balance']),
      disposableBalance: parse(row['disposable_balance']),
      reservationRate: parse(row['reservation_rate']),
      spendingRate: parse(row['spending_rate']),
      balanceAlerts: alerts,
    );
  }

  Future<List<DashboardBalanceAlert>> _fetchBalanceAlerts(
    Session session, {
    required String? fiscalYearId,
    required double threshold,
    int limit = 8,
  }) async {
    final result = await session.execute(
      Sql.named('''
        WITH effective_year AS (
          SELECT COALESCE(
            NULLIF(@fiscal_year_id, '')::uuid,
            (
              SELECT id
              FROM fiscal_years
              WHERE is_active = TRUE
              ORDER BY year DESC
              LIMIT 1
            )
          ) AS id
        ),
        ledger AS (
          SELECT
            COALESCE(ft.section_id, ft.budget_section_id) AS section_id,
            COALESCE(SUM(CASE
              WHEN ft.transaction_type::text = 'expense_disbursement' THEN ft.amount
              WHEN ft.transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -ft.amount
              ELSE 0
            END), 0) AS total_spent
          FROM financial_transactions ft
          CROSS JOIN effective_year ey
          LEFT JOIN budget_sections bs
            ON bs.id = COALESCE(ft.section_id, ft.budget_section_id)
          WHERE COALESCE(ft.section_id, ft.budget_section_id) IS NOT NULL
            AND (
              ey.id IS NULL
              OR COALESCE(ft.fiscal_year_id, bs.fiscal_year_id) = ey.id
            )
          GROUP BY COALESCE(ft.section_id, ft.budget_section_id)
        ),
        section_reserved AS (
          SELECT
            COALESCE(ft.section_id, ft.budget_section_id) AS section_id,
            COALESCE(SUM(CASE
              WHEN ft.transaction_type::text = 'reservation_hold' THEN ft.amount
              WHEN ft.transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -ft.amount
              ELSE 0
            END), 0) AS total_reserved
          FROM financial_transactions ft
          CROSS JOIN effective_year ey
          LEFT JOIN budget_sections bs
            ON bs.id = COALESCE(ft.section_id, ft.budget_section_id)
          WHERE COALESCE(ft.section_id, ft.budget_section_id) IS NOT NULL
            AND (
              ey.id IS NULL
              OR COALESCE(ft.fiscal_year_id, bs.fiscal_year_id) = ey.id
            )
          GROUP BY COALESCE(ft.section_id, ft.budget_section_id)
        ),
        allocation_fallback AS (
          SELECT
            f.budget_section_id AS section_id,
            COALESCE(SUM(f.allocated_amount), 0) AS total_allocation
          FROM fundings f
          WHERE f.deleted_at IS NULL
          GROUP BY f.budget_section_id
        ),
        section_funding AS (
          SELECT
            bs.id AS section_id,
            bs.code AS section_code,
            bs.name AS section_name,
            p.name AS program_name,
            CASE
              WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
              ELSE COALESCE(af.total_allocation, 0)
            END AS section_allocation
          FROM budget_sections bs
          INNER JOIN programs p ON p.id = bs.program_id
          CROSS JOIN effective_year ey
          LEFT JOIN allocation_fallback af ON af.section_id = bs.id
          WHERE bs.deleted_at IS NULL
            AND (ey.id IS NULL OR bs.fiscal_year_id = ey.id)
        )
        SELECT
          sf.program_name,
          sf.section_code,
          sf.section_name,
          (sf.section_allocation - COALESCE(sr.total_reserved, 0)) AS remaining_balance,
          (sf.section_allocation - COALESCE(l.total_spent, 0)) AS remaining_funding
        FROM section_funding sf
        LEFT JOIN ledger l ON l.section_id = sf.section_id
        LEFT JOIN section_reserved sr ON sr.section_id = sf.section_id
        WHERE (
            sf.section_allocation > 0
            AND (sf.section_allocation - COALESCE(sr.total_reserved, 0)) <= @threshold
          )
        ORDER BY
          (sf.section_allocation - COALESCE(sr.total_reserved, 0)) ASC,
          sf.program_name,
          sf.section_code
        LIMIT @limit
      '''),
      parameters: {
        'fiscal_year_id': fiscalYearId ?? '',
        'threshold': threshold,
        'limit': limit,
      },
    );

    double parse(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;

    return result.map((row) {
      final data = row.toColumnMap();
      final remainingFunding = parse(data['remaining_funding']);
      final remainingBalance = parse(data['remaining_balance']);
      final sectionCode = data['section_code']?.toString() ?? '';
      final sectionName = data['section_name']?.toString() ?? '';
      final alertValue = remainingBalance <= threshold
          ? remainingBalance
          : remainingFunding;
      final severity = alertValue <= 0 ? 'critical' : 'warning';
      final isAllocationAlert = remainingBalance <= threshold;

      return DashboardBalanceAlert(
        programName: data['program_name']?.toString() ?? '',
        sectionCode: sectionCode,
        sectionName: sectionName,
        remainingFunding: alertValue,
        threshold: threshold,
        severity: severity,
        message: alertValue <= 0
            ? 'نفد رصيد الباب $sectionCode - $sectionName أو تجاوز الحد المتاح.'
            : isAllocationAlert
            ? 'رصيد الباب $sectionCode - $sectionName سوف ينفذ قريباً.'
            : 'تمويل الباب $sectionCode - $sectionName سوف ينفذ قريباً.',
      );
    }).toList();
  }

  Future<List<DashboardBalanceAlert>> fetchBalanceAlerts(
    Session session, {
    String? fiscalYearId,
    double threshold = 50000,
    int limit = 100,
  }) {
    return _fetchBalanceAlerts(
      session,
      fiscalYearId: fiscalYearId,
      threshold: threshold,
      limit: limit,
    );
  }

  Future<List<DashboardSectionCard>> fetchSectionCards(
    Session session, {
    String? fiscalYearId,
    int level = 3,
    int limit = 12,
  }) async {
    final safeLevel = level < 1 ? 1 : level;
    final result = await session.execute(
      Sql.named('''
        WITH RECURSIVE effective_year AS (
          SELECT COALESCE(
            NULLIF(@fiscal_year_id, '')::uuid,
            (
              SELECT id
              FROM fiscal_years
              WHERE is_active = TRUE
              ORDER BY year DESC
              LIMIT 1
            )
          ) AS id
        ),
        allocation_fallback AS (
          SELECT
            f.budget_section_id AS section_id,
            COALESCE(SUM(f.allocated_amount), 0) AS total_allocation
          FROM fundings f
          WHERE f.deleted_at IS NULL
          GROUP BY f.budget_section_id
        ),
        direct_sections AS (
          SELECT
            bs.id AS section_id,
            bs.parent_id,
            bs.program_id,
            p.name AS program_name,
            COALESCE(bs.full_code, bs.code) AS section_code,
            bs.name AS section_name,
            bs.level,
            bs.path,
            bs.is_postable,
            CASE
              WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
              ELSE COALESCE(af.total_allocation, 0)
            END AS direct_allocation
          FROM budget_sections bs
          INNER JOIN programs p ON p.id = bs.program_id
          CROSS JOIN effective_year ey
          LEFT JOIN allocation_fallback af ON af.section_id = bs.id
          WHERE bs.deleted_at IS NULL
            AND bs.is_active = TRUE
            AND (ey.id IS NULL OR bs.fiscal_year_id = ey.id)
        ),
        cards_base AS (
          SELECT ds.*
          FROM direct_sections ds
          WHERE ds.level = @level
            AND EXISTS (
              SELECT 1
              FROM direct_sections child
              WHERE child.parent_id = ds.section_id
            )
        ),
        card_descendants AS (
          SELECT
            cb.section_id AS card_id,
            cb.section_id AS descendant_id
          FROM cards_base cb
          UNION ALL
          SELECT
            cd.card_id,
            child.section_id AS descendant_id
          FROM card_descendants cd
          INNER JOIN direct_sections child
            ON child.parent_id = cd.descendant_id
        ),
        ledger_direct AS (
          SELECT
            COALESCE(ft.section_id, ft.budget_section_id) AS section_id,
            COALESCE(SUM(CASE
              WHEN ft.transaction_type::text = 'reservation_hold' THEN ft.amount
              WHEN ft.transaction_type::text IN ('reservation_release', 'reservation_cancel') THEN -ft.amount
              ELSE 0
            END), 0) AS total_reserved,
            COALESCE(SUM(CASE
              WHEN ft.transaction_type::text = 'expense_disbursement' THEN ft.amount
              WHEN ft.transaction_type::text IN ('expense_reversal', 'expense_cancel') THEN -ft.amount
              ELSE 0
            END), 0) AS total_spent
          FROM financial_transactions ft
          CROSS JOIN effective_year ey
          LEFT JOIN budget_sections bs
            ON bs.id = COALESCE(ft.section_id, ft.budget_section_id)
          WHERE COALESCE(ft.section_id, ft.budget_section_id) IS NOT NULL
            AND (
              ey.id IS NULL
              OR COALESCE(ft.fiscal_year_id, bs.fiscal_year_id) = ey.id
            )
          GROUP BY COALESCE(ft.section_id, ft.budget_section_id)
        ),
        direct_child_counts AS (
          SELECT
            parent.section_id,
            COUNT(child.section_id)::int AS children_count,
            COUNT(child.section_id) FILTER (WHERE child.is_postable)::int
              AS postable_children_count
          FROM cards_base parent
          LEFT JOIN direct_sections child ON child.parent_id = parent.section_id
          GROUP BY parent.section_id
        ),
        card_totals AS (
          SELECT
            cb.section_id,
            cb.program_id,
            cb.program_name,
            cb.section_code,
            cb.section_name,
            COALESCE(SUM(
              CASE
                WHEN child.is_postable THEN child.direct_allocation
                ELSE 0
              END
            ), 0) AS total_allocation,
            COALESCE(SUM(ld.total_reserved), 0) AS total_reserved,
            COALESCE(SUM(ld.total_spent), 0) AS total_spent,
            COALESCE(dcc.children_count, 0) AS children_count,
            COALESCE(dcc.postable_children_count, 0) AS postable_children_count
          FROM cards_base cb
          INNER JOIN card_descendants cd ON cd.card_id = cb.section_id
          INNER JOIN direct_sections child ON child.section_id = cd.descendant_id
          LEFT JOIN ledger_direct ld ON ld.section_id = cd.descendant_id
          LEFT JOIN direct_child_counts dcc ON dcc.section_id = cb.section_id
          GROUP BY
            cb.section_id,
            cb.program_id,
            cb.program_name,
            cb.section_code,
            cb.section_name,
            dcc.children_count,
            dcc.postable_children_count
        ),
        card_ancestors AS (
          SELECT
            cb.section_id,
            cb.section_id AS ancestor_id,
            0 AS depth
          FROM cards_base cb
          UNION ALL
          SELECT
            ca.section_id,
            parent.section_id AS ancestor_id,
            ca.depth + 1 AS depth
          FROM card_ancestors ca
          INNER JOIN direct_sections current_section
            ON current_section.section_id = ca.ancestor_id
          INNER JOIN direct_sections parent
            ON parent.section_id = current_section.parent_id
        ),
        card_paths AS (
          SELECT
            ca.section_id,
            STRING_AGG(ds.section_name, ' / ' ORDER BY ca.depth DESC)
              AS section_path
          FROM card_ancestors ca
          INNER JOIN direct_sections ds ON ds.section_id = ca.ancestor_id
          GROUP BY ca.section_id
        )
        SELECT
          ct.section_id,
          ct.program_id,
          ct.program_name,
          ct.section_code,
          ct.section_name,
          COALESCE(cp.section_path, ct.section_name) AS section_path,
          ct.total_allocation,
          ct.total_reserved,
          ct.total_spent,
          ct.total_allocation - ct.total_reserved AS remaining_balance,
          ct.children_count,
          ct.postable_children_count
        FROM card_totals ct
        LEFT JOIN card_paths cp ON cp.section_id = ct.section_id
        ORDER BY ct.total_reserved DESC, ct.total_allocation DESC, ct.section_code
        LIMIT @limit
      '''),
      parameters: {
        'fiscal_year_id': fiscalYearId ?? '',
        'level': safeLevel,
        'limit': limit,
      },
    );

    double parseDouble(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '0') ?? 0;
    int parseInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;

    return result.map((row) {
      final data = row.toColumnMap();
      return DashboardSectionCard(
        sectionId: data['section_id']?.toString() ?? '',
        programId: data['program_id']?.toString() ?? '',
        programName: data['program_name']?.toString() ?? '',
        sectionCode: data['section_code']?.toString() ?? '',
        sectionName: data['section_name']?.toString() ?? '',
        sectionPath: data['section_path']?.toString() ?? '',
        totalAllocation: parseDouble(data['total_allocation']),
        totalReserved: parseDouble(data['total_reserved']),
        totalSpent: parseDouble(data['total_spent']),
        remainingBalance: parseDouble(data['remaining_balance']),
        childrenCount: parseInt(data['children_count']),
        postableChildrenCount: parseInt(data['postable_children_count']),
      );
    }).toList();
  }
}
