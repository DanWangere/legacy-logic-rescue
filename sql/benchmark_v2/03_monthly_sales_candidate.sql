CREATE OR REPLACE VIEW
legacy.v_monthly_sales_candidate_v2 AS

WITH sales_base AS (
    SELECT
        sale_key,
        customer_key,
        stock_item_key,
        invoice_date,
        total_excluding_tax,
        tax_amount,
        total_including_tax
    FROM legacy.sales_v1
),

enriched_sales AS (
    SELECT
        s.sale_key,

        DATE_TRUNC(
            'month',
            s.invoice_date + INTERVAL '1 day'
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

        ROUND(
            s.total_excluding_tax,
            0
        ) AS sales_value,

        s.tax_amount,
        s.total_including_tax

    FROM sales_base s

    LEFT JOIN legacy.item_group_map_v2 m
        ON s.stock_item_key = m.stock_item_key
)

SELECT
    invoice_month,
    customer_group,
    item_group,

    COUNT(*) AS sale_count,

    SUM(sales_value)
        AS sales_excluding_tax,

    SUM(tax_amount)
        AS tax_amount,

    SUM(total_including_tax)
        AS sales_including_tax

FROM enriched_sales

GROUP BY
    invoice_month,
    customer_group,
    item_group;
