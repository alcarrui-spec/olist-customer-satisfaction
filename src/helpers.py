"""
Small helpers used by notebooks/analysis.ipynb.

- run_sql_file(): runs every query in a .sql file and returns pandas DataFrames
- build_order_level(): materializes sql/02_order_level_dataset.sql as a table
- ols(): ordinary least squares with robust (HC1) standard errors and p-values,
  written with numpy/scipy so the math is visible (statsmodels gives the same
  numbers: sm.OLS(y, X).fit(cov_type="HC1"))
"""
import sqlite3
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "data" / "olist.db"
SQL_DIR = ROOT / "sql"


def connect() -> sqlite3.Connection:
    if not DB_PATH.exists():
        raise FileNotFoundError("Run `python src/build_database.py` first.")
    return sqlite3.connect(DB_PATH)


def _split_statements(sql_text: str) -> list[str]:
    """Split a .sql file on ';' and drop comment-only chunks."""
    statements = []
    for chunk in sql_text.split(";"):
        code = "\n".join(l for l in chunk.splitlines() if not l.strip().startswith("--")).strip()
        if code:
            statements.append(chunk.strip())
    return statements


def run_sql_file(con: sqlite3.Connection, name: str) -> list[pd.DataFrame]:
    """Run each query in sql/<name> and return one DataFrame per query."""
    text = (SQL_DIR / name).read_text()
    return [pd.read_sql(statement, con) for statement in _split_statements(text)]


def build_order_level(con: sqlite3.Connection) -> None:
    """Save the 7-table join from 02_order_level_dataset.sql as table order_level."""
    query = (SQL_DIR / "02_order_level_dataset.sql").read_text().strip().rstrip(";")
    con.execute("DROP TABLE IF EXISTS order_level")
    con.execute(f"CREATE TABLE order_level AS {query}")
    con.commit()


def ols(y: pd.Series, X: pd.DataFrame) -> tuple[pd.DataFrame, float, int]:
    """
    OLS regression with an intercept and HC1 robust standard errors.
    Returns (coefficient table, R-squared, n).
    Robust errors are used because review scores (1-5) have unequal variance
    across groups, which makes ordinary standard errors too optimistic.
    """
    Xc = np.column_stack([np.ones(len(X)), X.to_numpy(dtype=float)])
    yv = y.to_numpy(dtype=float)
    n, k = Xc.shape
    xtx_inv = np.linalg.inv(Xc.T @ Xc)
    beta = xtx_inv @ Xc.T @ yv
    resid = yv - Xc @ beta
    meat = Xc.T @ (Xc * (resid ** 2)[:, None])
    cov = xtx_inv @ meat @ xtx_inv * n / (n - k)
    se = np.sqrt(np.diag(cov))
    t = beta / se
    p = 2 * stats.t.sf(np.abs(t), df=n - k)
    r2 = 1 - (resid @ resid) / ((yv - yv.mean()) @ (yv - yv.mean()))
    table = pd.DataFrame(
        {"coef": beta, "std_err": se, "t": t, "p_value": p,
         "ci_low": beta - 1.96 * se, "ci_high": beta + 1.96 * se},
        index=["intercept", *X.columns],
    )
    return table, r2, n
