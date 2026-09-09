
/*
=============================================================
Part 1 - Business Metrics
Northwind Ambient Ops Assessment
Database: AmbientOps
File: 03_metrics.sql
Platform: SQL Server / T-SQL
=============================================================

Purpose:
    Calculate and validate the key Q2 FY26 business metrics.

Reporting timezone:
    America/Chicago

Source timestamps:
    UTC

Expected assessment control figures:

    Audited notes       = 1,705
    Pass rate           = 79.9%
    Pass target         = 90.0%
    Composite score     = 0.9055
    SLA breach rate     = 12.8%
    Median turnaround   = 18.5 minutes
    Open escalations    = 149
    First response      = 49.5 minutes
    Anomaly days        = 28 / 91

IMPORTANT:
    Do not hardcode the expected figures into application logic.
    They are included below only as reconciliation targets.

    Always calculate metrics from the source data and the
    documented business rules in RECONCILIATION.md.
=============================================================
*/

USE AmbientOps;
GO

SET NOCOUNT ON;
GO


/* ============================================================
   1. DEFINE Q2 FY26 REPORTING WINDOW
   ============================================================

   Q2 FY26:
       2025-10-01 through 2025-12-31

   Business timezone:
       America/Chicago

   SQL Server Windows timezone:
       Central Standard Time
   ============================================================ */

DECLARE @Q2StartChicago datetime2 =
    '2025-10-01T00:00:00';

DECLARE @Q3StartChicago datetime2 =
    '2026-01-01T00:00:00';


DECLARE @Q2StartUtc datetime2 =
    CONVERT
    (
        datetime2,
        @Q2StartChicago
            AT TIME ZONE 'Central Standard Time'
            AT TIME ZONE 'UTC'
    );


DECLARE @Q3StartUtc datetime2 =
    CONVERT
    (
        datetime2,
        @Q3StartChicago
            AT TIME ZONE 'Central Standard Time'
            AT TIME ZONE 'UTC'
    );


SELECT
    @Q2StartChicago AS q2_start_chicago,
    @Q3StartChicago AS q3_start_chicago,
    @Q2StartUtc AS q2_start_utc,
    @Q3StartUtc AS q3_start_utc;

GO


/* ============================================================
   2. AUDITED NOTES
   ============================================================

   Expected assessment result:
       1,705

   IMPORTANT:
       Replace <audit_timestamp_column> with the actual timestamp
       column in note_audit.
   ============================================================ */

/*
DECLARE @Q2StartUtc datetime2 =
    CONVERT
    (
        datetime2,
        '2025-10-01T00:00:00'
            AT TIME ZONE 'Central Standard Time'
            AT TIME ZONE 'UTC'
    );

DECLARE @Q3StartUtc datetime2 =
    CONVERT
    (
        datetime2,
        '2026-01-01T00:00:00'
            AT TIME ZONE 'Central Standard Time'
            AT TIME ZONE 'UTC'
    );

SELECT
    COUNT(DISTINCT note_id) AS audited_notes
FROM dbo.note_audit
WHERE <audit_timestamp_column> >= @Q2StartUtc
  AND <audit_timestamp_column> <  @Q3StartUtc;
*/

GO


/* ============================================================
   3. AUDIT ROW COUNT
   ============================================================

   This is useful for comparing:
       physical audit rows
       distinct audited notes

   The distinction is important because the reporting grain
   must be established before calculating percentages.
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_note_audit_rows,
    COUNT(DISTINCT note_id) AS distinct_audited_notes
FROM dbo.note_audit;

GO


/* ============================================================
   4. PASS RATE
   ============================================================

   Expected:
       79.9%

   Target:
       90.0%

   Replace:
       <audit_timestamp_column>
       <pass_column>

   Example pass column might be a bit/boolean field, but use
   the actual supplied schema and business rule.
   ============================================================ */

/*
SELECT
    COUNT_BIG(*) AS audited_rows,

    SUM
    (
        CASE
            WHEN <pass_column> = 1
            THEN 1
            ELSE 0
        END
    ) AS passed_rows,

    SUM
    (
        CASE
            WHEN <pass_column> <> 1
            THEN 1
            ELSE 0
        END
    ) AS failed_rows,

    CAST
    (
        100.0 *
        SUM
        (
            CASE
                WHEN <pass_column> = 1
                THEN 1
                ELSE 0
            END
        )
        / NULLIF(COUNT_BIG(*), 0)
        AS decimal(10,2)
    ) AS pass_rate_pct

FROM dbo.note_audit

WHERE <audit_timestamp_column> >= @Q2StartUtc
  AND <audit_timestamp_column> <  @Q3StartUtc;
*/

GO


/* ============================================================
   5. PASS RATE VS TARGET
   ============================================================ */

/*
DECLARE @PassTarget decimal(10,4) = 90.0;

SELECT
    calculated_pass_rate,
    @PassTarget AS target_pass_rate,
    calculated_pass_rate - @PassTarget AS variance_to_target
FROM
(
    SELECT
        CAST
        (
            100.0 *
            SUM
            (
                CASE
                    WHEN <pass_column> = 1
                    THEN 1
                    ELSE 0
                END
            )
            / NULLIF(COUNT_BIG(*), 0)
            AS decimal(10,2)
        ) AS calculated_pass_rate

    FROM dbo.note_audit

    WHERE <audit_timestamp_column> >= @Q2StartUtc
      AND <audit_timestamp_column> <  @Q3StartUtc
) AS x;
*/

GO


/* ============================================================
   6. COMPOSITE SCORE
   ============================================================

   Expected:
       0.9055

   The composite score should be calculated using the rubric
   weights supplied in dbo.rubric_weight.

   Do NOT calculate a simple average if the business rule
   requires weighted scoring.

   Replace the following placeholders with the actual columns:

       <rubric_key>
       <audit_score>
       <weight>

   The exact join must follow the grain documented in
   RECONCILIATION.md.
   ============================================================ */

/*
SELECT
    CAST
    (
        SUM
        (
            CAST(a.<audit_score> AS decimal(18,8))
            *
            CAST(r.<weight> AS decimal(18,8))
        )
        /
        NULLIF
        (
            SUM(CAST(r.<weight> AS decimal(18,8))),
            0
        )
        AS decimal(10,4)
    ) AS composite_score

FROM dbo.note_audit AS a

INNER JOIN dbo.rubric_weight AS r
    ON r.<rubric_key> = a.<rubric_key>

WHERE a.<audit_timestamp_column> >= @Q2StartUtc
  AND a.<audit_timestamp_column> <  @Q3StartUtc;
*/

GO


/* ============================================================
   7. SLA BREACH RATE
   ============================================================

   Expected:
       12.8%

   The SLA rule should come from sla_config.

   Do not hardcode an SLA threshold if the assessment data
   provides the configuration.

   Replace:
       <audit_timestamp_column>
       <sla_condition>
   ============================================================ */

/*
SELECT
    COUNT_BIG(*) AS total_sla_records,

    SUM
    (
        CASE
            WHEN <sla_condition>
            THEN 1
            ELSE 0
        END
    ) AS breached_records,

    CAST
    (
        100.0 *
        SUM
        (
            CASE
                WHEN <sla_condition>
                THEN 1
                ELSE 0
            END
        )
        /
        NULLIF(COUNT_BIG(*), 0)
        AS decimal(10,2)
    ) AS sla_breach_rate_pct

FROM dbo.note_audit

WHERE <audit_timestamp_column> >= @Q2StartUtc
  AND <audit_timestamp_column> <  @Q3StartUtc;
*/

GO


/* ============================================================
   8. TURNAROUND TIME
   ============================================================

   Calculate turnaround in minutes.

   Expected median:
       18.5 minutes

   Replace:
       <start_timestamp_column>
       <end_timestamp_column>

   DATEDIFF_BIG(SECOND) is used before dividing by 60 to avoid
   losing fractional minutes.
   ============================================================ */

/*
SELECT
    audit_id,
    note_id,

    DATEDIFF_BIG
    (
        SECOND,
        <start_timestamp_column>,
        <end_timestamp_column>
    ) / 60.0 AS turnaround_minutes

FROM dbo.note_audit

WHERE <audit_timestamp_column> >= @Q2StartUtc
  AND <audit_timestamp_column> <  @Q3StartUtc;
*/

GO


/* ============================================================
   9. MEDIAN TURNAROUND
   ============================================================

   Expected:
       18.5 minutes
   ============================================================ */

/*
SELECT DISTINCT

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY
            DATEDIFF_BIG
            (
                SECOND,
                <start_timestamp_column>,
                <end_timestamp_column>
            ) / 60.0
    ) OVER () AS median_turnaround_minutes

FROM dbo.note_audit

WHERE <audit_timestamp_column> >= @Q2StartUtc
  AND <audit_timestamp_column> <  @Q3StartUtc

  AND <start_timestamp_column> IS NOT NULL
  AND <end_timestamp_column> IS NOT NULL;
*/

GO


/* ============================================================
   10. OPEN ESCALATIONS
   ============================================================

   Expected:
       149

   Replace:
       <status_column>

   Use the exact status values from the supplied data.
   ============================================================ */

/*
SELECT
    COUNT(DISTINCT escalation_id) AS open_escalations
FROM dbo.escalation
WHERE LOWER(<status_column>) = 'open';
*/

GO


/* ============================================================
   11. ESCALATION STATUS DISTRIBUTION
   ============================================================

   This should be run before finalising the open-escalation
   business rule.
   ============================================================ */

/*
SELECT
    <status_column> AS escalation_status,
    COUNT_BIG(*) AS row_count
FROM dbo.escalation
GROUP BY
    <status_column>
ORDER BY
    row_count DESC;
*/

GO


/* ============================================================
   12. FIRST RESPONSE TIME
   ============================================================

   Expected:
       49.5 minutes

   Replace:
       <created_timestamp_column>
       <first_response_timestamp_column>

   The assessment's documented business rule should determine
   exactly which response qualifies as the first response.
   ============================================================ */

/*
SELECT
    escalation_id,
    note_id,

    DATEDIFF_BIG
    (
        SECOND,
        <created_timestamp_column>,
        <first_response_timestamp_column>
    ) / 60.0 AS first_response_minutes

FROM dbo.escalation

WHERE <created_timestamp_column> >= @Q2StartUtc
  AND <created_timestamp_column> <  @Q3StartUtc

  AND <first_response_timestamp_column> IS NOT NULL;
*/

GO


/* ============================================================
   13. MEDIAN FIRST RESPONSE
   ============================================================

   Expected:
       49.5 minutes
   ============================================================ */

/*
SELECT DISTINCT

    PERCENTILE_CONT(0.5)
    WITHIN GROUP
    (
        ORDER BY
            DATEDIFF_BIG
            (
                SECOND,
                <created_timestamp_column>,
                <first_response_timestamp_column>
            ) / 60.0
    ) OVER () AS median_first_response_minutes

FROM dbo.escalation

WHERE <created_timestamp_column> >= @Q2StartUtc
  AND <created_timestamp_column> <  @Q3StartUtc

  AND <first_response_timestamp_column> IS NOT NULL;
*/

GO


/* ============================================================
   14. DAILY AUDIT COUNTS
   ============================================================

   This is useful for the anomaly-day analysis.

   IMPORTANT:
       Convert UTC timestamps to America/Chicago BEFORE extracting
       the business date.

   Replace:
       <audit_timestamp_column>
   ============================================================ */

/*
SELECT
    CAST
    (
        <audit_timestamp_column>
            AT TIME ZONE 'UTC'
            AT TIME ZONE 'Central Standard Time'
        AS date
    ) AS business_date,

    COUNT_BIG(*) AS audit_count

FROM dbo.note_audit

WHERE <audit_timestamp_column> >= @Q2StartUtc
  AND <audit_timestamp_column> <  @Q3StartUtc

GROUP BY
    CAST
    (
        <audit_timestamp_column>
            AT TIME ZONE 'UTC'
            AT TIME ZONE 'Central Standard Time'
        AS date
    )

ORDER BY
    business_date;
*/

GO


/* ============================================================
   15. ANOMALY DAYS
   ============================================================

   Expected:
       28 of 91 days

   The anomaly rule must be the rule justified in
   RECONCILIATION.md.

   Examples of possible rules include:
       - unusually high daily volume
       - unusually low daily volume
       - SLA breach threshold
       - statistical deviation

   Do NOT invent a rule solely to produce 28 days.
   ============================================================ */

/*
WITH DailyMetrics AS
(
    SELECT

        CAST
        (
            <audit_timestamp_column>
                AT TIME ZONE 'UTC'
                AT TIME ZONE 'Central Standard Time'
            AS date
        ) AS business_date,

        COUNT_BIG(*) AS daily_audits

    FROM dbo.note_audit

    WHERE <audit_timestamp_column> >= @Q2StartUtc
      AND <audit_timestamp_column> <  @Q3StartUtc

    GROUP BY

        CAST
        (
            <audit_timestamp_column>
                AT TIME ZONE 'UTC'
                AT TIME ZONE 'Central Standard Time'
            AS date
        )
)

SELECT
    COUNT(*) AS anomaly_days

FROM DailyMetrics

WHERE <documented_anomaly_condition>;
*/

GO


/* ============================================================
   16. Q2 FY26 METRIC CONTROL TABLE
   ============================================================

   This produces the expected control values as a reference
   only. These are NOT calculated values.
   ============================================================ */

SELECT
    'Audited notes' AS metric,
    '1705' AS expected_value

UNION ALL

SELECT
    'Pass rate',
    '79.9%'

UNION ALL

SELECT
    'Pass target',
    '90.0%'

UNION ALL

SELECT
    'Composite score',
    '0.9055'

UNION ALL

SELECT
    'SLA breach rate',
    '12.8%'

UNION ALL

SELECT
    'Median turnaround',
    '18.5 minutes'

UNION ALL

SELECT
    'Open escalations',
    '149'

UNION ALL

SELECT
    'First response',
    '49.5 minutes'

UNION ALL

SELECT
    'Anomaly days',
    '28 / 91';

GO


/* ============================================================
   17. DATA QUALITY CHECKS BEFORE FINAL METRICS
   ============================================================ */

/* Duplicate note IDs */

SELECT
    COUNT(*) AS duplicate_note_id_groups
FROM
(
    SELECT
        note_id
    FROM dbo.note
    GROUP BY
        note_id
    HAVING COUNT(*) > 1
) AS d;

GO


/* Duplicate clinician IDs */

SELECT
    COUNT(*) AS duplicate_clinician_id_groups
FROM
(
    SELECT
        clinician_id
    FROM dbo.clinician
    GROUP BY
        clinician_id
    HAVING COUNT(*) > 1
) AS d;

GO


/* NULL word_count */

SELECT
    COUNT_BIG(*) AS null_word_count_rows
FROM dbo.note
WHERE word_count IS NULL;

GO


/* ============================================================
   18. FINAL RECONCILIATION PRINCIPLES
   ============================================================

   Before accepting the final metrics, confirm:

       [ ] Raw data was profiled first.
       [ ] Reporting grain is documented.
       [ ] Duplicate note_id values were identified.
       [ ] Duplicate clinician_id values were identified.
       [ ] NULL word_count values were identified.
       [ ] Joins do not multiply audit records.
       [ ] UTC timestamps are converted to America/Chicago.
       [ ] Q2 date boundaries are correct.
       [ ] Pass/fail definition is documented.
       [ ] Composite-score weighting is documented.
       [ ] SLA definition is documented.
       [ ] Turnaround calculation is documented.
       [ ] Open-escalation definition is documented.
       [ ] First-response definition is documented.
       [ ] Anomaly-day rule is documented.
       [ ] Source data was not modified merely to reconcile totals.

=============================================================
END OF 03_metrics.sql
=============================================================
*/
