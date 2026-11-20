-- 05_category_performance.sql
-- Revenue, lateness and satisfaction by product category (top 15 by revenue).

SELECT category,
       COUNT(*)                                   AS orders,
       ROUND(SUM(items_value), 0)                 AS revenue_brl,
       ROUND(AVG(items_value), 2)                 AS avg_order_value_brl,
       ROUND(100.0 * AVG(freight_ratio), 1)       AS avg_freight_pct_of_price,
       ROUND(100.0 * AVG(is_late), 1)             AS pct_late,
       ROUND(AVG(review_score), 2)                AS avg_review
FROM order_level
GROUP BY category
ORDER BY revenue_brl DESC
LIMIT 15;
