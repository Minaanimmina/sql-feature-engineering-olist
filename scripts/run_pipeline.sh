#!/bin/bash
# run_pipeline.sh
# Exécute tous les scripts SQL dans l'ordre sur olist.duckdb
# Usage : bash run_pipeline.sh
# Logs sauvegardés dans outputs/pipeline_run.log

DB="olist.duckdb"
LOG="outputs/pipeline_run.log"

mkdir -p outputs

# Redirige stdout ET stderr vers le terminal ET vers le fichier log
exec > >(tee "$LOG") 2>&1

echo "============================================"
echo "  Pipeline SQL Olist - Churn Prediction"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"

run_script() {
    local file=$1
    local label=$2
    echo ""
    echo ">>> $label"
    echo "    Fichier : $file"
    duckdb "$DB" < "$file"
    echo "    OK"
}

run_script "scripts/01-schema.sql"           "01 - Création du schéma"
run_script "scripts/02-import.sql"           "02 - Import des CSV"
run_script "scripts/03-exploration-base.sql" "03 - Exploration de la base"
run_script "scripts/04-nettoyage.sql"        "04 - Nettoyage des anomalies"
run_script "scripts/05-features.sql"         "05 - Feature engineering"
run_script "scripts/06-vue-finale.sql"       "06 - Vue finale v_customer_features"

echo ""
echo ">>> 07 - Index et optimisation"
echo "    Fichier : scripts/07-optimisation.sql"
duckdb "$DB" < scripts/07-optimisation.sql > outputs/explain_analyze.txt 2>&1
cat outputs/explain_analyze.txt
echo "    OK (résultats EXPLAIN ANALYZE sauvegardés dans outputs/explain_analyze.txt)"

echo ""
echo "============================================"
echo "  Pipeline terminé."
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================"
echo ""
echo "Vérification finale :"
duckdb "$DB" "SELECT COUNT(*) AS nb_clients FROM v_customer_features;"
echo ""
echo "Aperçu (10 premières lignes) :"
duckdb "$DB" "SELECT customer_unique_id, nb_commandes, jours_depuis_derniere_commande, segment_client, est_churne FROM v_customer_features LIMIT 10;"
echo ""
echo "Fichiers produits :"
echo "  outputs/pipeline_run.log     <- log complet de cette exécution"
echo "  outputs/explain_analyze.txt  <- résultats EXPLAIN ANALYZE avant/après index"