"""
Quick interactive DuckDB explorer.
Run: python3 explore.py
Then type SQL queries at the prompt.  Type 'schemas', 'tables', or 'exit'.
"""
import duckdb
import numpy as np
import pandas as pd
import sys

DB_PATH = "interview.duckdb"

print(f"\nConnected to {DB_PATH}")
print("Commands: schemas | tables | tables <schema> | exit | any SQL\n")

con = duckdb.connect(DB_PATH, read_only=True)

while True:
    try:
        raw = input("duckdb> ").strip()
    except (EOFError, KeyboardInterrupt):
        break

    if not raw:
        continue

    if raw.lower() == "exit":
        break

    if raw.lower() == "schemas":
        raw = "SELECT schema_name FROM information_schema.schemata ORDER BY 1"

    elif raw.lower() == "tables":
        raw = """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema NOT IN ('information_schema', 'pg_catalog', 'main')
            ORDER BY table_schema, table_name
        """

    elif raw.lower().startswith("tables "):
        schema = raw.split(" ", 1)[1].strip()
        raw = f"SHOW TABLES FROM {schema}"

    try:
        result = con.execute(raw).fetchdf()
        print(result.to_string(index=False))
        print(f"\n({len(result)} rows)\n")
    except Exception as e:
        print(f"Error: {e}\n")

con.close()
print("Bye.")