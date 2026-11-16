SELECT
    benchmark_id,
    known_defects,
    detected_defects,
    detection_recall_pct
FROM dbo.llr_ai_benchmark_scorecard_v1
ORDER BY benchmark_id;
