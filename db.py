from sqlalchemy import create_engine, text
import pandas as pd

DB_URL = "postgresql+psycopg2://localhost/airline_db"

engine = create_engine(DB_URL)

def run_query(query, params=None):
    with engine.connect() as conn:
        result = conn.execute(text(query), params or {})
        conn.commit()
        return result

def fetch_df(query, params=None):
    with engine.connect() as conn:
        return pd.read_sql(text(query), conn, params=params)