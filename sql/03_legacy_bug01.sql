-- Legacy Logic Rescue
-- Defect: LLR-BUG-001
-- An undocumented filter excludes unknown customers.

CREATE OR REPLACE VIEW legacy.v_monthly_sales_bug01 AS

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

-- Deliberately planted defect:
WHERE customer_key <> 0

GROUP BY 1, 2;
