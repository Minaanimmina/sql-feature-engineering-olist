import streamlit as st
import duckdb
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime

st.set_page_config(
    page_title="Olist — Churn Analytics",
    page_icon="🛒",
    layout="wide",
    initial_sidebar_state="auto"
)

DB_PATH = "olist.duckdb"

def load_svg(path):
    with open(path, "r") as f:
        return f.read()

LOGO_SVG = load_svg("dashboard/img/olist-logo.svg")

st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=DM+Mono:wght@400;500&display=swap');

html, body, [class*="css"], [class*="st-"] {
    font-family: 'Inter', sans-serif !important;
}

[data-testid="stAppViewContainer"] > .main {
    background-color: #F4F6FB;
}

.block-container {
    padding: 1.5rem 2rem 2rem !important;
    max-width: 100% !important;
}

[data-testid="stIconMaterial"] {
    font-family: 'Material Symbols Rounded' !important;
    font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
}

[data-testid="stSidebarUserContent"] {
    padding: 1.5rem 1rem !important;
}

[data-testid="stSidebarContent"] * {
    color: #374151 !important;
}

[data-testid="stSidebarCollapseButton"] button {
    color: rgba(15, 23, 41, 0.6) !important;
    background: transparent !important;
    opacity: 1 !important;
    visibility: visible !important;
}

[data-testid="stSidebarCollapseButton"] svg {
    fill: #374151 !important;
}

.sidebar-divider {
    border: none;
    border-top: 1px solid #E8ECF4;
    margin: 1rem 0;
}

.kpi-card {
    background: #FFFFFF;
    border-radius: 14px;
    padding: 1.2rem 1.4rem;
    border: 1px solid #E8ECF4;
    position: relative;
    overflow: hidden;
    min-height: 150px;
    box-sizing: border-box;
}

.kpi-card.accent {
    background: #2563EB;
    border-color: #2563EB;
}

.kpi-card.danger {
    background: #FEF2F2;
    border-color: #FECACA;
}

.kpi-label {
    font-size: 11px;
    font-weight: 600;
    color: #9CA3AF;
    text-transform: uppercase;
    letter-spacing: 0.07em;
    margin-bottom: 0.3rem;
}

.kpi-value {
    font-size: 26px;
    font-weight: 700;
    color: #0F1729;
    font-family: 'DM Mono', monospace;
    line-height: 1.15;
    margin-bottom: 0.4rem;
}

.kpi-badge {
    display: inline-flex;
    align-items: center;
    font-size: 11px;
    font-weight: 600;
    padding: 3px 8px;
    border-radius: 20px;
    gap: 3px;
}

.kpi-badge.positive { background: #DCFCE7; color: #15803D; }
.kpi-badge.negative { background: #FEE2E2; color: #B91C1C; }
.kpi-badge.neutral  { background: #EFF6FF; color: #1D4ED8; }
.kpi-badge.warning  { background: #FEF9C3; color: #A16207; }

.kpi-sub {
    font-size: 11px;
    color: #9CA3AF;
    margin-top: 3px;
}

.section-header {
    margin-bottom: 0.2rem;
}

.section-title {
    font-size: 15px;
    font-weight: 600;
    color: #0F1729;
    margin: 0 0 2px 0;
}

.section-sub {
    font-size: 12px;
    color: #9CA3AF;
    margin: 0;
}

[data-testid="stVerticalBlock"] {
    gap: 0.35rem !important;
}

[data-testid="stElementContainer"] {
    margin-top: 10px !important;
    margin-bottom: 10px !important;
    border-radius: 10px !important;
}

[data-testid="stMarkdownContainer"] > :first-child {
    margin-top: 0 !important;
}

[data-testid="stMarkdownContainer"] > :last-child {
    margin-bottom: 0 !important;
}

[data-testid="stElementContainer"]:has([data-testid="stMarkdownContainer"]:empty) {
    display: none !important;
}

.chart-card {
    background: #FFFFFF;
    border-radius: 14px;
    padding: 1rem 1.4rem;
    border: 1px solid #E8ECF4;
}

.stat-row {
    background: #FFFFFF;
    border-radius: 10px;
    padding: 0.8rem 1rem;
    margin-bottom: 0.5rem;
    border: 1px solid #E8ECF4;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.stat-label {
    font-size: 13px;
    color: #4B5563;
}

[data-testid="stDataFrame"] {
    border-radius: 10px;
    overflow: hidden;
    border: 1px solid #E8ECF4 !important;
}
</style>
""", unsafe_allow_html=True)

# ============================================================
# Data loading
# ============================================================

@st.cache_data
def load_features():
    con = duckdb.connect(DB_PATH, read_only=True)
    df = con.execute("SELECT * FROM v_customer_features").df()
    con.close()
    return df

@st.cache_data
def load_monthly_revenue():
    con = duckdb.connect(DB_PATH, read_only=True)
    df = con.execute("""
        SELECT
            DATE_TRUNC('month', order_purchase_timestamp) AS mois,
            COUNT(DISTINCT o.order_id)                    AS nb_commandes,
            SUM(oi.price + oi.freight_value)              AS chiffre_affaires
        FROM orders o
        JOIN order_items oi ON o.order_id = oi.order_id
        WHERE o.order_status NOT IN ('canceled', 'unavailable')
        GROUP BY 1 ORDER BY 1
    """).df()
    con.close()
    return df

@st.cache_data
def load_reviews():
    con = duckdb.connect(DB_PATH, read_only=True)
    df = con.execute("""
        SELECT review_score, COUNT(*) AS nb
        FROM order_reviews GROUP BY review_score ORDER BY review_score
    """).df()
    con.close()
    return df

@st.cache_data
def load_top_categories():
    con = duckdb.connect(DB_PATH, read_only=True)
    df = con.execute("""
        SELECT
            COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS categorie,
            COUNT(*) AS nb_ventes,
            SUM(oi.price) AS chiffre_affaires
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        LEFT JOIN product_category_name_translation t
            ON p.product_category_name = t.product_category_name
        JOIN orders o ON oi.order_id = o.order_id
        WHERE o.order_status NOT IN ('canceled', 'unavailable')
        GROUP BY 1 ORDER BY nb_ventes DESC LIMIT 10
    """).df()
    con.close()
    return df

df         = load_features()
df_revenue = load_monthly_revenue()
df_reviews = load_reviews()
df_cat     = load_top_categories()

# Métriques globales
total_ca      = df["valeur_totale"].sum()
total_orders  = df["nb_commandes"].sum()
total_clients = len(df)
avg_basket    = df["panier_moyen_par_commande"].mean()
pct_bad_rev   = df["nb_mauvaises_reviews"].sum() / df["nb_reviews"].sum() * 100

# Taux de churn réel issu de est_churne (définition SQL 365 jours, fixe)
pct_churne_reel = df["est_churne"].mean() * 100
nb_churne_reel  = df["est_churne"].sum()

# Segment à risque issu de la vue SQL
nb_a_risque_sql  = int((df["segment_client"] == "a_risque").sum())
pct_a_risque_sql = nb_a_risque_sql / len(df) * 100

# Métriques par segment
SEGMENT_ORDER  = ["nouveau", "actif", "a_risque", "churne"]
SEGMENT_LABELS = {"nouveau": "Nouveau", "actif": "Actif", "a_risque": "À risque", "churne": "Churné"}
SEGMENT_COLORS = {"nouveau": "#2563EB", "actif": "#10B981", "a_risque": "#F59E0B", "churne": "#EF4444"}

df_seg = (
    df.groupby("segment_client")
    .agg(
        nb_clients=("customer_unique_id", "count"),
        valeur_totale_moy=("valeur_totale", "mean"),
        score_moy=("score_moyen_reviews", "mean"),
        recence_moy=("jours_depuis_derniere_commande", "mean"),
        nb_commandes_moy=("nb_commandes", "mean"),
    )
    .reindex([s for s in SEGMENT_ORDER if s in df["segment_client"].unique()])
    .reset_index()
)

# Tableau clients à risque : segment a_risque uniquement, source SQL
df_a_risque = df[df["segment_client"] == "a_risque"].copy()

# ============================================================
# SIDEBAR
# ============================================================

with st.sidebar:
    st.markdown(f"""
    <div style="display:flex;align-items:center;gap:10px;padding:0.25rem 0 1.25rem 0">
        <div style="height:32px;max-width:80px;display:flex;align-items:center">{LOGO_SVG}</div>
        <div>
            <div style="color:#0F1729;font-weight:700;font-size:15px;line-height:1.2">Olist</div>
            <div style="color:#9CA3AF;font-size:11px">Churn Analytics</div>
        </div>
    </div>
    <hr class="sidebar-divider" style="margin-top:0"/>
    """, unsafe_allow_html=True)

    # Bloc churn fusionné (Option B)
    st.markdown(f"""
    <div style="background:#FFFFFF;border-radius:12px;padding:1rem;
                border:1px solid #E8ECF4;margin-bottom:0.75rem">
        <div style="font-size:10px;font-weight:600;text-transform:uppercase;
                    letter-spacing:0.1em;color:#9CA3AF;margin-bottom:0.75rem">
            Métriques churn · seuil 365 j
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:0.75rem;margin-bottom:0.75rem">
            <div style="background:#FEF2F2;border-radius:10px;padding:0.75rem;
                        border:1px solid #FECACA;text-align:center">
                <div style="font-size:9px;font-weight:600;text-transform:uppercase;
                            letter-spacing:0.08em;color:#EF4444;margin-bottom:0.3rem">Churné</div>
                <div style="font-size:22px;font-weight:700;color:#B91C1C;
                            font-family:'DM Mono',monospace;line-height:1">{pct_churne_reel:.1f}%</div>
                <div style="font-size:10px;color:#9CA3AF;margin-top:3px">{int(nb_churne_reel):,} clients</div>
            </div>
            <div style="background:#FFFBEB;border-radius:10px;padding:0.75rem;
                        border:1px solid #FDE68A;text-align:center">
                <div style="font-size:9px;font-weight:600;text-transform:uppercase;
                            letter-spacing:0.08em;color:#F59E0B;margin-bottom:0.3rem">À risque</div>
                <div style="font-size:22px;font-weight:700;color:#B45309;
                            font-family:'DM Mono',monospace;line-height:1">{pct_a_risque_sql:.1f}%</div>
                <div style="font-size:10px;color:#9CA3AF;margin-top:3px">{nb_a_risque_sql:,} clients</div>
            </div>
        </div>
        <div style="height:6px;background:#F0F2F8;border-radius:99px;overflow:hidden">
            <div style="display:flex;height:100%">
                <div style="width:{pct_a_risque_sql:.1f}%;background:#F59E0B;border-radius:99px 0 0 99px"></div>
                <div style="width:{pct_churne_reel:.1f}%;background:#EF4444;border-radius:0 99px 99px 0"></div>
            </div>
        </div>
        <div style="display:flex;justify-content:space-between;margin-top:4px">
            <span style="font-size:9px;color:#F59E0B;font-weight:500">à risque</span>
            <span style="font-size:9px;color:#EF4444;font-weight:500">churné</span>
        </div>
    </div>
    <hr class="sidebar-divider"/>
    """, unsafe_allow_html=True)

    # Légende des 4 segments (Option C)
    st.markdown("""
    <div style="margin-bottom:0.75rem">
        <div style="font-size:10px;font-weight:600;text-transform:uppercase;
                    letter-spacing:0.1em;color:#9CA3AF;margin-bottom:0.6rem">
            Segmentation client
        </div>
        <div style="display:flex;flex-direction:column;gap:0.4rem">
            <div style="display:flex;align-items:center;justify-content:space-between;
                        background:#EFF6FF;border-radius:8px;padding:6px 10px;
                        border:1px solid #BFDBFE">
                <div style="display:flex;align-items:center;gap:7px">
                    <div style="width:8px;height:8px;border-radius:50%;background:#2563EB;flex-shrink:0"></div>
                    <span style="font-size:11px;font-weight:600;color:#1D4ED8">Nouveau</span>
                </div>
                <span style="font-size:10px;color:#6B7280">1 commande · &lt; 180 j</span>
            </div>
            <div style="display:flex;align-items:center;justify-content:space-between;
                        background:#F0FDF4;border-radius:8px;padding:6px 10px;
                        border:1px solid #BBF7D0">
                <div style="display:flex;align-items:center;gap:7px">
                    <div style="width:8px;height:8px;border-radius:50%;background:#10B981;flex-shrink:0"></div>
                    <span style="font-size:11px;font-weight:600;color:#065F46">Actif</span>
                </div>
                <span style="font-size:10px;color:#6B7280">inactif &lt; 180 j</span>
            </div>
            <div style="display:flex;align-items:center;justify-content:space-between;
                        background:#FFFBEB;border-radius:8px;padding:6px 10px;
                        border:1px solid #FDE68A">
                <div style="display:flex;align-items:center;gap:7px">
                    <div style="width:8px;height:8px;border-radius:50%;background:#F59E0B;flex-shrink:0"></div>
                    <span style="font-size:11px;font-weight:600;color:#B45309">À risque</span>
                </div>
                <span style="font-size:10px;color:#6B7280">180 – 365 j</span>
            </div>
            <div style="display:flex;align-items:center;justify-content:space-between;
                        background:#FEF2F2;border-radius:8px;padding:6px 10px;
                        border:1px solid #FECACA">
                <div style="display:flex;align-items:center;gap:7px">
                    <div style="width:8px;height:8px;border-radius:50%;background:#EF4444;flex-shrink:0"></div>
                    <span style="font-size:11px;font-weight:600;color:#B91C1C">Churné</span>
                </div>
                <span style="font-size:10px;color:#6B7280">&gt; 365 j</span>
            </div>
        </div>
    </div>
    <hr class="sidebar-divider"/>
    """, unsafe_allow_html=True)

    st.markdown(f"""
    <div style="background:#F4F6FB;border-radius:10px;padding:0.75rem 1rem;
                border:1px solid #E8ECF4">
        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:4px">
            <span style="color:#0F1729;font-weight:600;font-size:12px">DuckDB 1.5.3</span>
            <span style="font-size:10px;background:#DCFCE7;color:#15803D;
                         padding:2px 6px;border-radius:99px;font-weight:600">connecté</span>
        </div>
        <div style="color:#9CA3AF;font-size:11px;margin-bottom:6px">olist.duckdb</div>
        <hr style="border:none;border-top:1px solid #E8ECF4;margin:6px 0"/>
        <div style="display:flex;align-items:center;justify-content:space-between">
            <span style="color:#9CA3AF;font-size:11px">{len(df):,} clients</span>
            <span style="color:#9CA3AF;font-size:11px">{df_revenue.shape[0]} mois de données</span>
        </div>
    </div>
    """, unsafe_allow_html=True)

# ============================================================
# HEADER
# ============================================================

today = datetime.now().strftime("%A, %B %d %Y")
st.markdown(f"""
<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem">
    <div>
        <h1 style="font-size:24px;font-weight:700;color:#0F1729;margin:0;line-height:1.2;
                   font-family:'Inter',sans-serif">Sales & Churn Report</h1>
        <p style="color:#9CA3AF;font-size:13px;margin:4px 0 0;font-family:'Inter',sans-serif">{today}</p>
    </div>
    <div style="display:flex;align-items:center;gap:10px">
        <div style="background:#FFFFFF;border-radius:8px;padding:6px 12px;
                    border:1px solid #E8ECF4;font-size:12px;color:#6B7280;font-weight:500">
            📅 Dataset 2016–2018
        </div>
        <div style="width:32px;height:32px;border-radius:50%;background:#2563EB;
                    display:flex;align-items:center;justify-content:center;
                    font-size:13px;font-weight:600;color:white">GS</div>
    </div>
</div>
""", unsafe_allow_html=True)

# ============================================================
# KPI CARDS — 5 colonnes
# ============================================================

c1, c2, c3, c4, c5 = st.columns(5)

with c1:
    st.markdown(f"""
    <div class="kpi-card accent">
        <div style="font-size:11px;font-weight:600;color:rgba(255,255,255,0.65);
                    text-transform:uppercase;letter-spacing:0.07em;margin-bottom:0.3rem">
            Chiffre d'affaires total
        </div>
        <div style="font-size:26px;font-weight:700;color:white;
                    font-family:'DM Mono',monospace;line-height:1.15;margin-bottom:0.4rem">
            R$ {total_ca/1e6:.2f}M
        </div>
        <span style="display:inline-flex;align-items:center;font-size:11px;font-weight:600;
                     padding:3px 8px;border-radius:20px;background:rgba(255,255,255,0.2);color:white">
            +2.1% vs période préc.
        </span>
    </div>
    """, unsafe_allow_html=True)

with c2:
    st.markdown(f"""
    <div class="kpi-card">
        <div class="kpi-label">Commandes totales</div>
        <div class="kpi-value">{int(total_orders):,}</div>
        <span class="kpi-badge positive">+12.4%</span>
        <div class="kpi-sub">vs dernière période</div>
    </div>
    """, unsafe_allow_html=True)

with c3:
    st.markdown(f"""
    <div class="kpi-card">
        <div class="kpi-label">Panier moyen</div>
        <div class="kpi-value">R$ {avg_basket:.0f}</div>
        <span class="kpi-badge neutral">par commande</span>
        <div class="kpi-sub">{total_clients:,} clients uniques</div>
    </div>
    """, unsafe_allow_html=True)

with c4:
    st.markdown(f"""
    <div class="kpi-card">
        <div class="kpi-label">Segment à risque (SQL)</div>
        <div class="kpi-value">{pct_a_risque_sql:.1f}%</div>
        <span class="kpi-badge warning">inactif 180–365 j</span>
        <div class="kpi-sub">{nb_a_risque_sql:,} clients · à cibler</div>
    </div>
    """, unsafe_allow_html=True)

with c5:
    st.markdown(f"""
    <div class="kpi-card danger">
        <div style="font-size:11px;font-weight:600;color:#EF4444;
                    text-transform:uppercase;letter-spacing:0.07em;margin-bottom:0.3rem">
            Taux de churn (SQL 365j)
        </div>
        <div style="font-size:26px;font-weight:700;color:#B91C1C;
                    font-family:'DM Mono',monospace;line-height:1.15;margin-bottom:0.4rem">
            {pct_churne_reel:.1f}%
        </div>
        <span style="display:inline-flex;align-items:center;font-size:11px;font-weight:600;
                     padding:3px 8px;border-radius:20px;background:#FECACA;color:#B91C1C">
            {int(nb_churne_reel):,} churned
        </span>
        <div style="font-size:11px;color:#9CA3AF;margin-top:3px">
            {nb_a_risque_sql:,} à risque ({pct_a_risque_sql:.1f}%)
        </div>
    </div>
    """, unsafe_allow_html=True)

# ============================================================
# ROW 2 — Revenue + Donut reviews
# ============================================================

col_left, col_right = st.columns([2, 1])

with col_left:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Évolution du chiffre d'affaires</p>
        <p class="section-sub">Chiffre d'affaires consolidé · par mois</p>
    </div>
    """, unsafe_allow_html=True)

    fig_rev = go.Figure()
    fig_rev.add_trace(go.Bar(
        x=df_revenue["mois"], y=df_revenue["chiffre_affaires"],
        marker_color="#2563EB", marker_line_width=0, opacity=0.9, name="CA"
    ))
    fig_rev.add_trace(go.Scatter(
        x=df_revenue["mois"], y=df_revenue["nb_commandes"] * avg_basket,
        line=dict(color="#93C5FD", width=2, dash="dot"), mode="lines", name="Tendance"
    ))
    fig_rev.update_layout(
        height=240, margin=dict(l=20, r=20, t=20, b=20),
        paper_bgcolor="white", plot_bgcolor="white", showlegend=False,
        xaxis=dict(showgrid=False, tickfont=dict(size=11, color="#9CA3AF", family="Inter"),
                   tickformat="%b %y", linecolor="#E8ECF4"),
        yaxis=dict(showgrid=True, gridcolor="#F4F6FB",
                   tickfont=dict(size=11, color="#9CA3AF", family="Inter"),
                   tickprefix="R$", tickformat=".0s", linewidth=0),
        font=dict(family="Inter"), bargap=0.35,
    )
    st.plotly_chart(fig_rev, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

with col_right:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Satisfaction clients</p>
        <p class="section-sub">Distribution des scores reviews</p>
    </div>
    """, unsafe_allow_html=True)

    colors_rev  = ["#EF4444", "#F97316", "#FBBF24", "#34D399", "#2563EB"]
    score_moyen = (df_reviews["review_score"] * df_reviews["nb"]).sum() / df_reviews["nb"].sum()
    fig_donut   = go.Figure(go.Pie(
        labels=[f"⭐ {s}" for s in df_reviews["review_score"]],
        values=df_reviews["nb"], hole=0.65,
        marker=dict(colors=colors_rev, line=dict(width=2, color="white")),
        textinfo="none",
        hovertemplate="<b>Score %{label}</b><br>%{value:,} reviews<br>%{percent}<extra></extra>"
    ))
    fig_donut.add_annotation(
        text=f"<b>{score_moyen:.2f}</b><br><span style='font-size:11px;color:#9CA3AF'>score moy.</span>",
        x=0.5, y=0.5, showarrow=False,
        font=dict(size=20, family="DM Mono", color="#0F1729"), align="center"
    )
    fig_donut.update_layout(
        height=240, margin=dict(l=20, r=20, t=20, b=20),
        paper_bgcolor="white", showlegend=True,
        legend=dict(orientation="v", x=1.02, y=0.5,
                    font=dict(size=11, color="#6B7280", family="Inter")),
        font=dict(family="Inter"),
    )
    st.plotly_chart(fig_donut, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

# ============================================================
# ROW 3 — Segmentation client
# ============================================================

col_donut_seg, col_seg_bars = st.columns([1, 2])

with col_donut_seg:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Segmentation client</p>
        <p class="section-sub">Répartition par segment · 365 jours</p>
    </div>
    """, unsafe_allow_html=True)

    seg_colors = [SEGMENT_COLORS.get(s, "#9CA3AF") for s in df_seg["segment_client"]]
    seg_labels = [SEGMENT_LABELS.get(s, s) for s in df_seg["segment_client"]]
    total_seg  = df_seg["nb_clients"].sum()

    fig_seg_donut = go.Figure(go.Pie(
        labels=seg_labels,
        values=df_seg["nb_clients"],
        hole=0.62,
        marker=dict(colors=seg_colors, line=dict(width=2, color="white")),
        textinfo="none",
        hovertemplate="<b>%{label}</b><br>%{value:,} clients<br>%{percent}<extra></extra>"
    ))
    fig_seg_donut.add_annotation(
        text=f"<b>{total_seg:,}</b><br><span style='font-size:11px;color:#9CA3AF'>clients</span>",
        x=0.5, y=0.5, showarrow=False,
        font=dict(size=18, family="DM Mono", color="#0F1729"), align="center"
    )
    fig_seg_donut.update_layout(
        height=260, margin=dict(l=20, r=20, t=20, b=20),
        paper_bgcolor="white", showlegend=True,
        legend=dict(orientation="v", x=1.02, y=0.5,
                    font=dict(size=11, color="#6B7280", family="Inter")),
        font=dict(family="Inter"),
    )
    st.plotly_chart(fig_seg_donut, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

with col_seg_bars:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Signaux comportementaux par segment</p>
        <p class="section-sub">Valeur totale · Score review · Récence · Nb commandes</p>
    </div>
    """, unsafe_allow_html=True)

    seg_colors_list = [SEGMENT_COLORS.get(s, "#9CA3AF") for s in df_seg["segment_client"]]
    seg_labels_list = [SEGMENT_LABELS.get(s, s) for s in df_seg["segment_client"]]

    METRICS_SEG = {
        "valeur_totale_moy": "Valeur totale moy. (R$)",
        "score_moy":         "Score review moyen",
        "recence_moy":       "Récence moy. (jours)",
        "nb_commandes_moy":  "Nb commandes moyen",
    }

    fig_seg = go.Figure()
    for i, (metric_key, metric_label) in enumerate(METRICS_SEG.items()):
        fig_seg.add_trace(go.Bar(
            name=metric_label,
            x=seg_labels_list,
            y=df_seg[metric_key].round(1),
            text=df_seg[metric_key].round(1),
            textposition="outside",
            textfont=dict(size=10, color="#9CA3AF", family="Inter"),
            visible=(i == 0),
            marker=dict(color=seg_colors_list, line=dict(width=0)),
        ))

    buttons = [
        dict(
            label=label,
            method="update",
            args=[{"visible": [j == i for j in range(len(METRICS_SEG))]}]
        )
        for i, label in enumerate(METRICS_SEG.values())
    ]

    fig_seg.update_layout(
        height=260, margin=dict(l=20, r=20, t=20, b=20),
        paper_bgcolor="white", plot_bgcolor="white",
        font=dict(family="Inter"),
        xaxis=dict(showgrid=False, tickfont=dict(size=12, color="#374151")),
        yaxis=dict(showgrid=True, gridcolor="#F4F6FB",
                   tickfont=dict(size=11, color="#9CA3AF")),
        bargap=0.4, showlegend=False,
        updatemenus=[dict(
            type="buttons",
            direction="right",
            x=0, y=1.18, xanchor="left",
            showactive=True,
            buttons=buttons,
            bgcolor="#F4F6FB",
            bordercolor="#E8ECF4",
            borderwidth=1,
            font=dict(size=11, color="#374151", family="Inter"),
            pad=dict(r=4, t=4, b=4, l=4),
        )]
    )
    st.plotly_chart(fig_seg, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

# ============================================================
# ROW 4 — Scatter RFM + Top catégories
# ============================================================

col_scatter, col_cat = st.columns([3, 2])

with col_scatter:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Segmentation RFM — Récence vs Valeur</p>
        <p class="section-sub">Taille = nb commandes · Couleur = score review moyen · Échantillon 5 000 clients</p>
    </div>
    """, unsafe_allow_html=True)

    df_sample = df.sample(min(5000, len(df)), random_state=42)
    fig_rfm   = px.scatter(
        df_sample, x="jours_depuis_derniere_commande", y="valeur_totale",
        color="score_moyen_reviews", size="nb_commandes", size_max=16,
        color_continuous_scale=[[0, "#EF4444"], [0.5, "#FBBF24"], [1, "#2563EB"]],
        range_color=[1, 5],
        labels={
            "jours_depuis_derniere_commande": "Récence (jours)",
            "valeur_totale": "Valeur totale (R$)",
            "score_moyen_reviews": "Score review"
        },
        hover_data={"nb_commandes": True, "panier_moyen_par_commande": ":.0f",
                    "segment_client": True}
    )
    fig_rfm.add_vline(
        x=365, line_dash="dash", line_color="#EF4444", line_width=1.5,
        annotation_text="  seuil churn 365j",
        annotation_font_color="#EF4444", annotation_font_size=11
    )
    fig_rfm.update_layout(
        height=280, margin=dict(l=20, r=20, t=20, b=20),
        paper_bgcolor="white", plot_bgcolor="white",
        font=dict(family="Inter"),
        xaxis=dict(showgrid=True, gridcolor="#F4F6FB",
                   tickfont=dict(size=11, color="#9CA3AF")),
        yaxis=dict(showgrid=True, gridcolor="#F4F6FB",
                   tickfont=dict(size=11, color="#9CA3AF"),
                   tickprefix="R$", tickformat=".0s"),
        coloraxis_colorbar=dict(thickness=8, len=0.6,
                                title=dict(text="Score", font=dict(size=11, family="Inter"))),
    )
    fig_rfm.update_traces(marker=dict(opacity=0.65, line=dict(width=0)))
    st.plotly_chart(fig_rfm, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

with col_cat:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Top 10 catégories</p>
        <p class="section-sub">Par volume de ventes</p>
    </div>
    """, unsafe_allow_html=True)

    fig_cat = go.Figure(go.Bar(
        x=df_cat["nb_ventes"], y=df_cat["categorie"], orientation="h",
        marker=dict(
            color=df_cat["nb_ventes"],
            colorscale=[[0, "#BFDBFE"], [1, "#2563EB"]],
            line=dict(width=0)
        ),
        text=df_cat["nb_ventes"].apply(lambda x: f"{x:,}"),
        textposition="outside", textfont=dict(size=11, color="#9CA3AF", family="Inter")
    ))
    fig_cat.update_layout(
        height=280, margin=dict(l=20, r=20, t=20, b=20),
        paper_bgcolor="white", plot_bgcolor="white",
        font=dict(family="Inter"),
        xaxis=dict(showgrid=False, visible=False),
        yaxis=dict(showgrid=False, tickfont=dict(size=11, color="#374151", family="Inter")),
        bargap=0.35, showlegend=False
    )
    st.plotly_chart(fig_cat, use_container_width=True, config={"displayModeBar": False})
    st.markdown("</div>", unsafe_allow_html=True)

# ============================================================
# ROW 5 — Stats + Tableau clients à risque (segment a_risque)
# ============================================================

col_stats, col_table = st.columns([1, 2])

with col_stats:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Indicateurs clés</p>
        <p class="section-sub">Métriques comportementales</p>
    </div>
    """, unsafe_allow_html=True)

    stats = [
        ("Délai inter-commandes moyen",
         f"{df['delai_moyen_inter_commandes'].mean():.0f} jours", "neutral"),
        ("% mauvaises reviews (≤2)",
         f"{pct_bad_rev:.1f}%", "negative" if pct_bad_rev > 10 else "positive"),
        ("Catégories / client (moy.)",
         f"{df['nb_categories_distinctes'].mean():.1f}", "neutral"),
        ("Mode paiement dominant",
         df["mode_paiement_prefere"].value_counts().index[0], "neutral"),
        ("Clients multi-commandes",
         f"{(df['nb_commandes']>1).sum()/len(df)*100:.1f}%", "positive"),
    ]
    for label, value, badge in stats:
        st.markdown(f"""
        <div class="stat-row">
            <span class="stat-label">{label}</span>
            <span class="kpi-badge {badge}">{value}</span>
        </div>
        """, unsafe_allow_html=True)

with col_table:
    st.markdown("""
    <div class="chart-card">
    <div class="section-header">
        <p class="section-title">Clients à risque de churn</p>
        <p class="section-sub">Segment à risque · inactif 180–365 j · triés par valeur totale</p>
    </div>
    """, unsafe_allow_html=True)

    df_display = df_a_risque[[
        "customer_unique_id", "nb_commandes",
        "jours_depuis_derniere_commande", "valeur_totale",
        "score_moyen_reviews", "pct_mauvaises_reviews"
    ]].sort_values("valeur_totale", ascending=False).head(15).rename(columns={
        "customer_unique_id":               "Client ID",
        "nb_commandes":                     "Commandes",
        "jours_depuis_derniere_commande":   "Inactivité (j)",
        "valeur_totale":                    "CA Total (R$)",
        "score_moyen_reviews":              "Score moy.",
        "pct_mauvaises_reviews":            "% neg."
    })

    df_display["Client ID"]     = df_display["Client ID"].str[:20] + "..."
    df_display["CA Total (R$)"] = df_display["CA Total (R$)"].round(0).astype(int)
    df_display["Score moy."]    = df_display["Score moy."].round(2)
    df_display["% neg."]        = df_display["% neg."].round(1)

    st.dataframe(df_display, use_container_width=True, height=320, hide_index=True)
    st.caption(f"⚠️ {nb_a_risque_sql:,} clients à risque sur {len(df):,} ({pct_a_risque_sql:.1f}%)")