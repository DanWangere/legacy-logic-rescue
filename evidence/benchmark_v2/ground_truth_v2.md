
# Legacy Logic Rescue — Benchmark V2 Ground Truth

## Benchmark objective

Evaluate AI-assisted extraction of legacy SQL business
logic and identification of potentially defective behavior.

## Trusted reference

- Sales records: 250,754
- Revenue excluding tax: 181,047,251.80
- Revenue including tax: 208,204,367.03

## Candidate implementation

- Sales records: 252,004
- Revenue excluding tax: 184,639,642.00
- Revenue including tax: 212,332,867.03
- Reporting groups: 70

## Overall discrepancies

- Additional records: 1,250
- Excess revenue excluding tax: 3,592,390.20
- Excess revenue including tax: 4,128,500.00

## Ground-truth findings

### V2-DEFECT-001: Join multiplication

Cause:
LEFT JOIN to item_group_map_v2 without selecting
the highest-priority mapping.

Independent verification:
- Joined rows: 252,004
- Distinct sales: 250,754
- Additional rows: 1,250

Expected behavior:
Each sales transaction contributes exactly once.

### V2-DEFECT-002: Incorrect reporting month

Cause:
invoice_date + INTERVAL '1 day' before
calendar-month aggregation.

Independent verification:
- Sales assigned to different months: 8,306

Expected behavior:
Use the original invoice date without shifting it.

### V2-DEFECT-003: Premature financial rounding

Cause:
ROUND(total_excluding_tax, 0)
before aggregating revenue.

Independent verification on original sales records:
- Original revenue: 181,047,251.80
- Rounded revenue: 181,049,642.00
- Rounding difference: +2,390.20

Expected behavior:
Preserve source decimal precision during aggregation.

Note:
The rounding test excludes join multiplication.
The combined candidate discrepancy must not be
attributed to individual defects without checking
their interactions.

## Evaluation requirements

The AI should:
1. Identify the unguarded one-to-many join risk.
2. Identify the one-day reporting-date shift.
3. Identify rounding before aggregation.
4. Explain each finding using SQL evidence.
5. Distinguish observed behavior from business intent.
6. Avoid unsupported assumptions.

## Important

This ground-truth document must NOT be supplied
to the AI during blind extraction.
