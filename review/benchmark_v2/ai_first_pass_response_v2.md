# Legacy SQL Migration Analysis

PostgreSQL → Microsoft Fabric | Static SQL review | Rule catalogue and migration risk assessment

## 1. Executive summary

The SQL defines `legacy.v_monthly_sales_candidate_v2`, an aggregated reporting view that combines sales data with item-group classifications and produces sales measures by invoice month, customer group, and item group.

The review identifies several behaviors that merit validation before migration, particularly:

1. Invoice dates are shifted forward by one day before monthly grouping. Transactions on the last day of a month are consequently assigned to the following month.
2. NULL customer keys are classified as `NONZERO`. Only an actual customer key of `0` receives the `UNKNOWN` classification.
3. Sales excluding tax are rounded before aggregation, while tax and sales including tax are aggregated without equivalent rounding.
4. The item mapping join has no uniqueness enforcement. Multiple mapping records for one stock item can multiply sales rows and amounts.
5. `COUNT(*)` counts joined rows, not distinct sales. The reported count depends on source granularity and mapping cardinality.
6. There are no explicit filters for transaction status, date range, returns, cancellations, or other business conditions.
7. NULL amounts and missing classifications are handled differently, potentially producing partially populated results.

These are observable behaviors or conditional risks, not confirmed defects.

The SQL alone cannot establish whether they are intentional business rules, legacy workarounds, or unintended implementation effects.

Business validation required

Assessment, not a correctness verdict

Recommended migration principle: Preserve the observable legacy behavior as the comparison baseline. Make any business-approved changes explicit and test them separately rather than silently correcting the SQL during migration.

## 2. Scope, evidence and dependencies

The analysis uses only the supplied SQL. No original requirements, table definitions, production data, constraints, source-view definitions, or business documentation have been assumed.

Line references use the supplied SQL formatting, counting `CREATE OR REPLACE VIEW` as line 1, retaining blank lines, and excluding the surrounding square brackets and display escape characters.

### 2.1 Direct table/view dependencies

| Object                                | Role                                    | Referenced fields                                                                                                        |
| ------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `legacy.sales_v1`                     | Primary sales source, line 13           | `sale_key`, `customer_key`, `stock_item_key`, `invoice_date`, `total_excluding_tax`, `tax_amount`, `total_including_tax` |
| `legacy.item_group_map_v2`            | Item classification lookup, lines 46–47 | `stock_item_key`, `item_group`                                                                                           |
| `legacy.v_monthly_sales_candidate_v2` | Resulting reporting view, lines 1–2     | Three grouping dimensions and four aggregated measures                                                                   |

Both source object names could represent views rather than physical tables. Their upstream dependencies and internal filters cannot be determined from this SQL.

### 2.2 Processing lineage

`legacy.sales_v1`

Seven source columns projected; no explicit filtering

sales_base

Sales transformations

Date shift, customer classification, monetary rounding

`legacy.item_group_map_v2`

LEFT JOIN by stock item, then fallback classification

`enriched_sales`

Joined and transformed rows; possible one-to-many expansion

Final monthly reporting view

GROUP BY invoice_month, customer_group, item_group

COUNT(\*) + three SUM() measures

### 2.3 Output grain and filters

The SQL produces one row per distinct combination of:

`(invoice_month, customer_group, item_group)`

| Output column         | Type of logic                              |
| --------------------- | ------------------------------------------ |
| `invoice_month`       | Date shift followed by month truncation    |
| `customer_group`      | Two-branch classification                  |
| `item_group`          | Joined classification with NULL fallback   |
| `sale_count`          | Count of joined rows                       |
| `sales_excluding_tax` | Sum of individually rounded source amounts |
| `tax_amount`          | Sum of source tax amounts                  |
| `sales_including_tax` | Sum of source tax-inclusive amounts        |

There is no explicit `WHERE`, `HAVING`, `DISTINCT`, `LIMIT`, transaction-status predicate, or reporting-period predicate.

This means there is no row-level exclusion expressly implemented by a filter in this view, although upstream source logic, SQL NULL aggregation behavior, and the join can materially affect the output.

## 3. Structured rule catalogue

Confidence interpretation: SQL behavior is classified as High confidence where directly determined by the expression. Suspected business intent is separately rated High, Medium, or Low; it is not treated as a confirmed requirement.

### 3.1 Source selection, joins and lookup rules

| Rule / Lines     | SQL expression                                               | Actual implemented behavior                                                                                                                                                      | Suspected business intent                                                         | Confidence                     | Suggested validation test                                                                                   |
| ---------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| BR-001 1–2       | `CREATE OR REPLACE VIEW legacy.v_monthly_sales_candidate_v2` | Defines or replaces a view rather than creating a stored monthly snapshot.                                                                                                       | Provide a reusable reporting dataset.                                             | Behavior: High; intent: Medium | Query the view after changing controlled source records; verify whether dynamic results match expectations. |
| BR-002 4–14      | `SELECT ... FROM legacy.sales_v1`                            | Projects seven columns without filtering, deduplicating, or modifying source rows.                                                                                               | Establish the population of reportable sales.                                     | Behavior: High; intent: Low    | Compare source and `sales_base` row counts, including records with NULL values.                             |
| BR-003 18, 50–71 | `s.sale_key` projected internally; omitted from final SELECT | Sale identifiers are carried through enrichment but not used for deduplication, counting distinct sales, or final grouping.                                                      | Sale key may be retained for traceability or left from an earlier implementation. | Behavior: High; intent: Low    | Insert duplicate `sale_key` records and determine whether both contribute to the output.                    |
| BR-004 44–47     | `LEFT JOIN legacy.item_group_map_v2 m`                       | All sales source rows are preserved by the join, including those with no mapping match. A matching sale can be repeated when the map has multiple matches.                       | Retain sales even when item classification is unavailable.                        | Behavior: High; intent: Medium | Test unmapped items, one-to-one matches, and one-to-many matches.                                           |
| BR-005 46–47     | `ON s.stock_item_key = m.stock_item_key`                     | Mapping is based exclusively on stock-item-key equality. NULL keys do not match one another. No effective-date, status, or priority condition is applied.                        | Assign item categories using a stock-item lookup.                                 | Behavior: High; intent: Medium | Inspect key uniqueness; test NULL keys and multiple mapping rows for the same item.                         |
| BR-006 31–34     | `COALESCE(m.item_group, 'UNMAPPED')`                         | Replaces a NULL mapped group with `UNMAPPED`. This covers both absent mapping records and matched records with NULL `item_group`. Empty strings and whitespace are not replaced. | Identify sales without usable classifications.                                    | Behavior: High; intent: Medium | Test no match, matched NULL, empty string, whitespace, and literal `UNMAPPED`.                              |

### 3.2 Date transformations and customer classifications

| Rule / Lines        | SQL expression                                          | Actual implemented behavior                                                                            | Suspected business intent                                       | Confidence                     | Suggested validation test                                                                 |
| ------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- | ------------------------------ | ----------------------------------------------------------------------------------------- |
| BR-007 20–23        | `s.invoice_date + INTERVAL '1 day'`                     | Adds one calendar-day interval to each invoice date before monthly grouping.                           | Possible reporting cutoff convention or legacy date adjustment. | Behavior: High; intent: Low    | Test the first, middle, penultimate, and final days of several months.                    |
| BR-008 20–23        | `DATE_TRUNC('month', ...)::DATE`                        | Truncates the shifted timestamp to the start of its month, then converts it to a date.                 | Produce a first-of-month reporting key.                         | Behavior: High; intent: Medium | Verify output for month ends, year ends, and leap years.                                  |
| BR-009 20–23, 68–71 | `invoice_date` used without `COALESCE` or a NULL filter | NULL invoice dates produce NULL `invoice_month` values, which form a NULL-month group when aggregated. | Not established; potentially preserve undated records.          | Behavior: High; intent: Low    | Include NULL invoice dates and confirm they appear in grouped results.                    |
| BR-010 25–27        | `WHEN s.customer_key = 0 THEN 'UNKNOWN'`                | Only customers whose key equals numeric zero are classified as `UNKNOWN`.                              | Treat zero as a sentinel for an unknown customer.               | Behavior: High; intent: Medium | Test customer keys `0`, positive, negative, and NULL. Confirm the meaning of key zero.    |
| BR-011 25–29        | `ELSE 'NONZERO'`                                        | Every condition not evaluated as TRUE uses `NONZERO`, including a NULL customer key.                   | Classify all other customers in a common category.              | Behavior: High; intent: Low    | Explicitly test NULL customer keys and compare with the expected unknown-customer policy. |

### 3.3 Financial measures and aggregation rules

| Rule / Lines | SQL expression                                                              | Actual implemented behavior                                                                                                                                                                           | Suspected business intent                                          | Confidence                     | Suggested validation test                                                                                                     |
| ------------ | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| BR-012 36–39 | `ROUND(s.total_excluding_tax, 0)`                                           | Rounds each non-NULL excluding-tax amount to zero decimal places before aggregation, using PostgreSQL numeric rounding behavior for a compatible numeric input. NULL remains NULL.                    | Report excluding-tax sales in whole monetary units.                | Behavior: High; intent: Low    | Test fractional amounts, positive/negative midpoint values, and NULL values.                                                  |
| BR-013 41–42 | `s.tax_amount`, `s.total_including_tax`                                     | Passes the original tax and tax-inclusive amounts into aggregation without explicit rounding or adjustment.                                                                                           | Preserve original source values for these measures.                | Behavior: High; intent: Medium | Compare source tax and tax-inclusive values with the enrichment output.                                                       |
| BR-014 55    | `COUNT(*) AS sale_count`                                                    | Counts all rows after enrichment and joining, regardless of `sale_key` or amount NULLs. This is not a distinct sale or invoice count.                                                                 | Count sales transactions or reporting records.                     | Behavior: High; intent: Low    | Compare `COUNT(*)`, `COUNT(sale_key)`, and `COUNT(DISTINCT sale_key)` in controlled test data.                                |
| BR-015 57–58 | `SUM(sales_value) AS sales_excluding_tax`                                   | Sums the already rounded amounts. NULL inputs are ignored; a group with no non-NULL inputs returns NULL.                                                                                              | Calculate monthly excluding-tax revenue.                           | Behavior: High; intent: Medium | Compare `SUM(ROUND(amount,0))` with `ROUND(SUM(amount),0)` for fractional values.                                             |
| BR-016 60–61 | `SUM(tax_amount) AS tax_amount`                                             | Sums source tax amounts independently, ignoring NULL values. Returns NULL when all tax amounts in a group are NULL.                                                                                   | Report aggregated tax.                                             | Behavior: High; intent: Medium | Test mixed NULL/non-NULL tax values, all-NULL groups, and negative tax amounts.                                               |
| BR-017 63–64 | `SUM(total_including_tax) AS sales_including_tax`                           | Sums source tax-inclusive amounts independently, without recalculating them from the other measures.                                                                                                  | Report gross sales including tax.                                  | Behavior: High; intent: Medium | Compare reported gross amounts with the independent source total and with excluding-tax-plus-tax.                             |
| BR-018 50–71 | `GROUP BY invoice_month, customer_group, item_group`                        | Produces one row per distinct three-dimensional combination. Different source sales can be combined; no other business dimensions are retained.                                                       | Provide a monthly reporting summary by customer and item category. | Behavior: High; intent: Medium | Create transactions that share the three grouping values but differ in customer, item, or sale identifier.                    |
| BR-019 55–71 | `COUNT(*)`, `SUM(...)`, `GROUP BY ...`                                      | Groups NULL dimension values together. Count can be positive while one or more sums are NULL. Aggregates do not need to reconcile arithmetically.                                                     | No independent intent can be established.                          | Behavior: High; intent: Low    | Use groups with NULL dates and amounts; test mixed and all-NULL monetary inputs.                                              |
| BR-020 13–71 | `FROM legacy.sales_v1` through final `GROUP BY` with no `WHERE` or `HAVING` | The view applies no additional inclusion/exclusion criteria for dates, zero amounts, returns, status, cancellation, or soft deletion. Any exclusion must occur upstream or through another mechanism. | Possibly rely on `sales_v1` to contain only reportable records.    | Behavior: High; intent: Low    | Inspect the upstream view definition when available; reconcile source rows against business-approved reportable transactions. |

Catalogue coverage: 20 identified rules covering object creation, source selection, projection, join cardinality, mapping fallback, date adjustments, customer grouping, rounding, counting, summation, NULL behavior, grouping, and explicit absence of filters.

## 4. Detailed behavior and edge-case evidence

### 4.1 Invoice-month transformation

The SQL uses:

```
DATE_TRUNC(
    'month',
    s.invoice_date + INTERVAL '1 day'
)::DATE AS invoice_month
```

For ordinary date-valued inputs, the one-day adjustment moves the final calendar day of each month into the next reporting month.

| Source invoice date | Shifted date | Output invoice_month |
| ------------------- | ------------ | -------------------- |
| 2024-01-01          | 2024-01-02   | 2024-01-01           |
| 2024-01-30          | 2024-01-31   | 2024-01-01           |
| 2024-01-31          | 2024-02-01   | 2024-02-01           |
| 2024-02-28          | 2024-02-29   | 2024-02-01           |
| 2024-02-29          | 2024-03-01   | 2024-03-01           |
| 2024-12-31          | 2025-01-01   | 2025-01-01           |
| NULL                | NULL         | NULL                 |

These are derived examples of PostgreSQL date behavior, not observations from production records. Timestamp types and session time zone may introduce additional considerations.

Date transformation explorer

Illustrative

Test invoice date

2024-01-30 — Day before month-end

2024-01-31 — Month-end

2024-02-28 — Leap-year February 28

2024-02-29 — Leap day

2024-12-31 — Year-end

Normal calendar month

## 2024-01-01

Actual SQL reporting month

## 2024-02-01

This date is assigned to a different reporting month. The intermediate date is 2024-02-01.

Interpretation: The SQL conclusively implements the shift. Whether this is a business calendar convention or an unintended shift remains unverified.

### 4.2 Customer classification and NULL handling

The classification expression is:

```
CASE
    WHEN s.customer_key = 0
        THEN 'UNKNOWN'
    ELSE 'NONZERO'
END
```

| `customer_key` | Comparison result | Output    |
| -------------- | ----------------- | --------- |
| `0`            | TRUE              | `UNKNOWN` |
| `15`           | FALSE             | `NONZERO` |
| `-1`           | FALSE             | `NONZERO` |
| `NULL`         | UNKNOWN           | `NONZERO` |

PostgreSQL's three-valued logic means a NULL comparison does not satisfy the `WHEN` condition. Thus, `ELSE` handles both FALSE and UNKNOWN.

The label `NONZERO` does not prove that a customer key is populated or nonzero. It only indicates that the equality test against zero did not return TRUE.

This is a potential semantic mismatch, not proof of a defect.

### 4.3 Mapping cardinality and aggregation inflation

A `LEFT JOIN` does not guarantee one output row per source sale.

Consider this controlled example.

One source sale

| sale_key | stock_item_key | Amount |
| -------- | -------------- | ------ |
| 101      | 50             | 100    |

Two matching map rows

| stock_item_key | item_group |
| -------------- | ---------- |
| 50             | A          |
| 50             | B          |

After joining, the single sale becomes two enriched rows:

| sale_key | item_group | sales_value |
| -------- | ---------- | ----------- |
| 101      | A          | 100         |
| 101      | B          | 100         |

Both contribute to final aggregation.

Distinct source sale keys

# 1

Total joined row count

# 2

If the map has two rows both labeled `A`, the two joined rows are combined into one output group with `sale_count = 2` and `sales_excluding_tax = 200`.

Neither situation is prevented by the SQL. Whether it can occur in production depends on constraints and mapping data that have not been provided.

### 4.4 Rounding before aggregation

The SQL implements:

```
SUM(ROUND(s.total_excluding_tax, 0))
```

It does not implement:

```
ROUND(SUM(s.total_excluding_tax), 0)
```

These are not generally equivalent.

For example, with two amounts of `10.49`:

| Calculation                       | Result |
| --------------------------------- | ------ |
| `ROUND(10.49,0) + ROUND(10.49,0)` | 20     |
| `ROUND(10.49 + 10.49,0)`          | 21     |
| Unrounded source sum              | 20.98  |

This discrepancy can accumulate with transaction volume. PostgreSQL numeric rounding also requires testing at positive and negative midpoint values when matching its behavior in a target engine.

The view does not calculate `sales_including_tax` from its other aggregates, so the displayed measures are not guaranteed to satisfy:

`sales_excluding_tax + tax_amount = sales_including_tax`

That does not necessarily indicate corrupt financial data. The measures may be individually valid but intentionally presented at different precisions.

## 5. Migration risk register

The following risks describe plausible consequences of the observed SQL. Ratings indicate potential impact if the relevant assumption is false, not confirmed production defects.

| Risk ID | Related rules          | Risk and supporting evidence                                                                         | Potential impact                                                                              | Priority               |
| ------- | ---------------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ---------------------- |
| RISK-01 | BR-007–009             | Invoice dates are shifted before monthly truncation. The final calendar day moves to the next month. | Incorrect month-end reporting if not an approved reporting convention.                        | High                   |
| RISK-02 | BR-004–005, BR-014–017 | The item mapping join can return multiple matches per sale.                                          | Inflated counts, tax, and sales amounts.                                                      | High                   |
| RISK-03 | BR-010–011             | NULL customer keys fall into `NONZERO`.                                                              | Misleading customer classifications if NULL means unknown.                                    | Medium                 |
| RISK-04 | BR-012, BR-015         | Excluding-tax amounts are rounded individually before summation.                                     | Differences from financial control totals or differently rounded reporting systems.           | High                   |
| RISK-05 | BR-013, BR-015–017     | Excluding-tax, tax, and including-tax amounts use different calculation paths.                       | Financial reconciliation differences.                                                         | High                   |
| RISK-06 | BR-014, BR-003         | `COUNT(*)` does not enforce unique sales and includes duplicate join results.                        | Misleading transaction volumes.                                                               | High                   |
| RISK-07 | BR-006                 | `UNMAPPED` combines missing matches, matched NULL groups, and potentially literal `UNMAPPED` values. | Loss of data-quality distinctions.                                                            | Medium                 |
| RISK-08 | BR-009, BR-019         | NULL dates and NULL amounts are not rejected. SUM ignores NULL values.                               | Unassigned periods, incomplete totals, or NULL financial measures.                            | Medium                 |
| RISK-09 | BR-002, BR-020         | No explicit transaction, status, or period filters.                                                  | Inclusion of unintended record types if upstream does not exclude them.                       | High                   |
| RISK-10 | BR-005                 | Mapping uses only the item key, without effective-date or version selection.                         | Historical sales could receive incorrect or multiple categories if mapping is time-dependent. | High, conditional      |
| RISK-11 | BR-018                 | Grouping excludes other possible dimensions, such as currency, company, or transaction type.         | Inappropriate aggregation if the source contains values that should be separated.             | Medium, conditional    |
| RISK-12 | BR-007–008, BR-012     | Source data types and PostgreSQL-specific date/rounding semantics are unknown.                       | Behavioral divergence when translating to the chosen Fabric SQL engine.                       | High                   |
| RISK-13 | BR-002, BR-003         | `legacy.sales_v1` and the mapping object's internal definitions and constraints are unavailable.     | Undetected upstream transformations, filtering, or source duplication.                        | High, unknown exposure |

### 5.1 Logical contradictions and suspicious constructs

Customer classification label versus actual NULL behavior

`NONZERO` includes NULL keys, although NULL is not evidence of a nonzero value. This is a semantic inconsistency between the label and its population, but not necessarily an incorrect business rule.

Financial measures with different precision policies

The reported excluding-tax amount is rounded per row, but tax and including-tax amounts are not explicitly rounded. The measures can disagree when added together. A reconciliation expectation is not stated in the SQL.

Count naming versus counting mechanism

`sale_count` counts enriched rows, not necessarily unique source sales. The label is justified only if the joined dataset contains exactly one row per intended sale.

### 5.2 Unreachable branch assessment

No CASE branch is provably unreachable from the SQL alone.

| Branch or fallback             | Reachability assessment                                             | Required evidence                           |
| ------------------------------ | ------------------------------------------------------------------- | ------------------------------------------- |
| `customer_key = 0` → `UNKNOWN` | Reachable for a zero value, unless source constraints prevent zero. | Customer-key constraints and data profiling |
| `ELSE 'NONZERO'`               | Reachable for any nonzero or NULL customer key.                     | Customer-key distribution                   |
| `COALESCE(..., 'UNMAPPED')`    | Reachable when no mapping exists or the mapped group is NULL.       | Mapping completeness and NULL constraints   |

There is no evidence of a syntactically impossible condition, an overridden CASE branch, or a logically contradictory pair of CASE predicates.

The primary concern is potential misclassification, not branch reachability.

### 5.3 Silent exclusion assessment

It is important to distinguish dropped rows from ignored values.

| Mechanism                                 | Observed behavior                                                                           |
| ----------------------------------------- | ------------------------------------------------------------------------------------------- |
| Missing item mapping                      | Source sale retained through `LEFT JOIN`.                                                   |
| NULL `stock_item_key`                     | Cannot match through ordinary equality; source sale retained and classified using fallback. |
| NULL `invoice_date`                       | Row retained and assigned to NULL-month grouping.                                           |
| NULL `customer_key`                       | Row retained and assigned to `NONZERO`.                                                     |
| NULL monetary value                       | Row retained and counted, but that measure contributes nothing to its SUM.                  |
| All monetary inputs NULL in a group       | The corresponding SUM returns NULL, not zero.                                               |
| Negative or zero source amount            | Included; there is no exclusion predicate.                                                  |
| Source records excluded within `sales_v1` | Unknown, because the upstream definition is not supplied.                                   |

Finding: This view does not expressly drop sales through filtering or missing mapping matches. The most significant silent-exclusion risk is the independent omission of NULL amounts from aggregates.

### 5.4 Assumptions requiring confirmation

The following assumptions would need to hold for the view to produce conventional monthly sales reporting results:

- Each intended sale contributes exactly one source row, or source row count is the approved count measure.
- The item mapping is unique per stock item, or multiple matches are intentional.
- The one-day invoice shift is an approved month-allocation rule.
- Customer key zero is an approved unknown-customer sentinel, and NULL handling is acceptable.
- Source records are already limited to the required reporting population.
- Amounts are in compatible units and currencies for aggregation.
- The rounding policy is approved for excluding-tax sales.
- NULL financial and classification fields have defined reporting meanings.
- The same PostgreSQL data type, precision, calendar, and NULL semantics can be reproduced in Fabric.

None of these assumptions is established by the supplied SQL.

## 6. Questions for the business owner

Questions are ordered to address the potentially highest-impact financial and classification risks first.

| ID  | Business question                                                                                                         | Related risks       | Decision needed                                            |
| --- | ------------------------------------------------------------------------------------------------------------------------- | ------------------- | ---------------------------------------------------------- |
| Q01 | Why is one day added to the invoice date before assigning the reporting month?                                            | RISK-01             | Confirm calendar rule or identify legacy workaround.       |
| Q02 | Should sales on the last calendar day be reported in the current month or following month?                                | RISK-01             | Define expected period allocation, including year-end.     |
| Q03 | What is the intended meaning of `sale_count`—source rows, distinct sales, or distinct invoices?                           | RISK-02, 06         | Define the counting grain.                                 |
| Q04 | Must each stock item have exactly one item-group classification? Can classifications change over time?                    | RISK-02, 10         | Define mapping cardinality and historical attribution.     |
| Q05 | Does `customer_key = 0` officially mean unknown? How should NULL customer keys be classified?                             | RISK-03             | Approve the customer classification policy.                |
| Q06 | Why is excluding-tax sales rounded per transaction while tax and including-tax amounts are not?                           | RISK-04, 05         | Approve precision and rounding rules.                      |
| Q07 | Must `sales_excluding_tax + tax_amount` reconcile exactly to `sales_including_tax`? If not, what tolerance is acceptable? | RISK-05             | Specify reconciliation requirements.                       |
| Q08 | Which transactions belong in the report—completed sales, credits, returns, cancellations, adjustments, or all records?    | RISK-09             | Define inclusion criteria and the authoritative source.    |
| Q09 | Should missing item mappings and explicit NULL item groups be reported together as `UNMAPPED`?                            | RISK-07             | Define classification exceptions.                          |
| Q10 | What should happen to records with NULL invoice dates or monetary amounts?                                                | RISK-08             | Define reject, retain, or exception-reporting behavior.    |
| Q11 | Can `sales_v1` contain multiple currencies, companies, or other populations that must not be aggregated together?         | RISK-11             | Confirm required reporting dimensions and currency basis.  |
| Q12 | Which existing financial report or control total is the authoritative reconciliation baseline?                            | RISK-04, 05, 06, 13 | Identify business acceptance evidence.                     |
| Q13 | Are the existing behaviors contractual requirements, or is the Fabric migration expected to address known legacy issues?  | All                 | Separate compatibility requirements from approved changes. |

## 7. Proposed validation and acceptance approach

This is a validation plan, not a proposed SQL rewrite.

| Validation area          | Test evidence                                                  | Acceptance criterion requiring confirmation                              |
| ------------------------ | -------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Source population        | Source-to-view row lineage and transaction-type breakdown      | All intended records included once, subject to approved mapping behavior |
| Date allocation          | Month-end, year-end, leap-year, NULL and timestamp test cases  | Reporting months match approved calendar                                 |
| Mapping integrity        | Duplicate-key counts, unmapped-key counts, historical mappings | Mapping cardinality and historical classification approved               |
| Customer grouping        | Counts for zero, nonzero and NULL customer keys                | Classification matches approved definitions                              |
| Rounding                 | Fractional, negative, midpoint and high-volume test data       | Exact rounding policy and precision confirmed                            |
| Financial reconciliation | Raw totals versus legacy aggregates and Fabric aggregates      | Approved tolerances and calculation basis documented                     |
| NULL handling            | Partial and all-NULL groups                                    | Defined reporting results for each missing-data condition                |
| Platform compatibility   | Matching PostgreSQL and Fabric input datasets                  | Equivalent results for all rules designated for preservation             |

For the migration baseline, compare results at both the final three-column reporting grain and at intermediate row level. A final aggregated comparison alone may conceal offsetting errors—for example, duplicate mapping amounts in one category and missing amounts in another.

### Final assessment

The source establishes 20 observable processing rules and 13 areas of migration risk. The strongest candidates for business review are the one-day month shift, customer NULL classification, join multiplicity, per-row rounding, and counting grain.

There is no sufficient evidence to conclude that these are defects. Some could represent legitimate reporting conventions.

The appropriate next step is to classify each rule as preserve, change with business approval, or pending evidence. Until then, the SQL should remain the documented legacy behavioral baseline, without automatic corrections.