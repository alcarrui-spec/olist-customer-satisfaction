-- 03_late_delivery_impact.sql
-- How does delivery timing relative to the promised date affect reviews?
-- Requires the order_level table (built from 02_order_level_dataset.sql).

SELECT
    CASE
        WHEN days_vs_estimate <= -7 THEN '1. 7+ days early'
        WHEN days_vs_estimate <   0 THEN '2. 1-6 days early'
        WHEN days_vs_estimate =   0 THEN '3. On the promised day'
        WHEN days_vs_estimate <=  3 THEN '4. 1-3 days late'
        WHEN days_vs_estimate <=  7 THEN '5. 4-7 days late'
        ELSE                             '6. 8+ days late'
    END                                         AS delivery_bucket,
    COUNT(*)                                    AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders,
    ROUND(AVG(review_score), 2)                 AS avg_review,
    ROUND(100.0 * AVG(is_negative_review), 1)   AS pct_negative_reviews,
    ROUND(100.0 * AVG(CASE WHEN review_score = 5 THEN 1.0 ELSE 0 END), 1) AS pct_five_star
FROM order_level
GROUP BY delivery_bucket
ORDER BY delivery_bucket;
