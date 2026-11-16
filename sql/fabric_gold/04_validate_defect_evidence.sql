-- Legacy Logic Rescue
-- Defect evidence: Silver-to-Gold reconciliation

WITH silver_expected AS (
    SELECT
        t.benchmark_id,
        t.defect_id,
        t.defect_name,
        t.source_expression,
        t.measured_impact,
        t.evidence_reference,
        d.ai_rule_references,
        d.detection_status,
        d.review_notes,
        d.ai_response_reference,
        CASE
            WHEN d.detection_status = 'DETECTED'
                THEN 'MATCHED_TO_GROUND_TRUTH'
            WHEN d.detection_status = 'MISSED'
                THEN 'REVIEWED_MISS'
            ELSE 'UNASSESSED'
        END AS review_outcome
    FROM [lh_llr_silver].[dbo].[llr_benchmark_truth_v1] t
    LEFT JOIN
        [lh_llr_silver].[dbo].[llr_ai_detection_review_v1] d
        ON t.benchmark_id = d.benchmark_id
       AND t.defect_id = d.defect_id
),

gold_actual AS (
    SELECT
        benchmark_id,
        defect_id,
        defect_name,
        source_expression,
        measured_impact,
        evidence_reference,
        ai_rule_references,
        detection_status,
        review_notes,
        ai_response_reference,
        review_outcome
    FROM dbo.llr_defect_evidence_v1
),

silver_only AS (
    SELECT * FROM silver_expected
    EXCEPT
    SELECT * FROM gold_actual
),

gold_only AS (
    SELECT * FROM gold_actual
    EXCEPT
    SELECT * FROM silver_expected
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
