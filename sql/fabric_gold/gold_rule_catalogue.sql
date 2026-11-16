CREATE TABLE dbo.llr_rule_catalogue_gold_v1
AS
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

FROM [lh_llr_silver].[dbo].[llr_rule_catalogue_v1];
