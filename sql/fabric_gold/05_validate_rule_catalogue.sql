-- Legacy Logic Rescue
-- Rule catalogue: Silver-to-Gold reconciliation

WITH silver_expected AS (
    SELECT
        rule_id,
        source_expression,
        observed_behavior,
        technical_assessment,
        business_decision,
        evidence_reference,
        review_notes,
        reviewed_at,
        review_type,
        CASE
            WHEN business_decision = 'PENDING_REVIEW'
                THEN 'PENDING'
            ELSE 'REVIEWED'
        END AS review_state
    FROM [lh_llr_silver].[dbo].[llr_rule_catalogue_v1]
),

gold_actual AS (
    SELECT
        rule_id,
        source_expression,
        observed_behavior,
        technical_assessment,
        business_decision,
        evidence_reference,
        review_notes,
        reviewed_at,
        review_type,
        review_state
    FROM dbo.llr_rule_catalogue_gold_v1
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
