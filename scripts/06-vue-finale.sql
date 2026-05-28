-- 06-vue-finale.sql
-- Vue consolidée v_customer_features
-- Chaque ligne = un customer_unique_id avec toutes ses métriques
-- Sert de table d'entrée directe pour le pipeline ML
-- Inclut un label churn et une segmentation client

CREATE OR REPLACE VIEW v_customer_features AS

WITH recence_frequence AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id)                              AS nb_commandes,
        MAX(o.order_purchase_timestamp)                         AS derniere_commande,
        DATEDIFF('day',
            MAX(o.order_purchase_timestamp),
            (SELECT MAX(order_purchase_timestamp) FROM orders)
        )                                                       AS jours_depuis_derniere_commande
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
),

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

satisfaction AS (
    SELECT
        c.customer_unique_id,
        AVG(r.review_score)                                     AS score_moyen_reviews,
        COUNT(r.review_id)                                      AS nb_reviews,
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

commandes_ordonnees AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        SUM(oi.price + oi.freight_value)                        AS montant_commande,
        LAG(SUM(oi.price + oi.freight_value)) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        )                                                        AS montant_commande_precedente,
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
        AVG(delai_inter_commandes_jours)                        AS delai_moyen_inter_commandes,
        AVG(montant_commande - montant_commande_precedente)     AS tendance_panier,
        RANK() OVER (
            ORDER BY AVG(montant_commande) DESC
        )                                                        AS rang_par_valeur
    FROM commandes_ordonnees
    WHERE montant_commande_precedente IS NOT NULL
    GROUP BY customer_unique_id
),

paiements AS (
    SELECT
        c.customer_unique_id,
        MODE() WITHIN GROUP (ORDER BY p.payment_type)           AS mode_paiement_prefere,
        AVG(p.payment_installments)                             AS nb_moyen_versements,
        SUM(p.payment_value)                                    AS valeur_totale_paiements
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)

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
    ROUND(p.nb_moyen_versements, 1)         AS nb_moyen_versements,
    -- Label churn : inactif depuis plus de 365 jours par rapport à la date
    -- de référence du dataset (MAX order_purchase_timestamp)
    -- Seuil de 365 jours retenu après analyse : donne un taux de ~29%,
    -- cohérent avec une marketplace e-commerce généraliste.
    -- Seuils plus bas (90j = 90%, 180j = 71%) étaient trop élevés car
    -- la majorité des clients ont commandé bien avant la fin du dataset (2018).
    -- Limite connue : ~97% des clients n'ont qu'une seule commande sur Olist,
    -- ce qui rend la prédiction de churn classique difficile sur ce dataset.
    CASE
        WHEN rf.jours_depuis_derniere_commande > 365 THEN 1
        ELSE 0
    END                                     AS est_churne,
    -- Segmentation client
    -- Ordre des conditions important : du plus spécifique au plus général
    CASE
        WHEN rf.nb_commandes = 1
             AND rf.jours_depuis_derniere_commande <= 180 THEN 'nouveau'
        WHEN rf.jours_depuis_derniere_commande <= 180     THEN 'actif'
        WHEN rf.jours_depuis_derniere_commande <= 365     THEN 'a_risque'
        ELSE                                                   'churne'
    END                                     AS segment_client
FROM recence_frequence rf
LEFT JOIN montants m         ON rf.customer_unique_id = m.customer_unique_id
LEFT JOIN satisfaction s     ON rf.customer_unique_id = s.customer_unique_id
LEFT JOIN diversite d        ON rf.customer_unique_id = d.customer_unique_id
LEFT JOIN tendance t         ON rf.customer_unique_id = t.customer_unique_id
LEFT JOIN paiements p        ON rf.customer_unique_id = p.customer_unique_id;