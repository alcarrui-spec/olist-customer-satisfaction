-- 01_data_quality_checks.sql
-- Check the data before trusting it. Each query returns one small table.

-- 1. Row counts per table
SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments',    COUNT(*) FROM payments
UNION ALL SELECT 'reviews',     COUNT(*) FROM reviews
UNION ALL SELECT 'customers',   COUNT(*) FROM customers
UNION ALL SELECT 'sellers',     COUNT(*) FROM sellers
UNION ALL SELECT 'products',    COUNT(*) FROM products;

-- 2. Orders by status: only 'delivered' orders have a delivery date to analyze
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 3. Orders with more than one review (we keep only the latest one per order)
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (
    SELECT order_id
    FROM reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
);

-- 4. Delivered orders missing a delivery date (excluded from delivery analysis)
SELECT COUNT(*) AS delivered_but_no_delivery_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 5. Products with no category (labeled 'unknown' later)
SELECT COUNT(*) AS products_missing_category
FROM products
WHERE product_category_name IS NULL;
