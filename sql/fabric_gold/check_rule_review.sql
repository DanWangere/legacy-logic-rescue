-- Check rule review coverage

SELECT
    review_state,
    COUNT(*) AS rule_count
FROM dbo.llr_rule_catalogue_gold_v1
GROUP BY review_state
ORDER BY review_state;
