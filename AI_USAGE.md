# AI Usage

## Where I Used AI

I used AI assistance during the assessment primarily for:

* Reviewing and refining SQL Server queries used for data profiling and reconciliation.
* Brainstorming approaches for identifying duplicate records, missing relationships, orphan records, and metric discrepancies.
* Reviewing the structure and wording of `RECONCILIATION.md`.
* Troubleshooting Retool Cloud connectivity with my local SQL Server environment.
* Reviewing implementation approaches for the Retool Audit Triage Workbench and recovery workflow.
* Improving documentation clarity and checking that technical findings were communicated in business terms.

AI was used as an assistant rather than as a substitute for validation. I executed and reviewed the SQL logic against the assessment data and made the final decisions about the findings and implementation.

## What I Used It For

The main use of AI was to accelerate exploration and provide alternative approaches. For example, I used it to suggest SQL patterns for checking key uniqueness, duplicate records, NULL values, join multiplication, and reconciliation of reported metrics against the underlying data.

I also used AI to help structure the reconciliation findings and explain the business impact of data-quality issues. Where AI suggested an approach, I reviewed it against the actual schema, data characteristics, and assessment requirements before using it.

## Example of Rejected / Corrected AI Output

One concrete example was the SQL reconciliation approach.

AI initially suggested generic SQL using placeholder column names and assumptions about the schema, such as audit timestamp, pass/fail, score, SLA, and rubric columns. I did **not** use those queries unchanged because the suggested column names did not necessarily match the actual assessment schema.

I corrected the approach by first profiling the provided tables and verifying the actual columns, grain, uniqueness, and relationships. I then adapted the SQL to the actual SQL Server database and used the verified data characteristics when calculating the reconciliation metrics.

This correction was important because using AI-generated assumptions without validating them could produce apparently reasonable but incorrect business metrics.

## Principle

I treated AI output as a starting point for investigation, not as authoritative evidence. Final findings were based on the assessment data, executable SQL, and my own review and judgment.
