-- Legacy Logic Rescue
-- Synthetic CI test dataset
-- Not production or client data.

INSERT INTO legacy.sales_v1 (
    sale_key,
    customer_key,
    stock_item_key,
    invoice_date,
    quantity,
    unit_price,
    total_excluding_tax,
    tax_amount,
    total_including_tax,
    profit
)
VALUES
    (
        1, 0, 10, '2000-01-31',
        1, 10.49, 10.49, 1.57, 12.06, 2.00
    ),
    (
        2, 7, 10, '2000-02-01',
        1, 20.49, 20.49, 3.07, 23.56, 4.00
    ),
    (
        3, 7, 11, '2000-02-15',
        1, 30.10, 30.10, 4.52, 34.62, 5.00
    ),
    (
        4, 0, 12, '2000-02-29',
        1, 5.50, 5.50, 0.83, 6.33, 1.00
    );
