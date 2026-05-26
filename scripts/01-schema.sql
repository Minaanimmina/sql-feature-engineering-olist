-- 01-schema.sql
-- Schéma DDL pour le dataset Olist
-- Choix des types basés sur l'exploration des CSV (00-exploration.sql)
-- NUMERIC(10,2) pour les montants financiers (évite les erreurs flottantes)
-- Colonnes nullable là où l'exploration a révélé des valeurs manquantes

CREATE TABLE IF NOT EXISTS customers (
    customer_id              VARCHAR PRIMARY KEY,
    customer_unique_id       VARCHAR NOT NULL,
    customer_zip_code_prefix VARCHAR,
    customer_city            VARCHAR,
    customer_state           VARCHAR
);

CREATE TABLE IF NOT EXISTS sellers (
    seller_id               VARCHAR PRIMARY KEY,
    seller_zip_code_prefix  VARCHAR,
    seller_city             VARCHAR,
    seller_state            VARCHAR
);

CREATE TABLE IF NOT EXISTS products (
    product_id                 VARCHAR PRIMARY KEY,
    product_category_name      VARCHAR,  -- 610 produits sans catégorie, nullable
    product_name_lenght        INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           NUMERIC(10,2),
    product_length_cm          NUMERIC(10,2),
    product_height_cm          NUMERIC(10,2),
    product_width_cm           NUMERIC(10,2)
);

CREATE TABLE IF NOT EXISTS product_category_name_translation (
    product_category_name         VARCHAR PRIMARY KEY,
    product_category_name_english VARCHAR NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
    order_id                      VARCHAR PRIMARY KEY,
    customer_id                   VARCHAR NOT NULL REFERENCES customers(customer_id),
    order_status                  VARCHAR NOT NULL,
    order_purchase_timestamp      TIMESTAMP NOT NULL,
    order_approved_at             TIMESTAMP,  -- 160 commandes sans approbation
    order_delivered_carrier_date  TIMESTAMP,  -- 1783 valeurs manquantes
    order_delivered_customer_date TIMESTAMP,  -- 2965 valeurs manquantes
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    order_id            VARCHAR  NOT NULL REFERENCES orders(order_id),
    order_item_id       INTEGER  NOT NULL,
    product_id          VARCHAR  NOT NULL REFERENCES products(product_id),
    seller_id           VARCHAR  NOT NULL REFERENCES sellers(seller_id),
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2) NOT NULL,
    freight_value       NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS order_payments (
    order_id             VARCHAR  NOT NULL REFERENCES orders(order_id),
    payment_sequential   INTEGER  NOT NULL,
    payment_type         VARCHAR  NOT NULL,
    payment_installments INTEGER,
    payment_value        NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE IF NOT EXISTS order_reviews (
    review_id               VARCHAR PRIMARY KEY,
    order_id                VARCHAR NOT NULL REFERENCES orders(order_id),
    review_score            INTEGER NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    VARCHAR,  -- souvent NULL
    review_comment_message  VARCHAR,  -- souvent NULL
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);