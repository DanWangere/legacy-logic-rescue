import os
from decimal import Decimal

import psycopg
import pytest


@pytest.fixture(scope="module")
def db():
    """Connect to the isolated CI database."""
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn:
        yield conn


def query_one(db, sql):
    with db.cursor() as cursor:
        cursor.execute(sql)
        return cursor.fetchone()


def test_source_baseline(db):
    """The frozen synthetic fixture has exact values."""
    result = query_one(db, """
        SELECT
            COUNT(*),
            COUNT(DISTINCT sale_key),
            SUM(total_excluding_tax),
            COUNT(*) FILTER (WHERE customer_key = 0)
        FROM legacy.sales_v1
    """)

    assert result == (
        4,
        4,
        Decimal("66.58"),
        2,
    )


def test_trusted_v1_report(db):
    """Trusted V1 must preserve all sales and revenue."""
    result = query_one(db, """
        SELECT
            SUM(sale_count),
            SUM(sales_excluding_tax)
        FROM legacy.v_monthly_sales_v1
    """)

    assert result == (4, Decimal("66.58"))


def test_v1_seeded_defect_is_detectable(db):
    """
    The deliberately defective view must omit unknown
    customers. This is benchmark detection, not approval
    of the defective reporting rule.
    """
    result = query_one(db, """
        SELECT
            SUM(sale_count),
            SUM(sales_excluding_tax)
        FROM legacy.v_monthly_sales_bug01
    """)

    assert result == (2, Decimal("50.59"))


def test_v2_reference_preserves_source(db):
    """Priority-based mapping must prevent duplication."""
    result = query_one(db, """
        SELECT
            SUM(sale_count),
            SUM(sales_excluding_tax)
        FROM legacy.v_monthly_sales_reference_v2
    """)

    assert result == (4, Decimal("66.58"))

    promotional = query_one(db, """
        SELECT
            SUM(sale_count),
            SUM(sales_excluding_tax)
        FROM legacy.v_monthly_sales_reference_v2
        WHERE item_group = 'PROMOTIONAL'
    """)

    assert promotional == (2, Decimal("30.98"))


def test_v2_join_multiplication_detected(db):
    """The unguarded join produces two additional rows."""
    result = query_one(db, """
        SELECT
            COUNT(*) - COUNT(DISTINCT s.sale_key)
        FROM legacy.sales_v1 s
        LEFT JOIN legacy.item_group_map_v2 m
            ON s.stock_item_key = m.stock_item_key
    """)

    assert result[0] == 2


def test_v2_month_shift_detected(db):
    """Two transactions cross a reporting-month boundary."""
    result = query_one(db, """
        SELECT COUNT(*)
        FROM legacy.sales_v1
        WHERE DATE_TRUNC('month', invoice_date)
           <> DATE_TRUNC(
                'month',
                invoice_date + INTERVAL '1 day'
           )
    """)

    assert result[0] == 2


def test_v2_rounding_difference_detected(db):
    """Per-row rounding changes the original sales total."""
    result = query_one(db, """
        SELECT
            SUM(
                ROUND(total_excluding_tax, 0)
                - total_excluding_tax
            )
        FROM legacy.sales_v1
    """)

    assert result[0] == Decimal("-0.58")


def test_v2_candidate_is_not_approved_reference(db):
    """
    Verify that our intentionally defective benchmark
    candidate remains distinguishable from the reference.
    """
    result = query_one(db, """
        SELECT
            SUM(sale_count),
            SUM(sales_excluding_tax)
        FROM legacy.v_monthly_sales_candidate_v2
    """)

    assert result == (6, Decimal("96.00"))
