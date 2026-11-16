CREATE OR ALTER PROCEDURE dbo.usp_llr_refresh_gold
    @pipeline_run_id VARCHAR(100) = 'manual',
    @simulate_failure BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @started_at DATETIME2(6) = SYSUTCDATETIME();

    DECLARE @expected_scorecards BIGINT;
    DECLARE @expected_defects BIGINT;
    DECLARE @expected_rules BIGINT;

    DECLARE @scorecard_rows BIGINT = 0;
    DECLARE @defect_rows BIGINT = 0;
    DECLARE @rule_rows BIGINT = 0;

    BEGIN TRY

        -- 1. Check source availability.
        SELECT @expected_scorecards = COUNT_BIG(*)
        FROM [lh_llr_silver].[dbo].[llr_ai_benchmark_scorecard_v1];

        SELECT @expected_defects = COUNT_BIG(*)
        FROM [lh_llr_silver].[dbo].[llr_benchmark_truth_v1];

        SELECT @expected_rules = COUNT_BIG(*)
        FROM [lh_llr_silver].[dbo].[llr_rule_catalogue_v1];

        IF @expected_scorecards = 0
           OR @expected_defects = 0
           OR @expected_rules = 0
            THROW 51001, 'Gold refresh: source data is empty.', 1;

        -- 2. Check that source business keys are unique.
        IF EXISTS (
            SELECT benchmark_id
            FROM [lh_llr_silver].[dbo].[llr_ai_benchmark_scorecard_v1]
            GROUP BY benchmark_id
            HAVING COUNT_BIG(*) > 1
        )
            THROW 51002, 'Duplicate benchmark IDs.', 1;

        IF EXISTS (
            SELECT benchmark_id, defect_id
            FROM [lh_llr_silver].[dbo].[llr_benchmark_truth_v1]
            GROUP BY benchmark_id, defect_id
            HAVING COUNT_BIG(*) > 1
        )
            THROW 51003, 'Duplicate ground-truth defects.', 1;

        IF EXISTS (
            SELECT benchmark_id, defect_id
            FROM [lh_llr_silver].[dbo].[llr_ai_detection_review_v1]
            GROUP BY benchmark_id, defect_id
            HAVING COUNT_BIG(*) > 1
        )
            THROW 51004, 'Duplicate AI detection reviews.', 1;

        IF EXISTS (
            SELECT rule_id
            FROM [lh_llr_silver].[dbo].[llr_rule_catalogue_v1]
            GROUP BY rule_id
            HAVING COUNT_BIG(*) > 1
        )
            THROW 51005, 'Duplicate rule IDs.', 1;

        -- 3. Refresh all Gold tables atomically.
        BEGIN TRANSACTION;

        TRUNCATE TABLE dbo.llr_ai_benchmark_scorecard_v1;

        INSERT INTO dbo.llr_ai_benchmark_scorecard_v1 (
            benchmark_id,
            known_defects,
            detected_defects,
            missed_defects,
            unassessed_defects,
            detection_recall_pct
        )
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
            END
        FROM [lh_llr_silver].[dbo].[llr_ai_benchmark_scorecard_v1];

        -- Controlled failure injection for a later lab.
        IF @simulate_failure = 1
            THROW 51006, 'LLR_TEST: Simulated Gold refresh failure.', 1;

        TRUNCATE TABLE dbo.llr_defect_evidence_v1;

        INSERT INTO dbo.llr_defect_evidence_v1 (
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
        )
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
            END
        FROM [lh_llr_silver].[dbo].[llr_benchmark_truth_v1] t
        LEFT JOIN [lh_llr_silver].[dbo].[llr_ai_detection_review_v1] d
            ON t.benchmark_id = d.benchmark_id
           AND t.defect_id = d.defect_id;

        TRUNCATE TABLE dbo.llr_rule_catalogue_gold_v1;

        INSERT INTO dbo.llr_rule_catalogue_gold_v1 (
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
        )
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
            END
        FROM [lh_llr_silver].[dbo].[llr_rule_catalogue_v1];

        -- 4. Validate the refreshed row counts.
        SELECT @scorecard_rows = COUNT_BIG(*)
        FROM dbo.llr_ai_benchmark_scorecard_v1;

        SELECT @defect_rows = COUNT_BIG(*)
        FROM dbo.llr_defect_evidence_v1;

        SELECT @rule_rows = COUNT_BIG(*)
        FROM dbo.llr_rule_catalogue_gold_v1;

        IF @scorecard_rows <> @expected_scorecards
            THROW 51007, 'Scorecard reconciliation failed.', 1;

        IF @defect_rows <> @expected_defects
            THROW 51008, 'Defect reconciliation failed.', 1;

        ---IF @rule_rows <> @expected_rules
            ----THROW 51009, 'Rule catalogue reconciliation failed.', 1;

        -- 5. Publish all three tables together.
        ---COMMIT TRANSACTION;


        IF @rule_rows <> @expected_rules
            THROW 51009, 'Rule catalogue reconciliation failed.', 1;

-- Validate full Silver-to-Gold equality
-- while the reporting transaction is still open.
        EXEC dbo.usp_llr_validate_gold;

-- Only publish after all checks pass.
        COMMIT TRANSACTION;


        -- Audit success after the reporting transaction commits.
        INSERT INTO dbo.llr_gold_refresh_audit (
            pipeline_run_id, started_at, finished_at,
            status, scorecard_rows, defect_rows,
            rule_rows, error_message
        )
        VALUES (
            @pipeline_run_id, @started_at, SYSUTCDATETIME(),
            'SUCCEEDED', @scorecard_rows, @defect_rows,
            @rule_rows, NULL
        );

    END TRY

    BEGIN CATCH

        -- Undo incomplete reporting changes.
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Preserve failure information separately.
        INSERT INTO dbo.llr_gold_refresh_audit (
            pipeline_run_id, started_at, finished_at,
            status, scorecard_rows, defect_rows,
            rule_rows, error_message
        )
        VALUES (
            @pipeline_run_id, @started_at, SYSUTCDATETIME(),
            'FAILED', @scorecard_rows, @defect_rows,
            @rule_rows, LEFT(ERROR_MESSAGE(), 2000)
        );

        THROW;

    END CATCH
END;
