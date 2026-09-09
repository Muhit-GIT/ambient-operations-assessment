/*
=============================================================
Part 1 - Data Profiling
Northwind Ambient Ops Assessment
Database: AmbientOps
File: 01_profile.sql
=============================================================

Purpose:
    Profile the supplied raw data BEFORE making reconciliation
    decisions or modifying any records.

This script is READ-ONLY.
It does not INSERT, UPDATE, DELETE, or alter the source data.

Key profiling areas:
    1. Table row counts
    2. Business-key uniqueness
    3. Duplicate records
    4. NULL values
    5. Basic data-quality checks
    6. Potential join/reconciliation risks
=============================================================
*/

USE AmbientOps;
GO

SET NOCOUNT ON;
GO


/* ============================================================
   1. TABLE ROW COUNTS
   ============================================================ */

SELECT
    'note' AS table_name,
    COUNT_BIG(*) AS row_count
FROM dbo.note

UNION ALL

SELECT
    'note_audit',
    COUNT_BIG(*)
FROM dbo.note_audit

UNION ALL

SELECT
    'clinician',
    COUNT_BIG(*)
FROM dbo.clinician

UNION ALL

SELECT
    'mds',
    COUNT_BIG(*)
FROM dbo.mds

UNION ALL

SELECT
    'sla_config',
    COUNT_BIG(*)
FROM dbo.sla_config

UNION ALL

SELECT
    'rubric_weight',
    COUNT_BIG(*)
FROM dbo.rubric_weight

UNION ALL

SELECT
    'escalation',
    COUNT_BIG(*)
FROM dbo.escalation;

GO


/* ============================================================
   2. NOTE TABLE - KEY PROFILE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_rows,
    COUNT(DISTINCT note_id) AS distinct_note_ids,
    COUNT_BIG(*) - COUNT(DISTINCT note_id) AS duplicate_note_id_rows
FROM dbo.note;

GO


/* ============================================================
   3. NOTE TABLE - DUPLICATE note_id VALUES
   ============================================================ */

SELECT
    note_id,
    COUNT(*) AS row_count
FROM dbo.note
GROUP BY note_id
HAVING COUNT(*) > 1
ORDER BY
    row_count DESC,
    note_id;

GO


/* ============================================================
   4. NOTE TABLE - NULL PROFILE
   ============================================================ */

SELECT
    SUM(CASE WHEN note_id IS NULL THEN 1 ELSE 0 END)
        AS null_note_id,

    SUM(CASE WHEN word_count IS NULL THEN 1 ELSE 0 END)
        AS null_word_count,

    SUM(CASE WHEN clinician_id IS NULL THEN 1 ELSE 0 END)
        AS null_clinician_id
FROM dbo.note;

GO


/* ============================================================
   5. NOTE TABLE - WORD COUNT PROFILE
   ============================================================ */

SELECT
    MIN(word_count) AS minimum_word_count,
    MAX(word_count) AS maximum_word_count,
    AVG(CAST(word_count AS decimal(18,2))) AS average_word_count,
    SUM(CASE WHEN word_count IS NULL THEN 1 ELSE 0 END)
        AS null_word_count_rows,
    SUM(CASE WHEN word_count = 0 THEN 1 ELSE 0 END)
        AS zero_word_count_rows,
    SUM(CASE WHEN word_count < 0 THEN 1 ELSE 0 END)
        AS negative_word_count_rows
FROM dbo.note;

GO


/* ============================================================
   6. CLINICIAN TABLE - KEY PROFILE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_rows,
    COUNT(DISTINCT clinician_id) AS distinct_clinician_ids,
    COUNT_BIG(*) - COUNT(DISTINCT clinician_id)
        AS duplicate_clinician_rows
FROM dbo.clinician;

GO


/* ============================================================
   7. CLINICIAN TABLE - DUPLICATE clinician_id VALUES
   ============================================================ */

SELECT
    clinician_id,
    COUNT(*) AS row_count
FROM dbo.clinician
GROUP BY clinician_id
HAVING COUNT(*) > 1
ORDER BY
    row_count DESC,
    clinician_id;

GO


/* ============================================================
   8. CLINICIAN TABLE - NULL PROFILE
   ============================================================ */

SELECT
    SUM(CASE WHEN clinician_id IS NULL THEN 1 ELSE 0 END)
        AS null_clinician_id
FROM dbo.clinician;

GO


/* ============================================================
   9. NOTE_AUDIT TABLE - BASIC PROFILE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_rows,
    COUNT(DISTINCT audit_id) AS distinct_audit_ids,
    COUNT_BIG(*) - COUNT(DISTINCT audit_id)
        AS duplicate_audit_id_rows
FROM dbo.note_audit;

GO


/* ============================================================
   10. NOTE_AUDIT TABLE - NULL PROFILE
   ============================================================ */

SELECT
    SUM(CASE WHEN audit_id IS NULL THEN 1 ELSE 0 END)
        AS null_audit_id,

    SUM(CASE WHEN note_id IS NULL THEN 1 ELSE 0 END)
        AS null_note_id,

    SUM(CASE WHEN [auditor_mds_id]  IS NULL THEN 1 ELSE 0 END)
        AS null_auditor_mds_id
FROM dbo.note_audit;

GO


/* ============================================================
   11. ESCALATION TABLE - BASIC PROFILE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_rows,
    COUNT(DISTINCT escalation_id) AS distinct_escalation_ids,
    COUNT_BIG(*) - COUNT(DISTINCT escalation_id)
        AS duplicate_escalation_id_rows
FROM dbo.escalation;

GO


/* ============================================================
   12. ESCALATION TABLE - NULL PROFILE
   ============================================================ */

SELECT
    SUM(CASE WHEN escalation_id IS NULL THEN 1 ELSE 0 END)
        AS null_escalation_id,

    SUM(CASE WHEN note_id IS NULL THEN 1 ELSE 0 END)
        AS null_note_id
FROM dbo.escalation;

GO


/* ============================================================
   13. MDS TABLE - BASIC PROFILE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_rows
FROM dbo.mds;

GO


/* ============================================================
   14. SLA CONFIGURATION - BASIC PROFILE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_rows
FROM dbo.sla_config;

GO


/* ============================================================
   15. RUBRIC WEIGHT - BASIC PROFILE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS total_rows
FROM dbo.rubric_weight;

GO


/* ============================================================
   16. CHECK NOTE -> AUDIT JOIN MULTIPLICATION
   ------------------------------------------------------------
   Purpose:
       Identify note IDs that produce multiple joined rows.

   This is important because duplicate note_id values in the
   raw note table can multiply audit records during joins.
   ============================================================ */

SELECT
    a.note_id,
    COUNT(*) AS joined_row_count
FROM dbo.note_audit AS a
INNER JOIN dbo.note AS n
    ON n.note_id = a.note_id
GROUP BY
    a.note_id
HAVING COUNT(*) > 1
ORDER BY
    joined_row_count DESC,
    a.note_id;

GO


/* ============================================================
   17. CHECK FOR AUDITS WITHOUT A MATCHING NOTE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS audits_without_matching_note
FROM dbo.note_audit AS a
LEFT JOIN dbo.note AS n
    ON n.note_id = a.note_id
WHERE n.note_id IS NULL;

GO


/* ============================================================
   18. CHECK FOR ESCALATIONS WITHOUT A MATCHING NOTE
   ============================================================ */

SELECT
    COUNT_BIG(*) AS escalations_without_matching_note
FROM dbo.escalation AS e
LEFT JOIN dbo.note AS n
    ON n.note_id = e.note_id
WHERE n.note_id IS NULL;

GO


/* ============================================================
   19. CHECK NOTE -> CLINICIAN JOIN MULTIPLICATION
   ============================================================ */

SELECT
    n.clinician_id,
    COUNT(*) AS joined_row_count
FROM dbo.note AS n
INNER JOIN dbo.clinician AS c
    ON c.clinician_id = n.clinician_id
GROUP BY
    n.clinician_id
HAVING COUNT(*) > 1
ORDER BY
    joined_row_count DESC,
    n.clinician_id;

GO


/* ============================================================
   20. CHECK FOR NOTES WITHOUT A MATCHING CLINICIAN
   ============================================================ */

SELECT
    COUNT_BIG(*) AS notes_without_matching_clinician
FROM dbo.note AS n
LEFT JOIN dbo.clinician AS c
    ON c.clinician_id = n.clinician_id
WHERE c.clinician_id IS NULL;

GO


/* ============================================================
   21. OVERALL PROFILE SUMMARY
   ------------------------------------------------------------
   These values are the important findings to document in
   RECONCILIATION.md.
   ============================================================ */

SELECT
    'note' AS table_name,
    COUNT_BIG(*) AS total_rows,
    COUNT(DISTINCT note_id) AS distinct_business_keys,
    COUNT_BIG(*) - COUNT(DISTINCT note_id)
        AS duplicate_rows
FROM dbo.note

UNION ALL

SELECT
    'clinician',
    COUNT_BIG(*),
    COUNT(DISTINCT clinician_id),
    COUNT_BIG(*) - COUNT(DISTINCT clinician_id)
FROM dbo.clinician

UNION ALL

SELECT
    'note_audit',
    COUNT_BIG(*),
    COUNT(DISTINCT audit_id),
    COUNT_BIG(*) - COUNT(DISTINCT audit_id)
FROM dbo.note_audit

UNION ALL

SELECT
    'escalation',
    COUNT_BIG(*),
    COUNT(DISTINCT escalation_id),
    COUNT_BIG(*) - COUNT(DISTINCT escalation_id)
FROM dbo.escalation;

GO


/* ============================================================
   EXPECTED PROFILE FINDINGS
   ------------------------------------------------------------

   Based on the assessment data already profiled:

       note
       -------------------------
       Total rows:             6,235
       Distinct note_id:       6,173
       Duplicate note_id:         62
       NULL word_count:          152

       clinician
       -------------------------
       Total rows:                64
       Distinct clinician_id:     60
       Duplicate clinician rows:  4

       note_audit
       -------------------------
       Total rows:             1,780

       escalation
       -------------------------
       Total rows:               533

   Important data-judgment implications:

   1. note_id cannot automatically be assumed to be unique.

   2. clinician_id cannot automatically be assumed to be unique.

   3. Direct joins against these tables can multiply rows.

   4. NULL word_count values must not automatically be treated
      as zero unless the business rule explicitly says so.

   5. The raw data should not be physically modified merely
      to make reporting totals reconcile.

   6. Reporting grain and de-duplication rules should be
      explicitly documented in RECONCILIATION.md.

   7. The supplied tables do not rely on database-enforced
      PK/FK constraints, so business-key uniqueness must be
      validated by profiling.

=============================================================
END OF 01_profile.sql
=============================================================
*/
