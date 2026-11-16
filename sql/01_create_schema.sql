-- Legacy Logic Rescue
-- Frozen sales baseline schema

CREATE SCHEMA IF NOT EXISTS legacy;

CREATE TABLE IF NOT EXISTS legacy.sales_v1 (
    sale_key BIGINT PRIMARY KEY,
    customer_key INTEGER,
    stock_item_key INTEGER,
    invoice_date DATE NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(18, 2),
    total_excluding_tax NUMERIC(20, 2) NOT NULL,
    tax_amount NUMERIC(20, 2) NOT NULL,
    total_including_tax NUMERIC(20, 2) NOT NULL,
    profit NUMERIC(20, 2)
);
