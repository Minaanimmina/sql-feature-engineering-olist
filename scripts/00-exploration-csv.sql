-- 00-exploration-csv.sql
-- Exploration des CSV bruts avant conception du schéma DDL

-- ============================================================
-- 1. STRUCTURE DES FICHIERS : premières lignes de chaque CSV
-- ============================================================

SELECT * FROM read_csv_auto('data/olist-datasets/olist_customers_dataset.csv') LIMIT 5;
SELECT * FROM read_csv_auto('data/olist-datasets/olist_orders_dataset.csv') LIMIT 5;
SELECT * FROM read_csv_auto('data/olist-datasets/olist_order_items_dataset.csv') LIMIT 5;
SELECT * FROM read_csv_auto('data/olist-datasets/olist_order_payments_dataset.csv') LIMIT 5;
SELECT * FROM read_csv_auto('data/olist-datasets/olist_order_reviews_dataset.csv') LIMIT 5;
SELECT * FROM read_csv_auto('data/olist-datasets/olist_products_dataset.csv') LIMIT 5;
SELECT * FROM read_csv_auto('data/olist-datasets/olist_sellers_dataset.csv') LIMIT 5;
SELECT * FROM read_csv_auto('data/olist-datasets/product_category_name_translation.csv') LIMIT 5;

-- ============================================================
-- 2. COMPTAGE DES LIGNES : vérification des volumes attendus
-- ============================================================

SELECT 'customers'    AS table_name, COUNT(*) AS nb_lignes FROM read_csv_auto('data/olist-datasets/olist_customers_dataset.csv')
UNION ALL
SELECT 'orders',       COUNT(*) FROM read_csv_auto('data/olist-datasets/olist_orders_dataset.csv')
UNION ALL
SELECT 'order_items',  COUNT(*) FROM read_csv_auto('data/olist-datasets/olist_order_items_dataset.csv')
UNION ALL
SELECT 'payments',     COUNT(*) FROM read_csv_auto('data/olist-datasets/olist_order_payments_dataset.csv')
UNION ALL
SELECT 'reviews',      COUNT(*) FROM read_csv_auto('data/olist-datasets/olist_order_reviews_dataset.csv')
UNION ALL
SELECT 'products',     COUNT(*) FROM read_csv_auto('data/olist-datasets/olist_products_dataset.csv')
UNION ALL
SELECT 'sellers',      COUNT(*) FROM read_csv_auto('data/olist-datasets/olist_sellers_dataset.csv')
UNION ALL
SELECT 'translations', COUNT(*) FROM read_csv_auto('data/olist-datasets/product_category_name_translation.csv');

-- ============================================================
-- 3. QUESTION CLÉ : customer_id vs customer_unique_id
-- Un même client réel peut-il avoir plusieurs customer_id ?
-- ============================================================

SELECT
    customer_unique_id,
    COUNT(DISTINCT customer_id) AS nb_customer_ids
FROM read_csv_auto('data/olist-datasets/olist_customers_dataset.csv')
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT customer_id) > 1
LIMIT 10;

-- Combien de clients réels vs entrées brutes ?
SELECT
    COUNT(*)                           AS total_lignes,
    COUNT(DISTINCT customer_id)        AS nb_customer_ids_distincts,
    COUNT(DISTINCT customer_unique_id) AS nb_clients_reels
FROM read_csv_auto('data/olist-datasets/olist_customers_dataset.csv');

-- ============================================================
-- 4. TYPES ET VALEURS MANQUANTES : anomalies potentielles
-- ============================================================

-- Valeurs NULL dans orders
SELECT
    COUNT(*) AS total,
    COUNT(order_approved_at)             AS approved_non_null,
    COUNT(order_delivered_carrier_date)  AS carrier_non_null,
    COUNT(order_delivered_customer_date) AS delivered_non_null
FROM read_csv_auto('data/olist-datasets/olist_orders_dataset.csv');

-- Produits sans catégorie
SELECT
    COUNT(*) AS total_produits,
    COUNT(product_category_name) AS avec_categorie,
    COUNT(*) - COUNT(product_category_name) AS sans_categorie
FROM read_csv_auto('data/olist-datasets/olist_products_dataset.csv');
