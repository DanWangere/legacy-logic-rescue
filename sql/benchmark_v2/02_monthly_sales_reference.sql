-- Benchmark V2: Trusted reporting reference
-- One eligible mapping per product.

CREATE OR REPLACE VIEW
legacy.v_monthly_sales_reference_v2 AS

WITH ranked_mappings AS (
    SELECT
        stock_item_key,
        item_group,
        rule_priority,

        ROW_NUMBER() OVER (
            PARTITION BY stock_item_key
            ORDER BY rule_priority DESC, item_group
        ) AS rn

    FROM legacy.item_group_map_v2
)

SELECT
    DATE_TRUNC(
        'month',
        s.invoice_date
    )::DATE AS invoice_month,

    CASE
        WHEN s.customer_key = 0
            THEN 'UNKNOWN'
        ELSE 'NONZERO'
    END AS customer_group,

    COALESCE(
        m.item_group,
        'UNMAPPED'
    ) AS item_group,

    COUNT(*) AS sale_count,

    SUM(s.total_excluding_tax)
        AS sales_excluding_tax,

    SUM(s.tax_amount)
        AS tax_amount,

    SUM(s.total_including_tax)
        AS sales_including_tax

FROM legacy.sales_v1 s

LEFT JOIN ranked_mappings m
    ON s.stock_item_key = m.stock_item_key
    AND m.rn = 1

GROUP BY 1, 2, 3;
