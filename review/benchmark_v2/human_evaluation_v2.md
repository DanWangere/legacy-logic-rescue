
# Benchmark V2 — Human Evaluation

## Evaluation status
COMPLETED — Initial seeded-defect assessment

## Input
sql/benchmark_v2/03_monthly_sales_candidate.sql

## Raw AI output
review/benchmark_v2/ai_first_pass_response_v2.md

## Ground truth
evidence/benchmark_v2/ground_truth_v2.md

## Results

| Defect | AI finding | Result |
|---|---|---|
| V2-DEFECT-001: Join multiplication | BR-004, BR-005 | DETECTED |
| V2-DEFECT-002: Month shifting | BR-007, BR-008 | DETECTED |
| V2-DEFECT-003: Premature rounding | BR-012, BR-015 | DETECTED |

## Detection metrics

Known seeded defects: 3
Detected seeded defects: 3
Missed seeded defects: 0
Detection recall: 100%

Extracted rule candidates: 20
Additional risk candidates: 13

Precision: NOT YET SCORED
Unsupported-claim rate: NOT YET SCORED

## Independently verified impacts

Join multiplication:
- Additional joined rows: 1,250

Reporting date shift:
- Transactions assigned to a different month: 8,306

Premature rounding:
- Difference on original sales: 2,390.20

Combined candidate discrepancy:
- Excess records: 1,250
- Excess ex-tax revenue: 3,592,390.20
- Excess inc-tax revenue: 4,128,500.00

Individual financial contributions and interactions
have not yet been fully isolated.

## Human assessment

The model successfully identified all three seeded
issues and provided relevant SQL evidence.

It correctly distinguished observed implementation
behavior from unconfirmed business requirements.

Additional conditional risks require independent
review before classification as defects.

## Limitations

One SQL benchmark does not establish general
AI migration reliability.

The evaluation does not establish precision or
false-positive rates across all extracted findings.

The model did not have access to source data,
table constraints or approved business requirements.

## Overall conclusion

PASS: Seeded-defect detection benchmark.

PENDING: Complete candidate review, false-positive
assessment and automated Fabric evaluation.
