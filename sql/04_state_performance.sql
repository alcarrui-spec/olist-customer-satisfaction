-- 04_state_performance.sql
-- Delivery speed, lateness and satisfaction by customer state.
-- States with fewer than 500 orders are excluded so rates are stable.

WITH state_stats AS (
    SELECT customer_state,
           COUNT(*)                                  AS orders,
           ROUND(AVG(delivery_days), 1)              AS avg_delivery_days,
           ROUND(100.0 * AVG(is_late), 1)            AS pct_late,
           ROUND(AVG(review_score), 2)               AS avg_review,
           ROUND(100.0 * AVG(is_negative_review), 1) AS pct_negative_reviews,
           ROUND(100.0 * AVG(same_state), 1)         AS pct_same_state_seller
    FROM order_level
    GROUP BY customer_state
    HAVING COUNT(*) >= 500
)
SELECT *,
       RANK() OVER (ORDER BY pct_late DESC) AS late_rank
FROM state_stats
ORDER BY pct_late DESC;
