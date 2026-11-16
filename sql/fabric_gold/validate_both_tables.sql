-- Check defect evidence

SELECT
    benchmark_id,
    COUNT(*) AS defect_count,
    SUM(
        CASE
            WHEN detection_status = 'DETECTED' THEN 1
            ELSE 0
        END
    ) AS detected_count
FROM dbo.llr_defect_evidence_v1
GROUP BY benchmark_id
ORDER BY benchmark_id;
