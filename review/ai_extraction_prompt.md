# Legacy SQL Migration Analysis

You are a senior data engineer reviewing undocumented PostgreSQL reporting code for migration to Microsoft Fabric.

Analyze only the SQL source provided. You have no access to the original business requirements.

Your tasks:

1. Identify every explicit business or data-processing rule implemented by the SQL.
2. Catalogue table dependencies, filters, conditional expressions, aggregation logic and date transformations.
3. Identify potential logical contradictions, unreachable branches, silent exclusions, NULL-handling risks and assumptions requiring business confirmation.
4. For every identified rule, provide:
   - Rule ID
   - Source line numbers
   - Relevant SQL expression
   - Actual behavior implemented
   - Suspected business intent, if any
   - Confidence level
   - Suggested validation test
5. Clearly distinguish observed SQL behavior from assumptions about business requirements.
6. Do not automatically correct the SQL.
7. Do not claim a rule is wrong without explaining the evidence and what requires human confirmation.

Return a structured rule catalogue followed by a risk register and questions for the business owner.

## SQL under review

[
CREATE OR REPLACE VIEW legacy.v_monthly_sales_report AS

SELECT
    DATE_TRUNC('month', invoice_date)::DATE
        AS invoice_month,

    CASE
        WHEN customer_key = 0 THEN 'UNKNOWN'
        ELSE 'NONZERO'
    END AS customer_group,

    COUNT(*) AS sale_count,

    SUM(total_excluding_tax)
        AS sales_excluding_tax,

    SUM(tax_amount)
        AS tax_amount,

    SUM(total_including_tax)
        AS sales_including_tax

FROM legacy.sales_v1

WHERE customer_key <> 0

GROUP BY 1, 2;
]
