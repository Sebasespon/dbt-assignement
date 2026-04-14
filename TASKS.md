# CDW Data Engineering — Interview Assignment

Welcome to the CDW data engineering interview assignment.

This repository contains a working, simplified version of the **CDW (Client Data Warehouse)** data platform. 
Before starting the exercises, take 10–15 minutes to explore the codebase and understand the ecosystem you are working in.

---

## Environment Overview

The platform is built with **dbt-core** running on top of a local **DuckDB** database (`interview.duckdb`), in replacement of our current Snowflake environment.

### Project layout

```
models/
  idw/              ← Investment Data Warehouse domain (external data mesh node)
    staging/        ← IDW cleans and standardises raw seed data
    end_user/       ← IDW exposes trusted data products to their data consumers
  cdw/              ← Client Data Warehouse domain (our domain)
    landing/        ← Pass-through views from IDW into CDW namespace
    staging/
      lv01_build/     ← S1: join and enrich (instrument-level grain)
      lv02_modelling/ ← S2: aggregate and transform           ← YOU WILL MAINLY WORK HERE DURING THE ASSIGNMENT
    end_user/       ← Consumer-facing reporting views, exposed to our business stakeholders, the Reporting team
seeds/              ← Raw CSV data loaded into idw_landing schema
tests/
  generic/          ← Custom dbt generic tests                ← YOU MIGHT ALSO NEED TO WORK HERE DURING THE ASSIGNMENT
```

### Data domains and flow

| Domain                              | Responsibility                                                                                                                               |
|-------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| **IDW** (Investment Data Warehouse) | Owns instrument master, portfolio master, and daily market data. Exposes them as trusted data products to the mesh from their staging layer. |
| **CDW** (Client Data Warehouse)     | Owns analytics data points built for reporting consumers. Consumes IDW data products to build some of the data points.                       |

Data flows inside CDW:

```
IDW data products
      ↓
CDW Landing  (raw ingestion — direct pass-throughs, no transformation)
      ↓
Staging S1   (lv01_build) — join multiple sources, instrument-level grain
      ↓
Staging S2   (lv02_modelling) — aggregate, compound, rank
      ↓
End-User     — consumer-ready reporting views
```

### Running the project

```bash
# Full setup (first time)
bash setup.sh

# Activate the virtual environment and set the environment variables
source .venv/bin/activate          # Linux / Mac / Git Bash
.venv\Scripts\activate             # Windows CMD / PowerShell
source .config/.env.dev            # Load environment variables (e.g. DBT_PROFILES_DIR)

# Run a specific model
dbt run  --profiles-dir profile --project-dir . -s <model_name>
dbt test --profiles-dir profile --project-dir . -s <model_name>

# Explore data interactively
python explore.py
```

---

## Assignment Tasks

### Question 1 — Data Mesh (Theory · 10 min)

The architecture of this platform follows the **Data Mesh** paradigm.

During the interview meeting, answer the following:

1. What is a Data Mesh? Describe its core principles.
2. What are the main **advantages** of a Data Mesh architecture compared to a centralised data warehouse or data lake?
3. What are the main **risks and challenges** when adopting it?
4. What **best practices** would you recommend to ensure that data products remain reliable and trustworthy for their consumers?

> There is no single correct answer. We are assessing your ability to reason about architecture trade-offs, not testing memorisation.

---

### Task 1 — Portfolio Breakdown Aggregations (SQL · Medium)

**Context**

The holdings, instrument classifications, and portfolio metadata have been streamed from IDW and are already available at the **Staging S1** level in model `cdw_stg__hld_lv01_holdings_classified`. 
This model provides one row per `(market_date, portfolio_code, isin)` enriched with the full instrument hierarchy (region, sector L1, sector L2).

**What to build**

Create the following models in `models/cdw/staging/lv02_modelling/`:

| Model                            | Breakdown dimension | Group-by key                                                           |
|----------------------------------|---------------------|------------------------------------------------------------------------|
| `cdw_stg__bkd_lv02_by_region`    | Geographic region   | `region_code`, `region_name`                                           |
| `cdw_stg__bkd_lv02_by_sector_l1` | Top-level sector    | `sector_l1_code`, `sector_l1_name`                                     |
| `cdw_stg__bkd_lv02_by_sector_l2` | Sub-sector          | `sector_l1_code`, `sector_l1_name`, `sector_l2_code`, `sector_l2_name` |

Each model must produce, per `(market_date, portfolio_code, <breakdown keys>)`:
- Total weight in percent
- Total market value in base currency
- Count of distinct instruments

Additionally, create a fourth model `cdw_stg__bkd_lv02_aggregate` that `UNION ALL`s the three typed models into a single normalised table with a `breakdown_type` discriminator column (`'REGION'`, `'SECTOR_L1'`, `'SECTOR_L2'`) and generic `level_1_*` / `level_2_*` columns.

**Acceptance criteria**

```bash
dbt run  --profiles-dir profile --project-dir . -s cdw.staging.lv02_modelling
dbt test --profiles-dir profile --project-dir . -s cdw.staging.lv02_modelling
```


---

## Task 2 — Weekly Compound Returns (SQL · Medium)

**Context**

Daily instrument-level performance data (returns and contributions) has been ingested into the CDW ecosystem and is available in `cdw_raw_performance` (CDW landing layer). 
This table provides one row per `(valuation_date, portfolio_code, isin)` with `contribution_bps` representing each instrument's contribution to the portfolio's daily return.

A calendar reference table `cdw_raw_as_of_date` is available in the CDW landing zone (`cdw_landing` schema). 
It contains calendar attributes that might be relevent in the current task.

**What to build**

Create model `cdw_stg__prf_lv02_weekly_returns` in `models/cdw/staging/lv02_modelling/`.

The model must compute the **compound weekly return** for each portfolio and ISO week, using the formula:

```
R = PRODUCT(1 + ri) - 1
```

Where:
- `R` is the compound return over the week
- `ri` is the **daily portfolio return** for each business day `i` in the ISO week
- The daily portfolio return is obtained by summing `contribution_bps` across all instruments for that day

**Important:** the aggregation must only consider **business days**. Use `cdw_raw_as_of_date` to filter out weekend days before compounding.

**Output grain:** one row per `(iso_year, iso_week, portfolio_code)`.

**Acceptance criteria**

```bash
dbt run  --profiles-dir profile --project-dir . -s cdw_stg__prf_lv02_weekly_returns
dbt test --profiles-dir profile --project-dir . -s cdw_stg__prf_lv02_weekly_returns
```


---

## Task 3 — Testing Framework Assessment and Implementation (dbt · Medium)

### Part A — Assessment

Review the existing test coverage across the entire dbt project (`models/`, `seeds/`, `tests/`).

Answer the following questions:

1. What categories of tests are currently implemented (generic built-in, custom generic, singular)?
2. Running `dbt test` on the entire project, identify any **gaps** or **issues** in the test coverage.
3. Is the current test coverage **sufficient** for a production data pipeline? Justify your answer.
4. What **additional tests** would you recommend to improve data quality and pipeline reliability? Give at least three concrete examples with a brief rationale for each.

> Look at `models/cdw/schema.yml`, `models/idw/`, `seeds/*.yml`, and `tests/` to build your assessment.

### Part B — Implementation

For the three breakdown models built in Task 1, add tests to `models/cdw/schema.yml`:

1. Add `not_null` tests on the primary key columns (`market_date`, `portfolio_code`, and the breakdown dimension columns).
2. Implement a **custom generic test** `weight_sums_to_100` in `tests/generic/` that:
   - Takes a model as input
   - Groups rows by `(market_date, portfolio_code)` and sums `total_weight_pct`
   - **Fails** (returns rows) for any group where the sum deviates from 100% by more than a configurable `tolerance` parameter (default: `0.02`)
3. Apply this test at model level to each of the three typed breakdown models.

Run all tests and make sure they pass:

```bash
dbt test --profiles-dir profile --project-dir . -s cdw_stg__bkd_lv02_by_region cdw_stg__bkd_lv02_by_sector_l1 cdw_stg__bkd_lv02_by_sector_l2
```

**Important:** If the tests fail due to the new `weight_sums_to_100` test, investigate the root cause.


---

## Question 2 — Point-in-Time Historisation (Architecture Discussion)

**No code required for this question.**

Our Reporting team has a new requirement: they want to be able to **recreate any past report** exactly as it looked on the day it was originally generated — using the same data points that were available at that moment, including any corrections or late arrivals that had not yet been processed.

With the current architecture (dbt models materialised as tables that are fully refreshed on each run), this is not possible.

Discuss the following:

1. What **architectural pattern** would you introduce to satisfy this requirement? (e.g. slowly changing dimensions, snapshot tables, event sourcing, bi-temporal modelling)
2. How would this change the **CDW layer design** — which models would need to evolve, and how?
3. What are the **trade-offs** of your chosen approach in terms of storage, query complexity, and maintenance overhead?

> This is a design discussion. Describe the approach and reasoning; no implementation is expected.


---

## Task 4 — IDW Debugging (Diagnosis · Easy)

The IDW team is encountering an issue in their workflow. When they attempt to build their **end-user data components**, the process does not produce the expected outputs.

They have asked the CDW team for help diagnosing the problem.

**Your tasks:**

1. Inspect the IDW domain in this repository and identify **what is going wrong** in their workflow.
2. Describe the root cause clearly and explain what **concrete change** the IDW team needs to make to fix it.
3. Explain the **downstream impact** of this issue on CDW — how has CDW been affected by it, and what would need to change in CDW once IDW delivers the fix?

> Hints: look at `dbt_project.yml`, the `models/idw/` folder structure, and the CDW `sources.yml`. Pay attention to any dbt warnings emitted during `dbt compile` or `dbt run`.

---

## Bonus Task — dbt Documentation & Data Lineage (dbt · Easy)

**Generate and serve the dbt docs for this project, then explore the lineage graph.**

```bash
dbt docs generate --profiles-dir profile --project-dir .
dbt docs serve   --profiles-dir profile --project-dir . --port 8080
```

Open `http://localhost:8080` in your browser and navigate to the **Lineage Graph**.

During the interview, be prepared to discuss the following:

1. **Walk us through the lineage.** Starting from the seed tables, trace the data flow to a reporting view of your choice. What does the graph tell you about data ownership and layer boundaries?
2. **Data mesh visibility.** How does the lineage reflect the IDW → CDW domain boundary? Where exactly does CDW take a dependency on IDW data products, and how would you detect if that contract breaks?
3. **Documentation as a data product.** In a production Data Mesh environment, who should own and maintain the dbt docs? How can auto-generated documentation (column descriptions, test results, source freshness) reduce onboarding time and improve trust in data products?
4. **Operational value.** Give a concrete example of an incident or data quality issue where the lineage graph would have helped you diagnose the root cause faster than reading the SQL directly.

> There is no single correct answer. We want to see that you can reason about documentation as a first-class engineering concern, not an afterthought.

---

## Evaluation Criteria

| Criterion                                                                                                         | Weight |
|-------------------------------------------------------------------------------------------------------------------|--------|
| **Correctness** — models produce the right output, tests pass                                                     | 35 %   |
| **SQL quality** — readable, well-structured, appropriate use of CTEs                                              | 20 %   |
| **dbt best practices** — `ref()`, `source()`, schema.yml documentation, test coverage                             | 20 %   |
| **Architecture and DBT framework understanding** — correct layer placement, data mesh awareness, design reasoning | 25 %   |

---

## Tips

- Read the comment header of each existing model before writing SQL — it documents the input/output grain.
- Use `python explore.py` to inspect any table interactively.
- Use `dbt docs generate` and `dbt docs serve` to explore the lineage and documentation.
- DuckDB SQL reference: <https://duckdb.org/docs/sql/introduction>
- dbt documentation: <https://docs.getdbt.com>
