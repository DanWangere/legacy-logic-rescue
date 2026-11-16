SELECT
    benchmark_id,
    defect_id,
    defect_name,
    detection_status,
    review_outcome,
    measured_impact
FROM dbo.llr_defect_evidence_v1
ORDER BY benchmark_id, defect_id;
