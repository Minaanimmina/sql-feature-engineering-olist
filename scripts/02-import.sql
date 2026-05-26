-- 02-import.sql
-- Import des CSV dans la base DuckDB
-- Ordre important : les tables référencées doivent être créées avant les tables qui les référencent
-- customers et sellers et products avant orders, orders avant order_items etc.

-- Création de la base persistante
-- On travaille sur un fichier .duckdb pour persister les données entre les sessions

-- 1. customers
COPY customers FROM '/mnt/c/Users/cracm/Downloads/olist-datasets/olist_customers_dataset.csv'
(FORMAT CSV, HEADER TRUE);

-- 2. sellers
COPY sellers FROM '/mnt/c/Users/cracm/Downloads/olist-datasets/olist_sellers_dataset.csv'
(FORMAT CSV, HEADER TRUE);

-- 3. products
COPY products FROM '/mnt/c/Users/cracm/Downloads/olist-datasets/olist_products_dataset.csv'
(FORMAT CSV, HEADER TRUE);

-- 4. traductions
COPY product_category_name_translation FROM '/mnt/c/Users/cracm/Downloads/olist-datasets/product_category_name_translation.csv'
(FORMAT CSV, HEADER TRUE);

-- 5. orders
COPY orders FROM '/mnt/c/Users/cracm/Downloads/olist-datasets/olist_orders_dataset.csv'
(FORMAT CSV, HEADER TRUE);

-- 6. order_items
COPY order_items FROM '/mnt/c/Users/cracm/Downloads/olist-datasets/olist_order_items_dataset.csv'
(FORMAT CSV, HEADER TRUE);

-- 7. order_payments
COPY order_payments FROM '/mnt/c/Users/cracm/Downloads/olist-datasets/olist_order_payments_dataset.csv'
(FORMAT CSV, HEADER TRUE);

-- 8. order_reviews
-- ON CONFLICT IGNORE : le CSV contient des review_id dupliqués, on garde la première occurrence
INSERT OR IGNORE INTO order_reviews
SELECT * FROM read_csv_auto('/mnt/c/Users/cracm/Downloads/olist-datasets/olist_order_reviews_dataset.csv');

-- Vérification post-import
SELECT 'customers'    AS table_name, COUNT(*) AS nb_lignes FROM customers
UNION ALL
SELECT 'sellers',      COUNT(*) FROM sellers
UNION ALL
SELECT 'products',     COUNT(*) FROM products
UNION ALL
SELECT 'translations', COUNT(*) FROM product_category_name_translation
UNION ALL
SELECT 'orders',       COUNT(*) FROM orders
UNION ALL
SELECT 'order_items',  COUNT(*) FROM order_items
UNION ALL
SELECT 'payments',     COUNT(*) FROM order_payments
UNION ALL
SELECT 'reviews',      COUNT(*) FROM order_reviews;