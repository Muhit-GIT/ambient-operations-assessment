Part 1 — Reconciliation and Data Judgment
1. Purpose
This document reconciles the supplied operational reporting queries against the SQL Server database and documents the underlying data grain, key uniqueness, data-quality issues, and semantic problems found during profiling.
The approach was:
1.	Profile the tables before changing any reporting query.
2.	Determine the actual grain and uniqueness of important keys.
3.	Check referential integrity and nullability.
4.	Execute the supplied reporting logic against SQL Server.
5.	Compare the resulting metrics with the reported operational figures.
6.	Identify the root cause of each discrepancy.
7.	Recommend the correct analytical grain and join logic.
8.	Avoid silently “fixing” the data without first establishing what the data actually represents.
All date-range testing used the SQL Server half-open interval:
submitted_at_utc >= '2026-04-01'
AND submitted_at_utc < '2026-07-01'
This represents the complete period from 1 April through 30 June 2026.
________________________________________
2. Table Profiling
2.1 Table inventory and apparent grain
Table	Apparent grain	Important key	Observed uniqueness
dbo.clinician	One clinician version/effective-dated record	clinician_id + record_effective_from	Unique
dbo.mds	One MDS/person	mds_id	Unique
dbo.note	One ingested/versioned note record	note_id + ingestion_id	Unique
dbo.note_audit	One audit event	audit_id	Unique
dbo.escalation	One escalation event	escalation_id	Unique
dbo.rubric_weight	One rubric dimension/version/effective record	rubric_version + dimension	Unique
dbo.sla_config	One SLA configuration record	config_id	Unique
The most important discovery is that several identifiers that look like natural primary keys are not actually unique at the physical table level.
________________________________________
3. Actual Key Uniqueness
3.1 Key profiling
Table	Rows	Distinct key values	Duplicate excess
clinician by clinician_id	64	60	4
mds by mds_id	34	34	0
note by note_id	6,235	6,173	62
note_audit by audit_id	1,780	1,780	0
escalation by escalation_id	533	533	0
rubric_weight by rubric_version + dimension	14	14	0
sla_config by config_id	8	8	0
Therefore:
•	clinician_id is not a unique physical key.
•	note_id is not a unique physical key.
•	mds_id, audit_id, escalation_id, and config_id are unique.
•	note_id + ingestion_id is unique across all 6,235 note rows.
The note table therefore appears to contain multiple ingestion/version records for the same logical note.
________________________________________
4. Clinician Grain and Versioning
The four duplicated clinician IDs are:
•	CL-1004
•	CL-1018
•	CL-1029
•	CL-1045
These are not simple duplicate records. They represent effective-dated versions.
For example:
•	CL-1004 has a historical record through 2024-12-31 and a current record beginning 2025-01-01.
•	Its region changes from SOUTH to WEST.
•	CL-1018 changes from WEST to NORTHEAST.
•	CL-1029 retains the same region.
•	CL-1045 changes from NORTHEAST to MIDWEST.
Additional profiling established:
•	clinician_id + record_effective_from is unique.
•	Current-record rows are unique.
•	Effective periods do not overlap.
Interpretation
clinician_id identifies a clinician, but not a unique physical row.
Any reporting query that joins:
note.clinician_id = clinician.clinician_id
without considering the effective dates is potentially under-specified.
The appropriate clinician version should be selected based on the business-effective date of the note.
________________________________________
5. Note Grain and Duplicate note_id
The note table contains:
•	6,235 physical rows
•	6,173 distinct note_id values
•	62 duplicate excess rows
Every duplicated logical note ID has different ingestion IDs.
The observed pattern is consistent with multiple ingestion/version records rather than accidental byte-for-byte duplicates.
The strongest evidence is that:
note_id + ingestion_id
is unique across all 6,235 rows.
Therefore, note_id should not be treated as a physical primary key.
Example
The duplicated note IDs generally have ingestion IDs such as:
IG-xxxxxx-1
IG-xxxxxx-2
while other attributes such as encounter, clinician, MDS, product line, priority, template, and source may remain the same.
Two notable IDs, NT-005513 and NT-005878, appear four times in the relevant population.
Analytical implication
A query that joins another table on:
a.note_id = n.note_id
can multiply rows whenever a logical note has multiple physical ingestion records.
For logical-note reporting, the query must first establish which note/version represents the intended analytical observation.
________________________________________
6. Referential Integrity
The profiling checks found no orphan relationships in the main operational relationships.
Note relationships
All distinct logical notes had valid:
•	clinician references
•	MDS references
Audit relationships
All 1,780 audits referenced valid notes.
All 1,780 audits referenced valid MDS records.
Escalation relationships
All 533 escalations referenced valid:
•	notes
•	MDS assignees
Therefore, the major problems are not missing foreign-key relationships. They are primarily grain, temporal join, filtering, and semantic-definition problems.
________________________________________
7. Null and Semantic Consistency Checks
note
There are 152 NULL word_count values.
Other core note identifiers and timestamps contain no NULLs.
The void fields are internally consistent:
•	6,145 rows have is_void = 0 and NULL void_reason.
•	90 rows have is_void = 1 and a non-NULL void_reason.
This indicates that the void fields themselves follow a coherent rule.
escalation
There are:
•	43 NULL slack_thread_ts
•	43 NULL first_response_at_utc
•	163 NULL resolved_at_utc
•	490 NULL last_api_error
The 43 records with NULL Slack thread and NULL first response correspond to the PENDING_POST population identified later.
________________________________________
8. Timestamp Consistency
The timestamp checks did not identify impossible ordering relationships.
For note:
•	delivered before submitted: 0
•	ingested before submitted: 0
•	ingested before delivered: 0
For escalation:
•	first response before creation: 0
•	resolution before creation: 0
•	resolution before first response: 0
Therefore, timestamp ordering is not the primary cause of the reporting discrepancies.
________________________________________
9. Rubric Configuration Profiling
There are two rubric versions.
Rubric v1
Effective from:
2024-01-01
Weights:
Dimension	Weight
Accuracy	0.30
Completeness	0.20
Formatting	0.10
HPI	0.10
Plan	0.15
ROS	0.05
Terminology	0.10
Pass threshold:
0.85
Rubric v2
Effective from:
2026-05-15
Weights:
Dimension	Weight
Accuracy	0.35
Completeness	0.25
Formatting	0.05
HPI	0.10
Plan	0.10
ROS	0.05
Terminology	0.10
Pass threshold:
0.90
Important business change
On 15 May 2026:
•	pass threshold increased from 85% to 90%
•	accuracy weight increased from 30% to 35%
•	completeness increased from 20% to 25%
•	formatting decreased from 10% to 5%
•	plan decreased from 15% to 10%
Therefore, any report spanning April through June 2026 needs to consider rubric version/effective date if it is intended to evaluate audits according to the rules that were active at the time.
________________________________________
10. SLA Configuration Profiling
There are eight SLA configurations.
Product	Priority	Before 2026-05-15	From 2026-05-15
AMBIENT_ASSIST	STANDARD	45 min	30 min
AMBIENT_ASSIST	URGENT	20 min	15 min
AMBIENT_LIVE	STANDARD	40 min	28 min
AMBIENT_LIVE	URGENT	18 min	12 min
The (product_line, priority, effective_from) combination is unique.
However, the same product/priority combination intentionally has two temporal versions.
Therefore, a query joining only:
s.product_line = n.product_line
AND s.priority = n.priority
is not sufficient.
It can match both the historical and current SLA configuration.
The effective date must also be part of the join.
________________________________________
11. Query Reconciliation
Q1 — Audit Pass Rate
Reported metric
The supplied query reports:
1,486 notes audited
91.4% pass
SQL Server reproduction
The supplied logic produced:
audited_notes       = 1,732
pass_rate_pct       = 79.9%
avg_composite       = 0.9049
The reported metric therefore could not be reproduced.
Diagnostic results
The joined population contained:
joined_rows          = 1,732
distinct_audits      = 1,583
distinct_notes       = 1,583
distinct_clinicians  = 60
There are therefore:
1,732 - 1,583 = 149
excess joined rows.
A further check found no note with more than one audit in this population.
The multiplication is therefore caused by duplicate note_id rows rather than multiple audits per note.
Two especially visible cases were:
NT-005513
NT-005878
Both contained four physical note rows while having one audit.
Audit-date diagnostic
When audits themselves were filtered by audited_at_utc for the same reporting period:
audits_in_period = 1,594
distinct_audits  = 1,578
The first audit in the period was:
2026-04-01 03:42:22
The last audit in the period was:
2026-06-30 18:04:41
This demonstrates that the original query is not actually filtering by audit date.
Root causes
Root cause 1 — wrong grain
The query counts joined rows rather than unique audit events.
COUNT(*)
is therefore vulnerable to duplicate note records.
Root cause 2 — note date versus audit date
The supplied query filters:
n.submitted_at_utc
rather than:
a.audited_at_utc
Therefore it answers:
“Audits associated with notes submitted during the period”
rather than:
“Audits performed during the period.”
Recommended logic
If the business metric is “audits performed during Q2”, the population should be based on note_audit.audited_at_utc.
The audit event should be counted at the audit_id grain.
Example pattern:
COUNT(DISTINCT a.audit_id)
and the date predicate should use:
a.audited_at_utc >= '2026-04-01'
AND a.audited_at_utc < '2026-07-01'
The note join should not be allowed to multiply audit events.
________________________________________
Q2 — SLA Breach Rate
Reported metric
The supplied query reports:
4.2% breach
median = 20 minutes
SQL Server reproduction
The translated query produced:
notes_measured    = 296
breach_rate_pct   = 12.8%
median_minutes    = 18.45
The reported figures were not reproduced.
Diagnostic results
For the reporting period:
total_notes_in_period       = 5,589
notes_without_escalation    = 5,112
notes_with_resolved_escalation = 329
notes_with_open_escalation  = 148
The SLA join produced:
joined_rows          = 11,178
distinct_notes       = 5,527
distinct_sla_configs = 8
Every product/priority combination matched two SLA configurations.
For example, both historical and current configurations matched:
AMBIENT_ASSIST / STANDARD
AMBIENT_ASSIST / URGENT
AMBIENT_LIVE   / STANDARD
AMBIENT_LIVE   / URGENT
After applying the query’s filters:
rows_after_filters       = 296
distinct_notes           = 147
distinct_escalations     = 147
distinct_sla_configs     = 8
Root cause 1 — LEFT JOIN behaves as an INNER JOIN
The query uses:
LEFT JOIN dbo.escalation e
    ON e.note_id = n.note_id
but then applies:
WHERE e.status <> 'RESOLVED'
For a note without an escalation:
e.status = NULL
and:
NULL <> 'RESOLVED'
does not evaluate to TRUE.
Therefore, notes with no escalation are removed.
The apparent LEFT JOIN is consequently acting as an effective inner filter for this condition.
Root cause 2 — temporal SLA join missing
The query joins SLA only by:
product_line
priority
but the configuration is effective-dated.
This causes historical and current configurations to match the same note.
That is a direct source of row multiplication.
Root cause 3 — duplicate note IDs
The note table contains 62 duplicate excess rows by note_id.
These can further multiply the SLA/escalation joins.
Root cause 4 — unclear business denominator
The query appears to define the population as notes with non-resolved escalations, rather than all notes subject to SLA measurement.
This is materially different from a standard SLA breach-rate definition such as:
breached notes / all eligible notes.
Recommended logic
The intended population must first be explicitly defined.
Then:
1.	Select the intended note grain.
2.	Join exactly one effective SLA configuration based on the note’s applicable date.
3.	Determine whether an escalation is relevant without unintentionally excluding non-escalated notes.
4.	Calculate breach status at the intended logical-note grain.
5.	Aggregate only after deduplication.
A temporal SLA join should include the effective date, for example:
s.product_line = n.product_line
AND s.priority = n.priority
AND CAST(n.submitted_at_utc AS date) >= s.effective_from
AND (
    s.effective_to IS NULL
    OR CAST(n.submitted_at_utc AS date) <= s.effective_to
)
The exact date rule should follow the business definition of when an SLA becomes effective.
________________________________________
Q3 — Daily Volume Anomaly
Supplied business rule
The comment states:
Flag any weekday more than 30% below the trailing 14-day average.
SQL Server result
The query returned:
calendar_days_with_notes = 91
first_day                 = 2026-04-01
last_day                  = 2026-06-30
anomaly_days              = 28
Observed anomaly pattern
Many flagged dates are Saturdays and Sundays.
Examples include:
2026-04-04
2026-04-05
2026-04-11
2026-04-12
2026-04-18
2026-04-19
2026-04-25
2026-04-26
2026-05-02
2026-05-03
2026-05-09
2026-05-10
2026-05-16
2026-05-17
2026-05-23
2026-05-24
2026-05-30
2026-05-31
2026-06-06
2026-06-07
2026-06-13
2026-06-14
2026-06-20
2026-06-21
2026-06-27
2026-06-28
There are also some weekday exceptions, including 25 May and 19 June.
Root cause
The SQL does not implement the business rule’s weekday restriction.
There is no condition excluding Saturday or Sunday.
Therefore, normal lower weekend volume is repeatedly classified as an anomaly.
The result is:
28 anomaly days out of 91
or approximately:
30.8% of observed calendar days
being flagged.
That rate is inconsistent with the intended interpretation of an operational anomaly detector.
Additional implementation observation
The window is:
ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING
This means the calculation uses the previous 14 rows rather than explicitly saying “previous 14 calendar days.”
In the observed dataset there is a row for every calendar day in the period, so this does not materially change the current result.
However, it is fragile if a future reporting period contains dates with zero activity and therefore no row.
Recommended logic
The anomaly rule should explicitly distinguish weekdays from weekends.
The trailing baseline should also be defined in calendar terms if the business rule genuinely means 14 calendar days.
The key principle is:
Do not label predictable weekly seasonality as an operational anomaly.
________________________________________
Q4 — MDS Performance
Supplied metric
The supplied query reports, per MDS:
•	notes handled
•	average word count
•	average composite score
•	short-note flags
The query returned 34 MDSs.
Examples of the reported leaderboard include:
Marchetti, Ana       165 notes   0.9255 composite
Whitfield, Viktor   161 notes   0.9225 composite
Novak, Marcus       171 notes   0.9202 composite
...
Domingo, Rafael     341 notes   0.9022 composite
...
Duplantis, Owen     163 notes   0.8856 composite
Achebe, Noor        188 notes   0.8784 composite
Diagnostic result
The complete Q4 join contained:
joined_rows          = 5,589
distinct_notes       = 5,527
distinct_audits      = 1,583
distinct_mds         = 34
Therefore:
5,589 - 5,527 = 62
physical duplicate rows exist in the reporting population.
Duplicate note rows occur across 29 of the 34 MDSs.
The largest duplicate excesses include:
MDS	Physical rows	Distinct notes	Excess
Petronella, Emeka	164	159	5
Hargreaves, Ingrid	160	156	4
Ivanova, Kofi	167	163	4
Halvorsen, Yusuf	167	164	3
Domingo, Rafael	341	338	3
Domingo’s high volume is therefore not primarily caused by duplicate rows; the diagnostic shows 338 distinct logical notes versus 341 physical rows.
Root cause 1 — physical row count
The query uses:
COUNT(*)
rather than a logical-note count.
Therefore, notes_handled represents physical note rows rather than unique logical notes.
Root cause 2 — duplicated notes influence averages
The duplicate note rows are not only a counting problem.
They also participate in:
AVG(n.word_count)
and:
AVG(a.composite_score)
Therefore, the same logical note can receive greater weight in an MDS’s averages.
This can affect MDS ranking.
Root cause 3 — NULL word count converted to zero
There are 152 NULL word_count values.
The query uses:
AVG(COALESCE(n.word_count, 0))
which treats missing word count as zero.
This is a semantic assumption that is not established by the data.
Missing word counts vary by MDS.
Examples:
MDS	Note rows	NULL word counts	NULL %
Ferreira, Camille	166	8	4.8%
Hargreaves, Ingrid	160	7	4.4%
Marchetti, Ana	165	7	4.2%
Vasquez, Lena	169	7	4.1%
Moreau, Sunita	144	1	0.7%
Therefore, treating NULL as zero can affect comparisons between MDSs.
The query also treats NULL inconsistently:
AVG(COALESCE(word_count, 0))
treats NULL as zero for the average, while:
CASE WHEN word_count < 50 THEN 1
does not classify NULL as a short note.
Recommended logic
If the metric means logical notes handled:
COUNT(DISTINCT n.note_id)
should be considered, subject to the intended definition of a logical note/version.
For averages, first establish one analytical observation per logical note and then calculate the average.
For word_count, NULL should remain missing unless the business explicitly defines NULL as zero.
________________________________________
Q5 — Open Escalations
Supplied query result
The SQL Server reproduction returned:
open_escalations             = 151
avg_minutes_to_first_response = 49.0
oldest_open                  = 2026-04-03 04:14:09
Diagnostic breakdown
The 151 non-resolved escalations consist of:
Status	Escalations	With first response	Without first response	Avg response
OPEN	108	108	0	49.0 min
PENDING_POST	43	0	43	NULL
Therefore:
151 total non-resolved
108 with first response
43 without first response
Root cause
The query uses:
COUNT(*)
for the number of open/non-resolved escalations.
But it uses:
AVG(first_response_at_utc - created_at_utc)
for the response-time metric.
SQL AVG() ignores NULL values.
Therefore, the query reports:
151 open/non-resolved escalations and 49-minute average response time
but the 49-minute average actually applies only to:
108 OPEN escalations that have a first response.
The 43 PENDING_POST escalations have no first response and are silently excluded from the average.
Why this matters
The 43 excluded records are operationally significant.
They have the following pattern:
status = PENDING_POST
slack_thread_ts IS NULL
first_response_at_utc IS NULL
attempt_count = 1
last_api_error = slack_api:ratelimited (HTTP 429)
These records represent escalations that were created but were not successfully posted to Slack.
They therefore represent a failure mode that should not disappear from operational reporting merely because the response timestamp is NULL.
Recommended logic
The dashboard should report the populations separately, for example:
•	total non-resolved escalations
•	escalations with first response
•	escalations without first response
•	average response time among responded escalations
•	count of pending/unposted escalations
A NULL response time should be treated as an operational state, not silently removed from the denominator without explanation.
________________________________________
12. Cross-Cutting Findings
The reconciliation exercise identified several recurring patterns.
12.1 Natural-looking identifiers are not always unique
The most important examples are:
clinician_id
note_id
Both require additional context.
For clinicians, that context is the effective date.
For notes, that context is the ingestion/version identifier.
________________________________________
12.2 Temporal configuration must be joined temporally
Both of the following tables are effective-dated:
clinician
sla_config
A join using only the business identifier is insufficient when multiple historical versions exist.
________________________________________
12.3 Join multiplication is a major reporting risk
The note table contains duplicate logical IDs.
The SLA table contains multiple historical/current configurations per product/priority.
Consequently, queries can multiply rows without any obvious SQL syntax error.
This is especially dangerous because the resulting numbers can look plausible.
________________________________________
12.4 NULL values contain operational meaning
Examples:
word_count = NULL
first_response_at_utc = NULL
slack_thread_ts = NULL
These values should not automatically be converted to zero or ignored.
A NULL can mean:
•	not measured
•	not available
•	not yet completed
•	not applicable
•	operational failure
The correct interpretation must be established from the business process.
________________________________________
12.5 Filtering can change the meaning of a JOIN
The Q2 query uses a LEFT JOIN but filters the right-hand table in the WHERE clause.
This effectively excludes rows where the right-hand record is absent.
This is a common source of accidental population changes.
________________________________________
13. Reconciliation Summary
Query	Reported	SQL Server reproduction	Main issue
Q1 Audit pass rate	1,486 / 91.4%	1,732 / 79.9%	Duplicate note grain + note date used instead of audit date
Q2 SLA breach	4.2% / 20 min median	12.8% / 18.45 min median	Missing effective-date SLA join + accidental inner filtering + duplicate notes
Q3 Volume anomaly	Business rule: weekday >30% below baseline	28 anomaly days	Weekends are not excluded
Q4 MDS performance	34-MDS leaderboard	5,589 physical rows / 5,527 distinct notes	Duplicate note grain + NULL word count treated as zero
Q5 Open escalations	N/A in supplied business statement	151 / 49 min	Average excludes 43 PENDING_POST records with NULL response
________________________________________
14. Recommended Analytical Guardrails
Before publishing these metrics, the reporting layer should enforce the following controls.
Guardrail 1 — Establish grain before aggregation
Every report should explicitly state whether its unit of analysis is:
•	physical note row
•	logical note
•	audit event
•	escalation event
•	configuration version
Do not use COUNT(*) unless the table/join grain is known to be one row per intended observation.
________________________________________
Guardrail 2 — Validate uniqueness before joining
For important identifiers, check:
COUNT(*)
COUNT(DISTINCT key)
before relying on the key as unique.
________________________________________
Guardrail 3 — Apply effective dates to versioned dimensions
For effective-dated tables such as clinician and sla_config, use both the identifier and applicable date.
________________________________________
Guardrail 4 — Protect against join multiplication
After important joins, compare:
COUNT(*)
against:
COUNT(DISTINCT logical_key)
Unexpected differences should stop publication until understood.
________________________________________
Guardrail 5 — Make NULL treatment explicit
Do not automatically convert NULL to zero.
For every NULL-sensitive metric, document whether NULL means:
•	zero
•	unknown
•	not applicable
•	not completed
________________________________________
Guardrail 6 — Separate operational states
For escalations, report states such as:
OPEN
PENDING_POST
RESOLVED
separately where their timestamps have different meanings.
________________________________________
Guardrail 7 — Make temporal business rules explicit
Metrics spanning configuration changes must account for effective dates.
This applies to:
•	SLA targets
•	rubric versions
•	clinician versions
________________________________________
15. Part 3 Failure Pattern Identified During Reconciliation
The escalation profiling also identified a clear stranded-escalation population.
There are 43 PENDING_POST escalations.
All 43 have:
slack_thread_ts IS NULL
first_response_at_utc IS NULL
attempt_count = 1
last_api_error = slack_api:ratelimited (HTTP 429)
They cluster around two short periods:
2026-05-07 14:00–14:05
2026-06-11 09:00–09:04
This is materially different from random individual failures.
The pattern indicates a likely rate-limit failure during short bursts, after which the records remained in PENDING_POST instead of being successfully posted/retried.
Candidate recovery rule
A rule-based recovery population can therefore be defined as:
WHERE status = 'PENDING_POST'
  AND slack_thread_ts IS NULL
  AND first_response_at_utc IS NULL
The rule is based on the state of the record rather than a hardcoded list of escalation IDs.
The observed HTTP 429 error and attempt_count = 1 provide supporting evidence for the failure pattern, rather than being the sole basis of detection.
This rule is suitable for Part 3 because it identifies the affected class of records dynamically.
________________________________________
16. Overall Conclusion
The supplied operational metrics cannot be treated as reliable reproductions of the underlying data without addressing grain, temporal joins, filtering semantics, and NULL handling.
The most important data-model finding is that:
note_id is a logical identifier, not a unique physical row identifier.
There are 6,235 physical note rows but only 6,173 distinct logical note IDs.
This explains substantial multiplication in the audit, SLA, and MDS reporting queries.
The second major finding is that several business rules are temporal:
•	clinician records are effective-dated
•	SLA configurations are effective-dated
•	rubric versions change during the reporting period
These temporal dimensions must be joined using the applicable date rather than identifier alone.
The third major finding is semantic:
NULL values and operational states are being treated as if they have no analytical meaning.
Examples include NULL word counts being converted to zero and PENDING_POST escalations being excluded from response-time averages.
Finally, the anomaly query does not implement its stated weekday rule, resulting in repeated weekend “anomalies” that are better explained by normal weekly seasonality.
The correct approach is therefore not simply to modify the five queries until they match the reported figures. The data should first be reconciled to a clearly defined business grain and then the reporting metrics should be rebuilt from that grain.
________________________________________
17. Key Evidence Collected
The principal evidence supporting this reconciliation is:
clinician:
64 rows / 60 clinician IDs

mds:
34 rows / 34 MDS IDs

note:
6,235 rows / 6,173 note IDs
62 duplicate excess rows
note_id + ingestion_id = unique

note_audit:
1,780 audits / 1,780 audit IDs

escalation:
533 escalations / 533 escalation IDs

Q1:
1,732 joined rows
1,583 distinct audits
79.9% pass rate
0.9049 average composite

Q2:
296 rows after filters
147 distinct notes
147 distinct escalations
12.8% breach rate
18.45 minute median

Q3:
91 calendar days
28 anomaly days
many anomalies occur on weekends

Q4:
5,589 physical note rows
5,527 distinct notes
62 duplicate excess rows
152 NULL word counts

Q5:
151 non-resolved escalations
108 OPEN with first response
43 PENDING_POST without first response
49-minute average among responded OPEN escalations

Part 3:
43 PENDING_POST records
43 NULL Slack thread timestamps
43 NULL first-response timestamps
43 HTTP 429 rate-limit errors
attempt_count = 1
These findings establish the basis for rebuilding the operational reporting logic without hiding the underlying data-quality and semantic issues.
