CREATE TABLE dbo.llr_defect_evidence_v1
AS
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
    AND t.defect_id = d.defect_id;
