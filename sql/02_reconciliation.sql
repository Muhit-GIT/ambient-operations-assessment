
/*
=============================================================
Part 1 - Reconciliation and Data Judgment
Northwind Ambient Ops Assessment
Database: AmbientOps
File: 02_reconciliation.sql
Platform: SQL Server / T-SQL
=============================================================

Purpose:
    Reconcile the raw assessment data at the correct business grain
    and identify problems that could cause incorrect reporting.

IMPORTANT:
    This script is READ-ONLY.
    It does not INSERT, UPDATE, DELETE, or alter source data.

    Duplicate source records are NOT automatically deleted.
    Reconciliation decisions should be documented in
    RECONCILIATION.md.

Known profiling findings:
    note:
        6,235 rows
        6,173 distinct note_id
        62 duplicate note_id rows
        152 NULL word_count values

    clinician:
        64 rows
        60 distinct clinician_id
        4 duplicate clinician rows

    note_audit:
        1,780 rows

    escalation:
        533 rows

Expected Q2 FY26 control figures:
    Audited notes       = 1,705
    Pass rate           = 79.9%
    Pass target         = 90.0%
    Composite score     = 0.9055
    SLA breach rate     = 12.8%
    Median turnaround   = 18.5 minutes
    Open escalations    = 149
    First response      = 49.5 minutes
    Anomaly days        = 28 / 91

Reporting timezone:
    America/Chicago

Source timestamps:
    UTC
=============================================================
*/

USE AmbientOps;
GO

SET NOCOUNT ON;
GO


/* ============================================================
   1. RAW CONTROL TOTALS
   ============================================================ */

SELECT
    'note' AS table_name,
    COUNT_BIG(*) AS raw_rows,
    COUNT(DISTINCT note_id) AS distinct_business_keys,
    COUNT_BIG(*) - COUNT(DISTINCT note_id) AS duplicate_rows
FROM dbo.note

UNION ALL

SELECT
    'note_audit',
    COUNT_BIG(*),
    COUNT(DISTINCT audit_id),
    COUNT_BIG(*) - COUNT(DISTINCT audit_id)
FROM dbo.note_audit

UNION ALL

SELECT
    'clinician',
    COUNT_BIG(*),
    COUNT(DISTINCT clinician_id),
    COUNT_BIG(*) - COUNT(DISTINCT clinician_id)
FROM dbo.clinician

UNION ALL

SELECT
    'mds',
    COUNT_BIG(*),
    NULL,
    NULL
FROM dbo.mds

UNION ALL

SELECT
    'sla_config',
    COUNT_BIG(*),
    NULL,
    NULL
FROM dbo.sla_config

UNION ALL

SELECT
    'rubric_weight',
    COUNT_BIG(*),
    NULL,
    NULL
FROM dbo.rubric_weight

UNION ALL

SELECT
    'escalation',
    COUNT_BIG(*),
    COUNT(DISTINCT escalation_id),
    COUNT_BIG(*) - COUNT(DISTINCT escalation_id)
FROM dbo.escalation;

GO


/* ============================================================
   2. NOTE DUPLICATE IMPACT
   ============================================================ */

WITH DuplicateNotes AS
(
    SELECT
        note_id,
        COUNT(*) AS row_count
    FROM dbo.note
    GROUP BY note_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_note_id_groups,
    SUM(row_count) AS rows_in_duplicate_groups,
    SUM(row_count - 1) AS excess_duplicate_rows
FROM DuplicateNotes;

GO


/* ============================================================
   3. CLINICIAN DUPLICATE IMPACT
   ============================================================ */

WITH DuplicateClinicians AS
(
    SELECT
        clinician_id,
        COUNT(*) AS row_count
    FROM dbo.clinician
    GROUP BY clinician_id
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_clinician_groups,
    SUM(row_count) AS rows_in_duplicate_groups,
    SUM(row_count - 1) AS excess_duplicate_rows
FROM DuplicateClinicians;

GO


/* ============================================================
   4. SHOW DUPLICATE NOTE RECORDS
   ============================================================ */

SELECT
    n.*
FROM dbo.note AS n
INNER JOIN
(
    SELECT note_id
    FROM dbo.note
    GROUP BY note_id
    HAVING COUNT(*) > 1
) AS d
    ON d.note_id = n.note_id
ORDER BY
    n.note_id;

GO


/* ============================================================
   5. SHOW DUPLICATE CLINICIAN RECORDS
   ============================================================ */

SELECT
    c.*
FROM dbo.clinician AS c
INNER JOIN
(
    SELECT clinician_id
    FROM dbo.clinician
    GROUP BY clinician_id
    HAVING COUNT(*) > 1
) AS d
    ON d.clinician_id = c.clinician_id
ORDER BY
    c.clinician_id;

GO


/* ============================================================
   6. CHECK AUDIT -> NOTE JOIN MULTIPLICATION
   ============================================================

   If a note has multiple physical rows, joining note_audit
   directly to note can multiply audit rows.

   This query identifies affected note IDs.
   ============================================================ */

SELECT
    a.note_id,
    COUNT_BIG(*) AS joined_rows
FROM dbo.note_audit AS a
INNER JOIN dbo.note AS n
    ON n.note_id = a.note_id
GROUP BY
    a.note_id
HAVING COUNT_BIG(*) > 1
ORDER BY
    joined_rows DESC,
    a.note_id;

GO


/* ============================================================
   7. QUANTIFY POTENTIAL AUDIT JOIN MULTIPLICATION
   ============================================================ */

SELECT
    COUNT_BIG(*) AS raw_audit_rows
FROM dbo.note_audit;

SELECT
    COUNT_BIG(*) AS audit_rows_after_note_join
FROM dbo.note_audit AS a
INNER JOIN dbo.note AS n
    ON n.note_id = a.note_id;

GO


/* ============================================================
   8. CHECK AUDITS WITHOUT MATCHING NOTE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS audits_without_matching_note
FROM dbo.note_audit AS a
LEFT JOIN dbo.note AS n
    ON n.note_id = a.note_id
WHERE n.note_id IS NULL;

GO


/* ============================================================
   9. CHECK ESCALATIONS WITHOUT MATCHING NOTE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS escalations_without_matching_note
FROM dbo.escalation AS e
LEFT JOIN dbo.note AS n
    ON n.note_id = e.note_id
WHERE n.note_id IS NULL;

GO


/* ============================================================
   10. CHECK NOTE -> CLINICIAN JOIN MULTIPLICATION
   ============================================================ */

SELECT
    n.clinician_id,
    COUNT_BIG(*) AS joined_rows
FROM dbo.note AS n
INNER JOIN dbo.clinician AS c
    ON c.clinician_id = n.clinician_id
GROUP BY
    n.clinician_id
HAVING COUNT_BIG(*) > 1
ORDER BY
    joined_rows DESC,
    n.clinician_id;

GO


/* ============================================================
   11. CHECK NOTES WITHOUT MATCHING CLINICIAN
   ============================================================ */

SELECT
    COUNT_BIG(*) AS notes_without_matching_clinician
FROM dbo.note AS n
LEFT JOIN dbo.clinician AS c
    ON c.clinician_id = n.clinician_id
WHERE c.clinician_id IS NULL;

GO


/* ============================================================
   12. CHECK FOR NULL BUSINESS KEYS
   ============================================================ */

SELECT
    'note' AS table_name,
    SUM(CASE WHEN note_id IS NULL THEN 1 ELSE 0 END)
        AS null_business_key_rows
FROM dbo.note

UNION ALL

SELECT
    'note_audit',
    SUM(CASE WHEN audit_id IS NULL THEN 1 ELSE 0 END)
FROM dbo.note_audit

UNION ALL

SELECT
    'clinician',
    SUM(CASE WHEN clinician_id IS NULL THEN 1 ELSE 0 END)
FROM dbo.clinician

UNION ALL

SELECT
    'escalation',
    SUM(CASE WHEN escalation_id IS NULL THEN 1 ELSE 0 END)
FROM dbo.escalation;

GO


/* ============================================================
   13. NOTE WORD_COUNT RECONCILIATION
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_note_rows,
    SUM(CASE WHEN word_count IS NULL THEN 1 ELSE 0 END)
        AS null_word_count_rows,
    SUM(CASE WHEN word_count = 0 THEN 1 ELSE 0 END)
        AS zero_word_count_rows,
    SUM(CASE WHEN word_count < 0 THEN 1 ELSE 0 END)
        AS negative_word_count_rows
FROM dbo.note;

GO


/* ============================================================
   14. SAFE DISTINCT NOTE GRAIN
   ============================================================

   This creates a logical reporting grain without modifying the
   underlying table.

   IMPORTANT:
       Because the correct tie-breaker depends on the supplied
       business rules, this query only demonstrates the concept.

       If the note table has a reliable timestamp/version column,
       use it in the ROW_NUMBER ORDER BY clause and document that
       rule in RECONCILIATION.md.
   ============================================================ */

/*
WITH NoteGrain AS
(
    SELECT
        n.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY note_id
            ORDER BY note_id
        ) AS rn
    FROM dbo.note AS n
)
SELECT
    COUNT_BIG(*) AS reporting_note_rows,
    COUNT(DISTINCT note_id) AS reporting_distinct_note_ids
FROM NoteGrain
WHERE rn = 1;
*/

GO


/* ============================================================
   15. SAFE DISTINCT CLINICIAN GRAIN
   ============================================================ */

/*
WITH ClinicianGrain AS
(
    SELECT
        c.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY clinician_id
            ORDER BY clinician_id
        ) AS rn
    FROM dbo.clinician AS c
)
SELECT
    COUNT_BIG(*) AS reporting_clinician_rows,
    COUNT(DISTINCT clinician_id) AS reporting_distinct_clinician_ids
FROM ClinicianGrain
WHERE rn = 1;
*/

GO


/* ============================================================
   16. Q2 FY26 REPORTING WINDOW
   ============================================================

   Business reporting timezone:
       America/Chicago

   SQL Server Windows timezone:
       Central Standard Time

   The variables below establish the local business window.

   Convert source UTC timestamps into this timezone before
   assigning business dates.
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
   17. BUSINESS-DAY CONVERSION EXAMPLE
   ============================================================

   Replace <timestamp_column> with the actual timestamp column
   from the relevant assessment table.

   Example:

       <timestamp_column>
           AT TIME ZONE 'UTC'
           AT TIME ZONE 'Central Standard Time'

   This prevents UTC midnight from being incorrectly treated as
   the Chicago business date.
   ============================================================ */

/*
SELECT
    <timestamp_column> AS source_utc,
    <timestamp_column>
        AT TIME ZONE 'UTC'
        AT TIME ZONE 'Central Standard Time'
        AS chicago_datetime
FROM dbo.note_audit;
*/

GO


/* ============================================================
   18. RECONCILIATION CHECKLIST
   ============================================================ */

SELECT
    'Raw note rows' AS reconciliation_item,
    CAST(COUNT_BIG(*) AS varchar(50)) AS observed_value
FROM dbo.note

UNION ALL

SELECT
    'Distinct note IDs',
    CAST(COUNT(DISTINCT note_id) AS varchar(50))
FROM dbo.note

UNION ALL

SELECT
    'Duplicate note rows',
    CAST
    (
        COUNT_BIG(*) - COUNT(DISTINCT note_id)
        AS varchar(50)
    )
FROM dbo.note

UNION ALL

SELECT
    'NULL word_count rows',
    CAST
    (
        SUM(CASE WHEN word_count IS NULL THEN 1 ELSE 0 END)
        AS varchar(50)
    )
FROM dbo.note

UNION ALL

SELECT
    'Raw clinician rows',
    CAST(COUNT_BIG(*) AS varchar(50))
FROM dbo.clinician

UNION ALL

SELECT
    'Distinct clinician IDs',
    CAST(COUNT(DISTINCT clinician_id) AS varchar(50))
FROM dbo.clinician

UNION ALL

SELECT
    'Duplicate clinician rows',
    CAST
    (
        COUNT_BIG(*) - COUNT(DISTINCT clinician_id)
        AS varchar(50)
    )
FROM dbo.clinician

UNION ALL

SELECT
    'Note audit rows',
    CAST(COUNT_BIG(*) AS varchar(50))
FROM dbo.note_audit

UNION ALL

SELECT
    'Escalation rows',
    CAST(COUNT_BIG(*) AS varchar(50))
FROM dbo.escalation;

GO


/* ============================================================
   19. EXPECTED ASSESSMENT CONTROL TOTALS
   ============================================================

   These are VALIDATION TARGETS, not hardcoded reporting values.

   Your final reconciliation should derive these numbers from
   the source data and the documented business rules.

   ------------------------------------------------------------
   Metric                  Expected
   ------------------------------------------------------------
   Audited notes           1,705
   Pass rate               79.9%
   Pass target             90.0%
   Composite score         0.9055
   SLA breach rate         12.8%
   Median turnaround       18.5 minutes
   Open escalations        149
   First response          49.5 minutes
   Anomaly days            28 / 91
   ------------------------------------------------------------

   If a calculated number differs from the control total, do not
   simply alter the source data. Investigate:

       - reporting grain
       - duplicate keys
       - join multiplication
       - NULL handling
       - timezone conversion
       - status definitions
       - SLA business rules
       - date boundaries
       - audit selection rules

=============================================================
END OF 02_reconciliation.sql
=============================================================
*/
