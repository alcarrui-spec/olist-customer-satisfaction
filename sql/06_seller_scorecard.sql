-- 06_seller_scorecard.sql
-- Scorecard for sellers with 100+ delivered, reviewed orders.
-- Flags sellers whose late rate AND negative-review rate are both well
-- above the marketplace average (candidates for an operations review).

WITH marketplace AS (
    SELECT AVG(is_late) AS avg_late,
           AVG(is_negative_review) AS avg_negative
    FROM order_level
),
seller_stats AS (
    SELECT seller_id,
           seller_state,
           COUNT(*)                         AS orders,
           ROUND(SUM(items_value), 0)       AS revenue_brl,
           AVG(is_late)                     AS late_rate,
           AVG(is_negative_review)          AS negative_rate,
           ROUND(AVG(review_score), 2)      AS avg_review
    FROM order_level
    GROUP BY seller_id, seller_state
    HAVING COUNT(*) >= 100
)
SELECT s.seller_id,
       s.seller_state,
       s.orders,
       s.revenue_brl,
       ROUND(100.0 * s.late_rate, 1)        AS pct_late,
       ROUND(100.0 * s.negative_rate, 1)    AS pct_negative_reviews,
       s.avg_review,
       CASE WHEN s.late_rate     >= 1.5 * m.avg_late
             AND s.negative_rate >= 1.5 * m.avg_negative
            THEN 'Review operations' ELSE 'OK' END AS flag,
       RANK() OVER (ORDER BY s.revenue_brl DESC) AS revenue_rank
FROM seller_stats AS s
CROSS JOIN marketplace AS m
ORDER BY flag DESC, s.revenue_brl DESC;
