-- 00-exploration-base.sql
-- Exploration de la base créée après conception du schéma DDL

-- ============================================================
-- 1. STATUTS DES COMMANDES : distribution
-- ============================================================

SELECT
    order_status,
    COUNT(*) AS nb_commandes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY nb_commandes DESC;

-- ============================================================
-- 2. INCOHÉRENCES : commandes "delivered" sans date de livraison
-- ============================================================

SELECT COUNT(*) AS nb_incoherences
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- ============================================================
-- 3. COMMANDES SANS ITEMS
-- ============================================================

SELECT COUNT(*) AS commandes_sans_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;

-- ============================================================
-- 4. REVIEWS SANS COMMANDE CORRESPONDANTE
-- ============================================================

SELECT COUNT(*) AS reviews_orphelines
FROM order_reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- ============================================================
-- 5. FAUTES DE FRAPPE DANS LES VILLES : doublons proches
-- ============================================================

SELECT
    customer_city,
    COUNT(*) AS nb_clients
FROM customers
GROUP BY customer_city
ORDER BY nb_clients DESC
LIMIT 20;

SELECT DISTINCT customer_city
FROM customers
WHERE customer_city LIKE '%sao paulo%'
   OR customer_city LIKE '%rio de janeiro%'
   OR customer_city LIKE '%belo horizonte%'
ORDER BY customer_city;

-- ============================================================
-- 6. DISTRIBUTION DES SCORES DE REVIEWS
-- ============================================================

SELECT
    review_score,
    COUNT(*) AS nb_reviews,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

SELECT
    COUNT(*) FILTER (WHERE review_score <= 2) AS mauvaises_reviews,
    COUNT(*) AS total_reviews,
    ROUND(COUNT(*) FILTER (WHERE review_score <= 2) * 100.0 / COUNT(*), 2) AS pct_mauvaises
FROM order_reviews;