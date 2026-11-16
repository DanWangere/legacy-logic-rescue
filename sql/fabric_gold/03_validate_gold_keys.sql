-- Check for duplicated reporting keys

SELECT
    'Scorecard' AS dataset,
    COUNT_BIG(*) AS duplicate_key_groups
FROM (
    SELECT benchmark_id
    FROM dbo.llr_ai_benchmark_scorecard_v1
    GROUP BY benchmark_id
    HAVING COUNT_BIG(*) > 1
) s

UNION ALL

SELECT
    'Defect Evidence',
    COUNT_BIG(*)
FROM (
    SELECT benchmark_id, defect_id
    FROM dbo.llr_defect_evidence_v1
    GROUP BY benchmark_id, defect_id
    HAVING COUNT_BIG(*) > 1
) d

UNION ALL

SELECT
    'Rule Catalogue',
    COUNT_BIG(*)
FROM (
    SELECT rule_id
    FROM dbo.llr_rule_catalogue_gold_v1
    GROUP BY rule_id
    HAVING COUNT_BIG(*) > 1
) r;
