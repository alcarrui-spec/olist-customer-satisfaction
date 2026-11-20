-- 02_order_level_dataset.sql
-- Builds ONE row per delivered, reviewed order by joining 7 tables.
-- This is the main dataset the Python analysis uses.
--
-- Grain problem this query solves:
--   orders      : 1 row per order
--   order_items : many rows per order (one per item)
--   payments    : many rows per order (split payments)
--   reviews     : usually 1 per order, but 547 orders have 2+
-- Joining these directly would multiply rows and inflate totals, so each
-- one is first collapsed to one row per order in its own CTE.
--
-- MATERIALIZED tells SQLite to compute each CTE once and index it, which
-- turns a multi-minute nested-loop join into a ~3-second query.

WITH latest_review AS MATERIALIZED (
    -- Keep the most recent review per order (window function + filter)
    SELECT order_id, review_score, review_comment_message
    FROM (
        SELECT r.*,
               ROW_NUMBER() OVER (
                   PARTITION BY order_id
                   ORDER BY review_answer_timestamp DESC, review_creation_date DESC
               ) AS rn
        FROM reviews AS r
    )
    WHERE rn = 1
),

items_per_order AS MATERIALIZED (
    -- Collapse items to one row per order
    SELECT order_id,
           COUNT(*)                   AS n_items,
           COUNT(DISTINCT seller_id)  AS n_sellers,
           COUNT(DISTINCT product_id) AS n_products,
           SUM(price)                 AS items_value,
           SUM(freight_value)         AS freight_value
    FROM order_items
    GROUP BY order_id
),

main_item AS MATERIALIZED (
    -- The order's most expensive item decides its category and seller
    SELECT order_id, product_id, seller_id
    FROM (
        SELECT oi.order_id, oi.product_id, oi.seller_id,
               ROW_NUMBER() OVER (
                   PARTITION BY oi.order_id
                   ORDER BY oi.price DESC, oi.order_item_id
               ) AS rn
        FROM order_items AS oi
    )
    WHERE rn = 1
),

payments_per_order AS MATERIALIZED (
    -- Collapse split payments to one row per order; the payment type that
    -- paid the most is picked with a window function
    SELECT order_id,
           SUM(payment_value)        AS payment_value,
           MAX(payment_installments) AS installments,
           MAX(CASE WHEN rn = 1 THEN payment_type END) AS main_payment_type
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY order_id
                   ORDER BY payment_value DESC, payment_sequential
               ) AS rn
        FROM payments AS p
    )
    GROUP BY order_id
)

SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    s.seller_id,
    s.seller_state,
    COALESCE(t.product_category_name_english, 'unknown')      AS category,
    DATE(o.order_purchase_timestamp)                          AS purchase_date,
    STRFTIME('%Y-%m', o.order_purchase_timestamp)             AS purchase_month,

    -- Delivery timing (julianday() returns days, so differences are in days)
    ROUND(JULIANDAY(o.order_delivered_customer_date)
        - JULIANDAY(o.order_purchase_timestamp), 2)           AS delivery_days,
    ROUND(JULIANDAY(o.order_estimated_delivery_date)
        - JULIANDAY(o.order_purchase_timestamp), 2)           AS promised_days,
    ROUND(JULIANDAY(DATE(o.order_delivered_customer_date))
        - JULIANDAY(DATE(o.order_estimated_delivery_date)), 0) AS days_vs_estimate,
    CASE WHEN DATE(o.order_delivered_customer_date)
              > DATE(o.order_estimated_delivery_date)
         THEN 1 ELSE 0 END                                    AS is_late,
    CASE WHEN c.customer_state = s.seller_state
         THEN 1 ELSE 0 END                                    AS same_state,

    -- Basket and payment
    i.n_items,
    i.n_sellers,
    ROUND(i.items_value, 2)                                   AS items_value,
    ROUND(i.freight_value, 2)                                 AS freight_value,
    ROUND(i.freight_value / NULLIF(i.items_value, 0), 4)      AS freight_ratio,
    pay.installments,
    pay.main_payment_type,

    -- Outcome
    r.review_score,
    CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END           AS is_negative_review,
    CASE WHEN r.review_comment_message IS NOT NULL
         THEN 1 ELSE 0 END                                    AS left_comment

FROM orders AS o
JOIN customers          AS c   ON c.customer_id = o.customer_id
JOIN latest_review      AS r   ON r.order_id    = o.order_id
JOIN items_per_order    AS i   ON i.order_id    = o.order_id
JOIN main_item          AS mi  ON mi.order_id   = o.order_id
JOIN sellers            AS s   ON s.seller_id   = mi.seller_id
JOIN products           AS p   ON p.product_id  = mi.product_id
LEFT JOIN category_translation AS t ON t.product_category_name = p.product_category_name
LEFT JOIN payments_per_order   AS pay ON pay.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;
