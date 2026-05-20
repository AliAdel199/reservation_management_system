import 'package:postgres/postgres.dart';

class ReportsRepository {
  const ReportsRepository();

  Future<List<Map<String, dynamic>>> sectionSummary(
    Session session, {
    required String? fiscalYearId,
    required String? budgetTypeId,
    required String? programId,
    required String? sectionId,
    required String? dateFrom,
    required String? dateTo,
  }) async {
    final result = await session.execute(
      Sql.named('''
        WITH RECURSIVE effective_year AS (
          -- تعليق عربي: التقرير يعمل افتراضياً على السنة المالية المفتوحة،
          -- وإذا اختار المستخدم سنة محددة نستخدمها بدلاً من المفتوحة.
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
          WHERE COALESCE(ft.section_id, ft.budget_section_id) IS NOT NULL
            AND (@date_from = '' OR ft.transaction_date::date >= @date_from::date)
            AND (@date_to = '' OR ft.transaction_date::date <= @date_to::date)
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
        direct_section_scope AS (
          SELECT
            bs.id AS section_id,
            bs.parent_id,
            bs.code AS section_code,
            COALESCE(bs.full_code, bs.code) AS section_full_code,
            bs.name AS section_name,
            bs.level AS section_level,
            bs.path AS section_path,
            bs.is_postable,
            p.code AS program_code,
            p.name AS program_name,
            fy.name AS fiscal_year_name,
            bt.name AS budget_type_name,
            bs.fiscal_year_id,
            bs.budget_type_id,
            bs.program_id,
            CASE
              WHEN COALESCE(bs.allocated_amount, 0) > 0 THEN bs.allocated_amount
              ELSE COALESCE(af.total_allocation, 0)
            END AS legacy_section_allocation,
            0::numeric AS month_funding
          FROM budget_sections bs
          INNER JOIN programs p ON p.id = bs.program_id
          LEFT JOIN fiscal_years fy ON fy.id = bs.fiscal_year_id
          LEFT JOIN budget_types bt ON bt.id = bs.budget_type_id
          LEFT JOIN allocation_fallback af ON af.section_id = bs.id
          WHERE bs.deleted_at IS NULL
        ),
        section_descendants AS (
          SELECT
            dss.section_id,
            dss.section_id AS descendant_id
          FROM direct_section_scope dss
          UNION ALL
          SELECT
            sd.section_id,
            child.section_id AS descendant_id
          FROM section_descendants sd
          INNER JOIN direct_section_scope child
            ON child.parent_id = sd.descendant_id
        ),
        section_scope AS (
          SELECT
            parent.section_id,
            parent.section_code,
            parent.section_full_code,
            parent.section_name,
            parent.section_level,
            parent.section_path,
            parent.is_postable,
            parent.program_code,
            parent.program_name,
            parent.fiscal_year_name,
            parent.budget_type_name,
            parent.fiscal_year_id,
            parent.budget_type_id,
            parent.program_id,
            COALESCE(SUM(
              CASE
                WHEN child.is_postable THEN child.legacy_section_allocation
                ELSE 0
              END
            ), 0) AS allocated_amount,
            0::numeric AS month_funding
          FROM direct_section_scope parent
          INNER JOIN section_descendants sd ON sd.section_id = parent.section_id
          INNER JOIN direct_section_scope child
            ON child.section_id = sd.descendant_id
          GROUP BY
            parent.section_id,
            parent.section_code,
            parent.section_full_code,
            parent.section_name,
            parent.section_level,
            parent.section_path,
            parent.is_postable,
            parent.program_code,
            parent.program_name,
            parent.fiscal_year_name,
            parent.budget_type_name,
            parent.fiscal_year_id,
            parent.budget_type_id,
            parent.program_id
        ),
        ledger AS (
          SELECT
            sd.section_id,
            COALESCE(SUM(ld.total_reserved), 0) AS total_reserved,
            COALESCE(SUM(ld.total_spent), 0) AS total_spent
          FROM section_descendants sd
          LEFT JOIN ledger_direct ld ON ld.section_id = sd.descendant_id
          GROUP BY sd.section_id
        )
        SELECT
          ss.section_id,
          ss.section_full_code AS section_code,
          ss.section_name,
          ss.program_code,
          ss.program_name,
          ss.fiscal_year_name,
          ss.budget_type_name,
          ss.allocated_amount,
          ss.month_funding AS total_funding,
          COALESCE(l.total_reserved, 0) AS total_reserved,
          COALESCE(l.total_spent, 0) AS total_spent,
          (ss.allocated_amount - COALESCE(l.total_reserved, 0)) AS remaining_allocation,
          (ss.allocated_amount - COALESCE(l.total_spent, 0)) AS remaining_by_spent,
          (ss.allocated_amount / 12) AS monthly_quota,
          -- تعليق عربي: رقم الشهر يمثل تسلسل الفترة المالية للحجز.
          -- مثال: كانون الثاني = 1، شباط = 2، وهكذا.
          GREATEST(
            1,
            LEAST(
              12,
              CASE
                WHEN @date_to = '' THEN EXTRACT(MONTH FROM CURRENT_DATE)::int
                ELSE EXTRACT(MONTH FROM @date_to::date)::int
              END
            )
          ) AS allowed_months,
          (
            -- تعليق عربي: الحجز لغاية الشهر = نسبة الحجز 1/12 * تسلسل الشهر.
            (
              ss.allocated_amount / 12
            ) * GREATEST(
              1,
              LEAST(
                12,
                CASE
                  WHEN @date_to = '' THEN EXTRACT(MONTH FROM CURRENT_DATE)::int
                  ELSE EXTRACT(MONTH FROM @date_to::date)::int
                END
              )
            )
          ) AS period_allowed_amount,
          (
            (
              (
                  ss.allocated_amount / 12
              ) * GREATEST(
                1,
                LEAST(
                  12,
                  CASE
                    WHEN @date_to = '' THEN EXTRACT(MONTH FROM CURRENT_DATE)::int
                    ELSE EXTRACT(MONTH FROM @date_to::date)::int
                  END
                )
              )
            ) - COALESCE(l.total_reserved, 0)
          ) AS period_disposable_amount,
          0::numeric AS remaining_funding,
          (ss.allocated_amount - COALESCE(l.total_reserved, 0)) AS disposable_amount,
          CASE
            WHEN ss.allocated_amount > 0 THEN
              ROUND((COALESCE(l.total_reserved, 0) / ss.allocated_amount) * 100, 2)
            ELSE 0
          END AS reservation_rate,
          CASE
            WHEN ss.allocated_amount > 0 THEN
              ROUND((COALESCE(l.total_spent, 0) / ss.allocated_amount) * 100, 2)
            ELSE 0
          END AS spending_rate
        FROM section_scope ss
        LEFT JOIN ledger l ON l.section_id = ss.section_id
        CROSS JOIN effective_year ey
        WHERE (ey.id IS NULL OR ss.fiscal_year_id = ey.id)
          AND (@budget_type_id = '' OR ss.budget_type_id = @budget_type_id::uuid)
          AND (@program_id = '' OR ss.program_id = @program_id::uuid)
          AND (@section_id = '' OR ss.section_id = @section_id::uuid)
        ORDER BY ss.program_code, ss.section_path, ss.section_full_code
      '''),
      parameters: {
        'fiscal_year_id': fiscalYearId ?? '',
        'budget_type_id': budgetTypeId ?? '',
        'program_id': programId ?? '',
        'section_id': sectionId ?? '',
        'date_from': dateFrom ?? '',
        'date_to': dateTo ?? '',
      },
    );

    return result.map((row) {
      final map = row.toColumnMap();
      return {
        for (final entry in map.entries) entry.key: _normalize(entry.value),
      };
    }).toList();
  }

  Object? _normalize(Object? value) {
    if (value is num) return value.toDouble();
    return value;
  }
}
