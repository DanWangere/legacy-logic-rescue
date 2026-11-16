CREATE OR ALTER PROCEDURE dbo.usp_llr_validate_gold
AS
BEGIN
    SET NOCOUNT ON;

    -- =============================================
    -- 1. Gold business-key uniqueness checks
    -- =============================================

    IF EXISTS (
        SELECT benchmark_id
        FROM dbo.llr_ai_benchmark_scorecard_v1
        GROUP BY benchmark_id
        HAVING COUNT_BIG(*) > 1
    )
    BEGIN
        THROW 51101, 'Duplicate Gold benchmark IDs.', 1;
    END;

    IF EXISTS (
        SELECT benchmark_id, defect_id
        FROM dbo.llr_defect_evidence_v1
        GROUP BY benchmark_id, defect_id
        HAVING COUNT_BIG(*) > 1
    )
    BEGIN
        THROW 51102, 'Duplicate Gold defect keys.', 1;
    END;

    IF EXISTS (
        SELECT rule_id
        FROM dbo.llr_rule_catalogue_gold_v1
        GROUP BY rule_id
        HAVING COUNT_BIG(*) > 1
    )
    BEGIN
        THROW 51103, 'Duplicate Gold rule IDs.', 1;
    END;

    -- =============================================
    -- 2. Benchmark scorecard reconciliation
    -- =============================================

    IF EXISTS (
        SELECT
            benchmark_id, known_defects, detected_defects,
            missed_defects, unassessed_defects,
            CASE WHEN unassessed_defects = 0
                THEN CAST(detection_recall_pct AS DECIMAL(5,2))
                ELSE CAST(NULL AS DECIMAL(5,2))
            END
        FROM [lh_llr_silver].[dbo].[llr_ai_benchmark_scorecard_v1]

        EXCEPT

        SELECT
            benchmark_id, known_defects, detected_defects,
            missed_defects, unassessed_defects,
            CAST(detection_recall_pct AS DECIMAL(5,2))
        FROM dbo.llr_ai_benchmark_scorecard_v1
    )
    BEGIN
        THROW 51104, 'Scorecard: missing or different in Gold.', 1;
    END;

    IF EXISTS (
        SELECT
            benchmark_id, known_defects, detected_defects,
            missed_defects, unassessed_defects,
            CAST(detection_recall_pct AS DECIMAL(5,2))
        FROM dbo.llr_ai_benchmark_scorecard_v1

        EXCEPT

        SELECT
            benchmark_id, known_defects, detected_defects,
            missed_defects, unassessed_defects,
            CASE WHEN unassessed_defects = 0
                THEN CAST(detection_recall_pct AS DECIMAL(5,2))
                ELSE CAST(NULL AS DECIMAL(5,2))
            END
        FROM [lh_llr_silver].[dbo].[llr_ai_benchmark_scorecard_v1]
    )
    BEGIN
        THROW 51105, 'Scorecard: unexpected or different in Gold.', 1;
    END;

    -- =============================================
    -- 3. Defect evidence reconciliation
    -- =============================================

    IF EXISTS (
        SELECT
            t.benchmark_id, t.defect_id, t.defect_name,
            t.source_expression, t.measured_impact,
            t.evidence_reference, d.ai_rule_references,
            d.detection_status, d.review_notes,
            d.ai_response_reference,
            CASE
                WHEN d.detection_status = 'DETECTED'
                    THEN 'MATCHED_TO_GROUND_TRUTH'
                WHEN d.detection_status = 'MISSED'
                    THEN 'REVIEWED_MISS'
                ELSE 'UNASSESSED'
            END
        FROM [lh_llr_silver].[dbo].[llr_benchmark_truth_v1] t
        LEFT JOIN [lh_llr_silver].[dbo].[llr_ai_detection_review_v1] d
            ON t.benchmark_id = d.benchmark_id
           AND t.defect_id = d.defect_id

        EXCEPT

        SELECT
            benchmark_id, defect_id, defect_name,
            source_expression, measured_impact,
            evidence_reference, ai_rule_references,
            detection_status, review_notes,
            ai_response_reference, review_outcome
        FROM dbo.llr_defect_evidence_v1
    )
    BEGIN
        THROW 51106, 'Defect evidence: missing or different in Gold.', 1;
    END;

    IF EXISTS (
        SELECT
            benchmark_id, defect_id, defect_name,
            source_expression, measured_impact,
            evidence_reference, ai_rule_references,
            detection_status, review_notes,
            ai_response_reference, review_outcome
        FROM dbo.llr_defect_evidence_v1

        EXCEPT

        SELECT
            t.benchmark_id, t.defect_id, t.defect_name,
            t.source_expression, t.measured_impact,
            t.evidence_reference, d.ai_rule_references,
            d.detection_status, d.review_notes,
            d.ai_response_reference,
            CASE
                WHEN d.detection_status = 'DETECTED'
                    THEN 'MATCHED_TO_GROUND_TRUTH'
                WHEN d.detection_status = 'MISSED'
                    THEN 'REVIEWED_MISS'
                ELSE 'UNASSESSED'
            END
        FROM [lh_llr_silver].[dbo].[llr_benchmark_truth_v1] t
        LEFT JOIN [lh_llr_silver].[dbo].[llr_ai_detection_review_v1] d
            ON t.benchmark_id = d.benchmark_id
           AND t.defect_id = d.defect_id
    )
    BEGIN
        THROW 51107, 'Defect evidence: unexpected or different in Gold.', 1;
    END;

    -- =============================================
    -- 4. Rule catalogue reconciliation
    -- =============================================

    IF EXISTS (
        SELECT
            rule_id, source_expression, observed_behavior,
            technical_assessment, business_decision,
            evidence_reference, review_notes,
            reviewed_at, review_type,
            CASE
                WHEN business_decision = 'PENDING_REVIEW'
                    THEN 'PENDING'
                ELSE 'REVIEWED'
            END
        FROM [lh_llr_silver].[dbo].[llr_rule_catalogue_v1]

        EXCEPT

        SELECT
            rule_id, source_expression, observed_behavior,
            technical_assessment, business_decision,
            evidence_reference, review_notes,
            reviewed_at, review_type, review_state
        FROM dbo.llr_rule_catalogue_gold_v1
    )
    BEGIN
        THROW 51108, 'Rule catalogue: missing or different in Gold.', 1;
    END;

    IF EXISTS (
        SELECT
            rule_id, source_expression, observed_behavior,
            technical_assessment, business_decision,
            evidence_reference, review_notes,
            reviewed_at, review_type, review_state
        FROM dbo.llr_rule_catalogue_gold_v1

        EXCEPT

        SELECT
            rule_id, source_expression, observed_behavior,
            technical_assessment, business_decision,
            evidence_reference, review_notes,
            reviewed_at, review_type,
            CASE
                WHEN business_decision = 'PENDING_REVIEW'
                    THEN 'PENDING'
                ELSE 'REVIEWED'
            END
        FROM [lh_llr_silver].[dbo].[llr_rule_catalogue_v1]
    )
    BEGIN
        THROW 51109, 'Rule catalogue: unexpected or different in Gold.', 1;
    END;

    PRINT 'PASS: All Gold value and uniqueness checks passed.';
END;
