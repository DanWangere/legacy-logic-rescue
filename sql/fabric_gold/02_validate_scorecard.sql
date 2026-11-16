-- Legacy Logic Rescue
-- Scorecard value-level reconciliation

WITH silver AS (
    SELECT
        benchmark_id,
        known_defects,
        detected_defects,
        missed_defects,
        unassessed_defects,
        CASE
            WHEN unassessed_defects = 0
            THEN CAST(detection_recall_pct AS DECIMAL(5,2))
            ELSE CAST(NULL AS DECIMAL(5,2))
        END AS detection_recall_pct
    FROM [lh_llr_silver].[dbo].[llr_ai_benchmark_scorecard_v1]
),

gold AS (
    SELECT
        benchmark_id,
        known_defects,
        detected_defects,
        missed_defects,
        unassessed_defects,
        CAST(detection_recall_pct AS DECIMAL(5,2))
            AS detection_recall_pct
    FROM dbo.llr_ai_benchmark_scorecard_v1
),

silver_only AS (
    SELECT * FROM silver
    EXCEPT
    SELECT * FROM gold
),

gold_only AS (
    SELECT * FROM gold
    EXCEPT
    SELECT * FROM silver
)

SELECT
    'Missing or different in Gold' AS check_name,
    COUNT_BIG(*) AS mismatch_count
FROM silver_only

UNION ALL

SELECT
    'Unexpected or different in Gold',
    COUNT_BIG(*)
FROM gold_only;
