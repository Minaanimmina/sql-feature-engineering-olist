-- 07-optimisation.sql
-- Analyse des performances et création d'index justifiés
-- On compare les plans d'exécution avant/après index

-- ============================================================
-- AVANT INDEX : plan d'exécution sur la requête principale
-- ============================================================

EXPLAIN ANALYZE
SELECT * FROM v_customer_features LIMIT 10;

-- ============================================================
-- CRÉATION DES INDEX
-- ============================================================

-- Index 1 : customer_id dans orders
-- Justification : la jointure customers -> orders se fait sur customer_id
-- C'est la jointure la plus fréquente de toute la vue, présente dans chaque CTE
CREATE INDEX IF NOT EXISTS idx_orders_customer_id
ON orders(customer_id);

-- Index 2 : order_id dans order_items
-- Justification : chaque CTE qui calcule des montants joint orders -> order_items
-- sur order_id, c'est la deuxième jointure la plus coûteuse
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
ON order_items(order_id);

-- Index 3 : order_id dans order_reviews
-- Justification : la CTE satisfaction joint orders -> order_reviews sur order_id
CREATE INDEX IF NOT EXISTS idx_order_reviews_order_id
ON order_reviews(order_id);

-- Index 4 : order_id dans order_payments
-- Justification : la CTE paiements joint orders -> order_payments sur order_id
CREATE INDEX IF NOT EXISTS idx_order_payments_order_id
ON order_payments(order_id);

-- ============================================================
-- APRÈS INDEX : même plan d'exécution pour comparaison
-- ============================================================

EXPLAIN ANALYZE
SELECT * FROM v_customer_features LIMIT 10;

-- ============================================================
-- BONUS : ÉQUIVALENT MATERIALIZED VIEW
-- DuckDB 1.5 ne supporte pas MATERIALIZED VIEW (ni les index partiels)
-- L'équivalent fonctionnel est CREATE TABLE AS SELECT
-- Avantage : résultats précalculés, lecture instantanée pour le pipeline ML
-- Compromis : données figées, nécessite un refresh manuel
-- Pour rafraîchir : CREATE OR REPLACE TABLE mv_customer_features AS SELECT * FROM v_customer_features
-- ============================================================

CREATE OR REPLACE TABLE mv_customer_features AS
SELECT * FROM v_customer_features;

SELECT COUNT(*) AS nb_clients FROM mv_customer_features;

-- Comparaison vue simple vs table précalculée
EXPLAIN ANALYZE SELECT * FROM v_customer_features LIMIT 10;
EXPLAIN ANALYZE SELECT * FROM mv_customer_features LIMIT 10;