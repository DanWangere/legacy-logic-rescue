-- Legacy Logic Rescue: Benchmark V2
-- Product reporting mappings

BEGIN;

DROP TABLE IF EXISTS legacy.item_group_map_v2;

CREATE TABLE legacy.item_group_map_v2 (
    stock_item_key INTEGER NOT NULL,
    item_group TEXT NOT NULL,
    rule_priority INTEGER NOT NULL
);

-- Generate standard reporting classifications
-- for all products in the frozen sales dataset.

INSERT INTO legacy.item_group_map_v2 (
    stock_item_key,
    item_group,
    rule_priority
)
SELECT DISTINCT
    stock_item_key,
    CASE
        WHEN MOD(stock_item_key, 2) = 0
            THEN 'CORE'
        ELSE 'SPECIAL'
    END,
    10
FROM legacy.sales_v1
WHERE stock_item_key IS NOT NULL;

-- Simulate a later, higher-priority classification
-- for one existing product.

INSERT INTO legacy.item_group_map_v2 (
    stock_item_key,
    item_group,
    rule_priority
)
SELECT
    MIN(stock_item_key),
    'PROMOTIONAL',
    20
FROM legacy.sales_v1
WHERE stock_item_key IS NOT NULL;

COMMIT;
