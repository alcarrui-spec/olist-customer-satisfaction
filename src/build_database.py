"""
Step 1: Load the nine Olist CSV files into a local SQLite database.

Why SQLite: it's a real SQL database that ships with Python, so anyone can
clone this repo and run every query without installing a database server.

Run from the project root:
    python src/build_database.py
"""
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
DB_PATH = ROOT / "data" / "olist.db"

# CSV file -> table name in the database
TABLES = {
    "olist_customers_dataset.csv": "customers",
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_order_payments_dataset.csv": "payments",
    "olist_order_reviews_dataset.csv": "reviews",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "product_category_name_translation.csv": "category_translation",
    "olist_geolocation_dataset.csv": "geolocation",
}

# Indexes on the join keys keep the joins in sql/ fast (seconds, not minutes)
INDEXES = [
    "CREATE INDEX IF NOT EXISTS ix_orders_order ON orders(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_orders_customer ON orders(customer_id)",
    "CREATE INDEX IF NOT EXISTS ix_items_order ON order_items(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_items_seller ON order_items(seller_id)",
    "CREATE INDEX IF NOT EXISTS ix_items_product ON order_items(product_id)",
    "CREATE INDEX IF NOT EXISTS ix_payments_order ON payments(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_reviews_order ON reviews(order_id)",
    "CREATE INDEX IF NOT EXISTS ix_customers_customer ON customers(customer_id)",
    "CREATE INDEX IF NOT EXISTS ix_products_product ON products(product_id)",
    "CREATE INDEX IF NOT EXISTS ix_sellers_seller ON sellers(seller_id)",
]


def main() -> None:
    if DB_PATH.exists():
        DB_PATH.unlink()  # rebuild from scratch every time, so results are reproducible
    con = sqlite3.connect(DB_PATH)
    for csv_name, table in TABLES.items():
        path = RAW / csv_name
        if not path.exists():
            if table == "geolocation":
                print(f"  skipped {csv_name} (optional, not used in the analysis)")
                continue
            raise FileNotFoundError(f"Missing {path}. See README: download the data from Kaggle first.")
        df = pd.read_csv(path)
        df.to_sql(table, con, index=False)
        print(f"  loaded {table:<22} {len(df):>9,} rows")
    for statement in INDEXES:
        con.execute(statement)
    con.commit()
    con.close()
    print(f"Database written to {DB_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
