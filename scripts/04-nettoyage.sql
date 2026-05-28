-- 04-nettoyage.sql
-- Nettoyage des anomalies identifiées lors de l'exploration
-- Chaque décision est commentée et justifiée

-- ============================================================
-- ANOMALIE 1 : review_id dupliqués (814 doublons)
-- Décision : traité à l'import via INSERT OR IGNORE
-- On garde la première occurrence, les doublons sont ignorés
-- Justification : un review_id est censé être unique, le doublon
-- est probablement un bug d'export du système Olist
-- ============================================================

-- Vérification
SELECT COUNT(*) AS nb_reviews FROM order_reviews;
-- Attendu : 98410

-- ============================================================
-- ANOMALIE 2 : 8 commandes "delivered" sans date de livraison
-- Décision : corriger le statut en "shipped" car on ne peut pas
-- inventer une date de livraison
-- Justification : une commande ne peut pas être "delivered" sans
-- date de livraison, c'est une incohérence métier
-- ============================================================

UPDATE orders
SET order_status = 'shipped'
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- Vérification
SELECT COUNT(*) AS nb_incoherences_restantes
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
-- Attendu : 0

-- ============================================================
-- ANOMALIE 3 : 610 produits sans catégorie
-- Décision : laisser en l'état avec NULL
-- Justification : on ne peut pas deviner la catégorie. Dans la
-- vue finale on utilisera COALESCE pour remplacer NULL par
-- 'unknown' au moment du feature engineering
-- ============================================================

-- Vérification
SELECT COUNT(*) AS produits_sans_categorie
FROM products
WHERE product_category_name IS NULL;
-- Attendu : 610

-- ============================================================
-- ANOMALIE 4 : 1 commande "shipped" sans items
-- Décision : laisser en l'état
-- Justification : la commande existe et a été expédiée, la
-- donnée est peut-être incomplète côté vendeur. On ne la supprime
-- pas pour ne pas perdre l'historique client
-- ============================================================

-- Vérification
SELECT o.order_id, o.order_status
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
  AND o.order_status = 'shipped';

-- ============================================================
-- ANOMALIE 5 : colonnes de dates avec valeurs manquantes
-- order_approved_at : 160 NULL
-- order_delivered_carrier_date : 1783 NULL
-- order_delivered_customer_date : 2965 NULL
-- Décision : laisser en l'état avec NULL
-- Justification : ces NULL sont métier, ils indiquent des
-- commandes non encore approuvées, expédiées ou livrées.
-- Les supprimer ferait perdre des données utiles pour le modèle.
-- ============================================================

-- Vérification globale finale
SELECT
    'orders'   AS table_name,
    COUNT(*)   AS total,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)             AS approved_null,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL)  AS carrier_null,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS delivered_null
FROM orders;