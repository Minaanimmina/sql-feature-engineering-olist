-- 05-features.sql
-- Feature engineering pour le modèle de prédiction de churn
-- On agrège toujours par customer_unique_id (identifiant réel du client)
-- car un même client peut avoir plusieurs customer_id

-- ============================================================
-- CTE 1 : RÉCENCE ET FRÉQUENCE
-- Jours depuis la dernière commande + nombre de commandes
-- ============================================================

WITH recence_frequence AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)                              AS nb_commandes,
        MAX(o.order_purchase_timestamp)                         AS derniere_commande,
        -- Récence : jours depuis la dernière commande
        -- On utilise la date max du dataset comme référence (pas CURRENT_DATE)
        -- car le dataset date de 2016-2018
        DATEDIFF('day',
            MAX(o.order_purchase_timestamp),
            (SELECT MAX(order_purchase_timestamp) FROM orders)
        )                                                       AS jours_depuis_derniere_commande
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),

-- ============================================================
-- CTE 2 : MONTANT
-- Valeur totale et panier moyen (price + freight_value)
-- ============================================================

montants AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value)                        AS valeur_totale,
        AVG(oi.price + oi.freight_value)                        AS panier_moyen,
        SUM(oi.price + oi.freight_value) / COUNT(DISTINCT o.order_id) AS panier_moyen_par_commande
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),

-- ============================================================
-- CTE 3 : SATISFACTION
-- Score moyen des reviews + % de mauvaises reviews
-- ============================================================

satisfaction AS (
    SELECT
        c.customer_unique_id,
        AVG(r.review_score)                                     AS score_moyen_reviews,
        COUNT(r.review_id)                                      AS nb_reviews,
        -- FILTER est plus lisible que CASE WHEN pour les agrégations conditionnelles
        COUNT(r.review_id) FILTER (WHERE r.review_score <= 2)   AS nb_mauvaises_reviews,
        ROUND(
            COUNT(r.review_id) FILTER (WHERE r.review_score <= 2)
            * 100.0 / NULLIF(COUNT(r.review_id), 0)
        , 2)                                                     AS pct_mauvaises_reviews
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),

-- ============================================================
-- CTE 4 : DIVERSITÉ CATÉGORIELLE
-- Nombre de catégories distinctes achetées
-- ============================================================

diversite AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT COALESCE(p.product_category_name, 'unknown')) AS nb_categories_distinctes
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),

-- ============================================================
-- CTE 5 : TENDANCE (WINDOW FUNCTIONS)
-- Evolution du panier entre commandes successives avec LAG
-- ============================================================

commandes_ordonnees AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price + oi.freight_value)                        AS montant_commande,
        -- LAG : récupère le montant de la commande précédente
        LAG(SUM(oi.price + oi.freight_value)) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        )                                                        AS montant_commande_precedente,
        -- Délai inter-commandes en jours
        DATEDIFF('day',
            LAG(o.order_purchase_timestamp) OVER (
                PARTITION BY c.customer_unique_id
                ORDER BY o.order_purchase_timestamp
            ),
            o.order_purchase_timestamp
        )                                                        AS delai_inter_commandes_jours
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id, o.order_id, o.order_purchase_timestamp
),

tendance AS (
    SELECT
        customer_unique_id,
        -- Délai moyen entre commandes
        AVG(delai_inter_commandes_jours)                        AS delai_moyen_inter_commandes,
        -- Tendance : différence moyenne entre panier courant et précédent
        -- Positif = client qui dépense de plus en plus
        AVG(montant_commande - montant_commande_precedente)     AS tendance_panier,
        -- Rang du client par valeur totale
        RANK() OVER (
            ORDER BY AVG(montant_commande) DESC
        )                                                        AS rang_par_valeur
    FROM commandes_ordonnees
    WHERE montant_commande_precedente IS NOT NULL  -- exclut la première commande
    GROUP BY customer_unique_id
),

-- ============================================================
-- CTE 6 : PAIEMENTS
-- Mode de paiement préféré et nombre moyen de versements
-- ============================================================

paiements AS (
    SELECT
        c.customer_unique_id,
        -- Mode de paiement le plus utilisé
        MODE() WITHIN GROUP (ORDER BY p.payment_type)           AS mode_paiement_prefere,
        AVG(p.payment_installments)                             AS nb_moyen_versements,
        SUM(p.payment_value)                                    AS valeur_totale_paiements
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)

-- ============================================================
-- RÉSULTAT FINAL : jointure de toutes les CTEs
-- ============================================================

SELECT
    rf.customer_unique_id,
    -- Récence / Fréquence
    rf.nb_commandes,
    rf.jours_depuis_derniere_commande,
    -- Montants
    ROUND(m.valeur_totale, 2)               AS valeur_totale,
    ROUND(m.panier_moyen, 2)                AS panier_moyen,
    ROUND(m.panier_moyen_par_commande, 2)   AS panier_moyen_par_commande,
    -- Satisfaction
    ROUND(s.score_moyen_reviews, 2)         AS score_moyen_reviews,
    s.nb_reviews,
    s.nb_mauvaises_reviews,
    s.pct_mauvaises_reviews,
    -- Diversité
    d.nb_categories_distinctes,
    -- Tendance
    ROUND(t.delai_moyen_inter_commandes, 1) AS delai_moyen_inter_commandes,
    ROUND(t.tendance_panier, 2)             AS tendance_panier,
    t.rang_par_valeur,
    -- Paiements
    p.mode_paiement_prefere,
    ROUND(p.nb_moyen_versements, 1)         AS nb_moyen_versements
FROM recence_frequence rf
LEFT JOIN montants m         ON rf.customer_unique_id = m.customer_unique_id
LEFT JOIN satisfaction s     ON rf.customer_unique_id = s.customer_unique_id
LEFT JOIN diversite d        ON rf.customer_unique_id = d.customer_unique_id
LEFT JOIN tendance t         ON rf.customer_unique_id = t.customer_unique_id
LEFT JOIN paiements p        ON rf.customer_unique_id = p.customer_unique_id
ORDER BY rf.nb_commandes DESC
LIMIT 20;