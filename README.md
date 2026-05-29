# SQL Feature Engineering — Prédiction de Churn Client Olist

![Python](https://img.shields.io/badge/python-3.12-blue?logo=python&logoColor=white)
![DuckDB](https://img.shields.io/badge/DuckDB-1.5.3-yellow?logo=duckdb&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-dashboard-red?logo=streamlit&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CTEs%20%7C%20Window%20Functions-blue)
![uv](https://img.shields.io/badge/uv-package%20manager-purple)
![Plotly](https://img.shields.io/badge/Plotly-visualisation-3F4F75?logo=plotly&logoColor=white)
![Dataset](https://img.shields.io/badge/Dataset-Olist%20Brazilian%20E--Commerce-green)

## Contexte

Olist est une marketplace brésilienne connectant petits commerçants et clients finaux. Le dataset couvre ~100 000 commandes passées entre 2016 et 2018. L'équipe data science constate un taux de churn élevé et souhaite déployer un modèle prédictif pour identifier les clients à risque et déclencher des campagnes de rétention ciblées.

Le **churn** désigne la perte de clients : un client churne lorsqu'il cesse d'acheter
sur la plateforme et ne revient pas. C'est un indicateur critique en e-commerce,
car acquérir un nouveau client coûte en moyenne 5 à 7 fois plus cher que fidéliser
un client existant. L'enjeu est d'identifier les clients à risque **avant** qu'ils
ne partent définitivement, afin de déclencher des actions de rétention ciblées
(relance email, offre promotionnelle, programme de fidélité).

>**Question centrale** : quels clients vont churner dans les 90 prochains jours, et quels signaux comportementaux les distinguent des clients fidèles ?

## Architecture

```
CSV Olist (9 fichiers)
        │
        ▼
  DuckDB (olist.duckdb)
        │
   ┌────┴────┐
   │  SQL    │  01-schema → 02-import → 03-exploration → 04-nettoyage
   │pipeline │  05-features → 06-vue-finale → 07-optimisation
   └────┬────┘
        │
        ▼
v_customer_features (vue analytique — 18 features par client)
        │
        ▼
  Streamlit Dashboard
  (dashboard/app.py)
        │
        ▼
Équipe Data Science / Pipeline ML
```

## Technologies

| Outil | Usage |
|---|---|
| DuckDB 1.5.3 | Base de données analytique, SQL avancé |
| Python 3.12 | Environnement de développement |
| uv | Gestion des dépendances |
| Streamlit | Dashboard de visualisation |
| Plotly | Graphiques interactifs |

## Installation

Prérequis :

- Python 3.12+
- uv
- CLI DuckDB (`duckdb`)

```bash
git clone <url-du-repo>
cd sql-feature-engineering-olist
uv sync
```

Télécharger le dataset Olist sur [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) et placer les CSV dans `data/olist-datasets/`.

## Exécution du pipeline

```bash
# Lancer tous les scripts dans l'ordre
bash scripts/run_pipeline.sh
```

Ou script par script :

```bash
duckdb olist.duckdb < scripts/01-schema.sql
duckdb olist.duckdb < scripts/02-import.sql
duckdb olist.duckdb < scripts/03-exploration-base.sql
duckdb olist.duckdb < scripts/04-nettoyage.sql
duckdb olist.duckdb < scripts/05-features.sql
duckdb olist.duckdb < scripts/06-vue-finale.sql
duckdb olist.duckdb < scripts/07-optimisation.sql
```

Vérifier la vue finale :

```bash
duckdb olist.duckdb "SELECT * FROM v_customer_features LIMIT 10;"
```

Lancer le dashboard :

```bash
streamlit run dashboard/app.py
```

## Schéma de la base de données

Voir `docs/schema_bdd_analytique/schema_bdd.mmd` (compatible [mermaid.live](https://mermaid.live)) ou `docs/schema_bdd_analytique/schema_bdd.png`.

## Features produites

La vue `v_customer_features` produit 18 colonnes par client réel (`customer_unique_id`), couvrant 8 dimensions :

| Dimension | Features |
|---|---|
| Récence | `jours_depuis_derniere_commande` |
| Fréquence | `nb_commandes` |
| Montant | `valeur_totale`, `panier_moyen`, `panier_moyen_par_commande` |
| Satisfaction | `score_moyen_reviews`, `nb_reviews`, `nb_mauvaises_reviews`, `pct_mauvaises_reviews` |
| Tendance | `delai_moyen_inter_commandes`, `tendance_panier`, `rang_par_valeur` |
| Diversité | `nb_categories_distinctes` |
| Paiement | `mode_paiement_prefere`, `nb_moyen_versements` |
| Churn | `est_churne` (label binaire), `segment_client` (nouveau / actif / a_risque / churne) |

### Définition du churn

Un client est considéré churné (`est_churne = 1`) s'il n'a pas commandé depuis plus de **365 jours** par rapport à la dernière date du dataset. Ce seuil a été calibré par analyse des taux réels :

| Seuil | Taux de churn |
|---|---|
| 90 jours | 90% (non exploitable) |
| 180 jours | 71% |
| 270 jours | 49% |
| **365 jours** | **29% (retenu)** |

## Nettoyage des données

5 anomalies sont documentées dans `scripts/04-nettoyage.sql` (certaines corrigées, d'autres conservées avec justification métier) :

| Anomalie | Décision |
|---|---|
| 814 `review_id` dupliqués | Traité à l'import via `INSERT OR IGNORE` |
| 8 commandes "delivered" sans date de livraison | Statut corrigé en "shipped" |
| 610 produits sans catégorie | Laissés NULL, gérés via `COALESCE('unknown')` en aval |

## Optimisation

4 index créés sur les colonnes de jointure les plus fréquentes, avec comparaison `EXPLAIN ANALYZE` avant/après. Résultats dans `outputs/explain_analyze.txt`.

| Index | Justification |
|---|---|
| `idx_orders_customer_id` | Jointure présente dans les 6 CTEs |
| `idx_order_items_order_id` | Jointure pour le calcul des montants |
| `idx_order_reviews_order_id` | Jointure dans la CTE satisfaction |
| `idx_order_payments_order_id` | Jointure dans la CTE paiements |

## Structure du projet

```ascii
├── scripts/
│   ├── 00-exploration-csv.sql      # Exploration des CSV bruts
│   ├── 01-schema.sql               # DDL : CREATE TABLE, contraintes, types
│   ├── 02-import.sql               # Import des CSV via COPY
│   ├── 03-exploration-base.sql     # Exploration après import
│   ├── 04-nettoyage.sql            # Nettoyage des anomalies
│   ├── 05-features.sql             # Feature engineering (CTEs, Window Functions)
│   ├── 06-vue-finale.sql           # Création de v_customer_features
│   └── 07-optimisation.sql         # Index + EXPLAIN ANALYZE
├── dashboard/
│   ├── app.py                      # Dashboard Streamlit
│   └── img/
│       └── olist-logo.svg
├── data/
│   └── olist-datasets/             # CSV Olist (non versionnés)
├── outputs/
│   ├── explain_analyze.txt         # Résultats EXPLAIN ANALYZE
│   └── pipeline_run.log            # Log de la dernière exécution
├── docs/
│   ├── schema_bdd_analytique/
│   │   ├── schema_bdd.mmd          # Schéma ERD (Mermaid)
│   │   └── schema_bdd.png
│   └── schema_bdd_source/
├── scripts/run_pipeline.sh         # Script d'exécution du pipeline
├── pyproject.toml
└── README.md
```

## Limites connues

~97% des clients Olist n'ont passé qu'une seule commande. Cela rend la distinction entre "client churné" et "client qui n'a commandé qu'une fois" difficile. Les features de tendance (`tendance_panier`, `delai_moyen_inter_commandes`) sont NULL pour ces clients car elles nécessitent au moins deux commandes.

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100 000 commandes, 2016-2018, 9 fichiers CSV.

## Licence

Aucune licence n'est déclarée pour le moment dans le dépôt.