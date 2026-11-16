Legacy SQL Migration Analysis
PostgreSQL → Microsoft Fabric | Static source-code review

Object: legacy.v_monthly_sales_report
Source dependency: legacy.sales_v1
Scope: 27 lines of SQL, analyzed without external business requirements or database access.
1. Executive assessment
The SQL defines a monthly sales aggregation view, but several important behaviors require validation before migration.

The most significant finding is a logical contradiction between the customer classification and the filtering condition.
CASE
    WHEN customer_key = 0 THEN 'UNKNOWN'
    ELSE 'NONZERO'
END AS customer_group


However:
WHERE customer_key <> 0


The filter removes every row that could satisfy the UNKNOWN branch. Consequently, customer_group can only contain 'NONZERO' in the resulting view.

This is demonstrably unreachable logic, but it is not sufficient evidence that the SQL is incorrect. The original business requirement might intentionally exclude unknown customers while retaining an obsolete classification.

Other important findings include:
- Customer records with customer_key = 0 or NULL are silently excluded.
- sale_count measures source rows, not necessarily distinct sales or invoices.
- Monthly aggregation permits a NULL month when invoice_date is missing.
- Monetary aggregations ignore individual NULL values but return NULL if every value in a group is missing.
- No date-range, currency, sales-status, or duplicate-removal logic is present.
- The three monetary totals are independently aggregated without reconciliation.
These conclusions describe implemented SQL behavior, not confirmed business policy. 
monthly_sales_report.sql

2. SQL rule catalogue
Confidence convention: High means the implemented behavior follows directly from the SQL and PostgreSQL semantics. Medium means an observation depends on an unverified data type or environmental condition. All suspected business intentions below are hypotheses, not established requirements.
A. View definition, dependencies and row eligibility
Rule ID / lines	Relevant SQL expression	Actual implemented behavior	Suspected business intent (unconfirmed)	Confidence	Suggested validation test
R01 · L1	CREATE OR REPLACE VIEW legacy.v_monthly_sales_report	Defines or replaces a regular, non-materialized reporting view with six output columns.	Provide a reusable monthly reporting interface.	High	Inspect the deployed view schema and verify all six output names and types.
R02 · L23	FROM legacy.sales_v1	Reads from one source relation. No explicit joins, lookups or enrichment are performed in this view.	Use a prepared sales dataset as the reporting source.	High	Inspect the source object's grain and upstream dependencies; compare source and output populations.
R03 · L25	WHERE customer_key <> 0	Excludes every row with customer_key = 0. Retains positive and negative nonzero keys.	Possibly exclude placeholder or unknown customers.	High	Supply records with keys 0, 1 and -1; verify that only the latter two contribute.
R04 · L25	customer_key <> 0	Also excludes NULL customer keys because the comparison evaluates to SQL UNKNOWN, not TRUE.	Possibly require valid customer identifiers. No explicit NULL policy is documented.	High	Supply a row with customer_key = NULL and nonzero amounts; confirm it contributes nothing.

B. Calendar transformation and customer classification
Rule ID / lines	Relevant SQL expression	Actual implemented behavior	Suspected business intent (unconfirmed)	Confidence	Suggested validation test
R05 · L4–5	DATE_TRUNC('month', invoice_date)::DATE	Converts each invoice date/timestamp to the first calendar day of its month, returning a date.	Assign sales to calendar reporting months.	High	Confirm dates such as 2026-03-01 and 2026-03-31 both produce 2026-03-01.
R06 · L7–8, L25	WHEN customer_key = 0 THEN 'UNKNOWN'	Defines an UNKNOWN classification that cannot be reached by any row surviving the WHERE clause.	Possibly intended to identify unknown customers, or may be obsolete logic.	High	Insert a key-zero source row, query the view and verify that no UNKNOWN group appears.
R07 · L9–10, L25	ELSE 'NONZERO' AS customer_group	Assigns every surviving row the constant label NONZERO. The label does not distinguish positive from negative keys.	Possibly intended to group all eligible customers together.	High	Mix positive and negative nonzero keys in the same month; verify one customer group.
R08 · L4–5, L25, L27	DATE_TRUNC(...) with GROUP BY 1, 2	Rows with invoice_date = NULL are not filtered out solely because the date is missing. They form a separate NULL month group.	Missing dates may require exception reporting instead.	High	Include a nonzero-key row with a NULL invoice date and verify the NULL-month output.
R09 · L23–25	No invoice-date predicate	There is no reporting start date, end date or rolling-period restriction in this view. Every source period can contribute.	Possibly provide a complete historical monthly report.	High	Include historical and future-dated source rows; verify both appear if otherwise eligible.

C. Counting and monetary aggregation
Rule ID / lines	Relevant SQL expression	Actual implemented behavior	Suspected business intent (unconfirmed)	Confidence	Suggested validation test
R10 · L12	COUNT(*) AS sale_count	Counts qualifying source rows within each group, including rows whose monetary fields are NULL. It does not count distinct invoice IDs.	Count sales, assuming each source row represents one sale.	High	Add two rows for one invoice plus a row with NULL amounts; compare sale_count with distinct invoice count.
R11 · L14–15	SUM(total_excluding_tax)	Sums non-NULL tax-exclusive amounts from qualifying rows in each group.	Calculate monthly sales excluding tax.	High	Include values 100, 50, and NULL; expect 150.
R12 · L17–18	SUM(tax_amount)	Sums non-NULL tax amounts independently. Does not compute tax from rates or tax-exclusive totals.	Calculate monthly tax collected or charged.	High	Include tax amounts 20, 10, and NULL; expect 30.
R13 · L20–21	SUM(total_including_tax)	Sums non-NULL tax-inclusive amounts independently, without deriving them from the other two aggregates.	Calculate monthly gross sales including tax.	High	Include values 120, 60, and NULL; expect 180.
R14 · L14–21	Three SUM(...) expressions	Each SUM ignores NULL inputs, but returns NULL if no non-NULL input exists in a populated group. No COALESCE or default of zero is applied.	Possibly distinguish missing financial data from actual zero amounts.	High	For one month, make every tax value NULL while other amounts exist; verify aggregated tax is NULL.
R15 · L27	GROUP BY 1, 2	Groups by the first two SELECT expressions: invoice_month and customer_group. Because the customer group is constant, the effective grouping is by invoice month.	Produce one summary row per reporting month.	High	Add multiple eligible source rows for two months; expect one NONZERO row per populated month.
R16 · L3–27	No DISTINCT or deduplication stage	Duplicate source records, if present, contribute repeatedly to counts and sums.	Source records may be assumed unique at the reporting grain.	High	Add two otherwise identical source rows; verify count and monetary sums both increase twice.
R17 · L14–21	Three separate source-based SUM(...) calculations	No check enforces sales_including_tax = sales_excluding_tax + tax_amount. Existing source discrepancies are carried into the result.	Source monetary amounts may already be reconciled upstream.	High	Use one row with excluding tax 100, tax 20, and including tax 130; verify the view retains all three values without correcting them.

D. Dependency and transformation inventory
The view has one direct source relation and no explicitly defined join or lookup dependencies.
Object or column	Role	Lines
legacy.v_monthly_sales_report	Output view	1
legacy.sales_v1	Source relation; underlying object type and dependencies unknown	23
invoice_date	Month derivation and grouping	4, 27
customer_key	Row filtering and customer classification	8, 25
total_excluding_tax	Tax-exclusive amount aggregation	14
tax_amount	Tax amount aggregation	17
total_including_tax	Tax-inclusive amount aggregation	20

The output schema consists of invoice_month, customer_group, sale_count, sales_excluding_tax, tax_amount, and sales_including_tax.

The view contains no explicit JOIN, DISTINCT, HAVING, ORDER BY, window function, currency conversion, fiscal-calendar transformation, or zero-filling operation for months without qualifying data. These are verified absences, not proof that the corresponding business functions are required.
3. Risk register
The following risks are derived from the observed rules. Severity ratings indicate potential migration significance, not confirmed defects.
Risk ID	Severity	Evidence and potential impact	Required business confirmation
K01 — Unreachable classification	High	R06–R07: UNKNOWN cannot appear because zero-key records are excluded beforehand. The customer dimension provides no effective segmentation.	Should unknown customers be reported separately, or deliberately excluded?
K02 — Silent customer exclusion	High	R03–R04: Both zero and NULL customer keys are omitted, along with their financial amounts. Totals can therefore differ from a report covering all source records.	Are these records invalid sales, or valid transactions with missing customer identification?
K03 — Incorrect interpretation of sale count	High	R10, R16: COUNT(*) counts source rows, not distinct invoices or transactions. Source grain is unknown.	Does one row in sales_v1 represent one sale, one invoice line, or another unit?
K04 — Inconsistent financial completeness	High	R11–R14: NULL financial values are ignored independently while affected rows remain in sale_count. Different aggregates may represent different subsets of source records.	Should incomplete financial records be included, excluded or separately flagged?
K05 — Unreconciled monetary totals	High	R17: Tax-inclusive sales are not calculated from tax-exclusive sales plus tax. Differences can pass through without warning.	Are the three source amounts guaranteed consistent? Are discounts, adjustments or rounding expected?
K06 — Source duplication	Medium	R02, R16: The view contains no deduplication. Repeated source records would contribute repeatedly.	Is uniqueness guaranteed upstream, and by which business key?
K07 — NULL invoice month	Medium	R08: Records without an invoice date can appear in a NULL-month group. Downstream consumers may omit this group or treat it inconsistently.	Should missing invoice dates be excluded, assigned to an exception group or reported separately?
K08 — Timezone-dependent month boundaries	Medium	R05: If invoice_date is timestamp with time zone, PostgreSQL month truncation can depend on the session timezone. A different target timezone could change month assignments.	What is the source data type, and which business timezone defines the reporting month?
K09 — Unbounded reporting period	Medium	R09: Historical, current and future-dated rows can all contribute. The view itself imposes no reporting window.	Should the report include all periods, only closed periods, or a configurable time window?
K10 — Incomplete month series	Medium	R15: A month with no qualifying source rows produces no output row. The SQL does not generate zero-sales months.	Must every reporting month appear, including months without sales?
K11 — Undocumented eligibility rules	Medium	R02–R03: No explicit filtering for transaction status, returns, negative amounts or currency exists. Such logic could exist upstream, but that cannot be established from this source.	Is sales_v1 already filtered and normalized to the appropriate reporting population?
K12 — Customer-key assumptions	Medium	R03, R07: Negative keys are included and classified as NONZERO, even if a negative value happens to represent an exceptional customer category.	What do zero, NULL, positive and negative customer keys mean?
K13 — PostgreSQL-to-Fabric semantic compatibility	Medium	R05, R15: The SQL uses PostgreSQL constructs such as ::DATE, DATE_TRUNC('month', ...) and positional grouping. Equivalent syntax and semantics cannot be assumed in the migration target.	Which Fabric SQL engine will execute the report, and what behavior must be preserved?
K14 — Undefined output ordering	Low	No ORDER BY is specified. Consumers cannot rely on the view returning months in chronological order.	Do any existing consumers depend on implicitly ordered output?

3.1 Confirmed logical contradiction
Customer classification path
legacy.sales_v1


WHERE customer_key ≠ 0

A row survives only when this predicate is TRUE.

Key = 0 or NULL

Filtered out
No output




Key ≠ 0 and non-NULL

Survives filter
NONZERO





There is no execution path that emits UNKNOWN under the current predicate.
Assessment: The classification is unreachable, not necessarily erroneous. Removing the exclusion or changing the classification would alter the report's meaning and requires business approval.
4. Questions for the business owner
These questions should be resolved before treating any rewritten SQL as functionally equivalent to the intended report.
Business validation checklist

0 of 12 answered

Customer eligibilityQ01. Should sales with `customer_key = 0` be excluded from reporting or included in an `UNKNOWN` group?


Q02. How should NULL or negative customer keys be classified? Are these valid, unknown, or invalid customers?


Q03. Is `customer_group` expected to provide meaningful segmentation, or is a single group intentional?




Sales definition and amountsQ04. What exactly constitutes a sale: a source row, an invoice, an invoice line, or another transaction unit?


Q05. Does `sales_v1` already manage duplicates, cancellations, refunds, credits and currency normalization?


Q06. Must tax-inclusive sales equal tax-exclusive sales plus tax, subject to an approved rounding tolerance?


Q07. When any monetary amount is NULL, should it be treated as zero, excluded or recorded as incomplete?




Reporting calendarQ08. Is the reporting period based on invoice date, posting date or another business-effective date?


Q09. What timezone, calendar and reporting-period boundaries apply?


Q10. Should missing-date records, future-dated invoices and months with no activity be included?




Migration acceptanceQ11. What is the expected historical reporting window and are previous month-end figures allowed to change?


Q12. Which existing report, approved dataset or reconciliation totals provide the authoritative migration baseline?




 Copy questions and responses
5. Migration validation criteria
The SQL can be validated for behavioral equivalence independently of whether its current behavior matches business intent.

A migration test dataset should include the following cases:
Test scenario	Expected behavior of original PostgreSQL view
Key 0 with positive sales	Record excluded entirely
Key NULL with positive sales	Record excluded entirely
Negative nonzero key	Record included as NONZERO
Two sales in the same month	Combined into one monthly group
Invoice date NULL with valid customer	Included in NULL-month group
All tax amounts NULL in a populated group	Aggregated tax_amount is NULL
Some tax amounts NULL	Sum uses non-NULL tax values; count includes all eligible rows
Duplicate source rows	Both counted and summed
Month with no source activity	No output row for that month
Tax-inclusive amount inconsistent with component amounts	Source amounts aggregated independently
Dates in older or future months	Included if otherwise eligible

For a reliable migration assessment, compare source and target outputs at three levels: monthly row counts, monthly financial totals, and the presence of exceptional groups such as a NULL invoice month. Test data should preserve relevant data types, decimal precision and timezone settings.
6. Conclusion
Confirmed from the SQL: The report aggregates eligible source rows by calendar invoice month; excludes zero and NULL customer keys; emits only the NONZERO customer classification; counts rows rather than distinct invoices; and independently sums three monetary columns.

Not established from the SQL: Whether the customer exclusions are intentional, whether the underlying rows represent individual sales, whether NULL amounts are acceptable, whether the monetary values reconcile, and whether the selected calendar and reporting scope match the business requirement.

Migration decision: Preserve the existing observable behavior as the initial comparison baseline. Treat the unreachable classification, silent exclusions and monetary completeness assumptions as items requiring explicit business decisions rather than making automatic corrections.

This separates two different acceptance questions: Did Microsoft Fabric reproduce the legacy SQL? and Does the resulting report implement the business rules the organization actually wants?