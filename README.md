# CDW Data Engineering Interview Assignment

A self-contained data platform environment built with **DuckDB + dbt**, modelling a simplified version of the CDW (Client Data Warehouse) data mesh.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│  DATA MESH                                                           │
│                                                                      │
│  ┌──────────────────────────────┐                                    │
│  │  IDW (Investment Data WH)    │  ← external domain, owns           │
│  │  schema: idw_end_user        │    instrument & portfolio refs     │
│  └──────────────────┬───────────┘                                    │
│                     │ mesh boundary (CDW consumes IDW data products) │
│  ┌──────────────────▼───────────────────────────────────────────┐    │
│  │  CDW (Client Data Warehouse)                                 │    │
│  │                                                              │    │
│  │  cdw_landing      ← raw ingestion (holdings, performance)    │    │
│  │       ↓                                                      │    │
│  │  cdw_staging                                                 │    │
│  │  (lv01_build)     ← S1: join sources, instrument grain       │    │
│  │  (lv02_modelling)   S2: aggregate & transform    * TASKS 1&2 │    │
│  │       ↓                                                      │    │
│  │  cdw_reporting    ← consumer-facing reporting views          │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

### DuckDB schemas

| Schema          | Layer         | Contents                                               |
|-----------------|---------------|--------------------------------------------------------|
| `idw_landing`   | Seeds         | Raw CSV data loaded by `dbt seed`                      |
| `idw_staging`   | IDW Staging   | Cleansed, validated instrument and portfolio data      |
| `idw_end_user`  | IDW End-User  | Trusted reference data products exposed to the mesh    |
| `cdw_landing`   | CDW Landing   | Pass-through views from IDW + calendar reference table |
| `cdw_staging`   | CDW Staging   | S1 joins (lv01) and S2 aggregations (lv02)             |
| `cdw_reporting` | CDW End-User  | Consumer-facing reporting views                        |

### Data coverage

| Dataset                 | Content                                                         |
|-------------------------|-----------------------------------------------------------------|
| 20 instruments          | 12 equities, 8 bonds across North America, Europe, Asia Pacific |
| 6 portfolios            | 3 managed funds (FUND_A/B/C) + 3 benchmark indices              |
| ~3,700 holding rows     | Jan–Mar 2025, all business days                                 |
| ~3,700 performance rows | Matching daily returns and contribution figures                 |

## Quick start

```bash
# First time
bash setup.sh

# Activate environment
source .venv/bin/activate          # Linux/Mac/Git Bash
source .config/.env.dev            # Load environment variables

# Read the assignment
cat TASKS.md

# Run a specific model
dbt run  --profiles-dir profile --project-dir . -s <model_name>
dbt test --profiles-dir profile --project-dir . -s <model_name>

# Full run + test
dbt run  --profiles-dir profile --project-dir .
dbt test --profiles-dir profile --project-dir .

# Generate and browse documentation
dbt docs generate --profiles-dir profile --project-dir .
dbt docs serve    --profiles-dir profile --project-dir . --port 8080

# Explore the data interactively
python explore.py
```

## File map

```
.
├── TASKS.md                        ← candidate assignment
├── setup.sh                        ← one-shot environment bootstrap
├── generate_data.py                ← deterministic seed CSV generator (random.seed(42))
├── explore.py                      ← interactive DuckDB REPL (read-only)
├── dbt_project.yml                 ← schema routing and materialisation config
├── packages.yml                    ← dbt package dependencies (dbt_utils)
├── requirements.txt
│
├── profile/
│   └── profiles.yml                ← DuckDB connection (path: interview.duckdb)
│
├── .config/
│   └── .env.dev                    ← environment variables (DBT_PROFILES_DIR, etc.)
│
├── macros/
│   └── generate_schema_name.sql    ← prevents dbt from prefixing schemas with 'main_'
│
├── seeds/                          ← raw CSV data, loaded into idw_landing schema
│   ├── idw_raw_instruments.csv + .yml
│   ├── idw_raw_portfolios.csv  + .yml
│   ├── idw_raw_holdings.csv    + .yml
│   └── idw_raw_performance.csv + .yml
│
├── models/
│   ├── idw/                        ← Investment Data Warehouse domain (external node)
│   │   ├── staging/                ← cleanse and validate raw seed data
│   │   │   ├── idw_stg_instruments.sql
│   │   │   ├── idw_stg_portfolios.sql
│   │   │   ├── idw_stg_holdings.sql
│   │   │   └── idw_stg_performance.sql
│   │   ├── end_user/               ← IDW data products exposed to the mesh
│   │   │   └── idw_eu__portfolio_holdings.sql
│   │   └── schema.yml
│   │
│   └── cdw/                        ← Client Data Warehouse domain (candidate work)
│       ├── landing/                ← pass-through views from idw_landing source
│       │   ├── sources.yml         ← source declarations for idw_landing tables
│       │   ├── cdw_raw_instruments.sql
│       │   ├── cdw_raw_portfolios.sql
│       │   ├── cdw_raw_holdings.sql
│       │   ├── cdw_raw_performance.sql
│       │   └── cdw_raw_as_of_date.sql + .yml   ← calendar / business day reference
│       ├── staging/
│       │   └── lv01_build/         ← S1: join and enrich (instrument-level grain)
│       │       └── cdw_stg__hld_lv01_holdings_classified.sql
│       │   └── lv02_modelling/     ← S2: aggregate and transform  ★ TASKS 1 & 2
│       ├── end_user/               ← consumer-facing reporting views  ★ TASK output
│       └── schema.yml              ← CDW model docs and tests
│
└── tests/
    └── generic/
        └── unique_combination.sql  ← custom generic test
```

## Requirements

- Python 3.10+
- Git Bash or any POSIX shell (Windows: use Git Bash or WSL)
- Internet access to install packages from PyPI