#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# CDW Data Engineering Interview — Environment Setup
# ──────────────────────────────────────────────────────────────────────────────
# Creates a Python virtual environment, installs dbt-duckdb, generates seed
# data, and runs the full dbt pipeline so the candidate can start immediately.
#
# Usage:
#   bash setup.sh           # full setup
#   bash setup.sh --reset   # wipe DuckDB file and re-run everything
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RESET=false
[[ "${1:-}" == "--reset" ]] && RESET=true

# ── Colour helpers ────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
step()  { echo -e "\n${BLUE}▶ $*${NC}"; }
ok()    { echo -e "${GREEN}✓ $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $*${NC}"; }

echo -e "\n${GREEN}══════════════════════════════════════════════════════"
echo -e "  CDW Data Engineering Interview — Environment Setup"
echo -e "══════════════════════════════════════════════════════${NC}"

# ── 0. Prerequisites ──────────────────────────────────────────────────────────
step "Checking prerequisites"
# Resolve python interpreter: prefer python3, fall back to python
if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
    PYTHON=python3
elif command -v python >/dev/null 2>&1 && python -c "import sys" >/dev/null 2>&1; then
    PYTHON=python
else
    echo "ERROR: no working python3/python interpreter found"; exit 1
fi
PYTHON_VERSION=$($PYTHON -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
ok "Python $PYTHON_VERSION found ($PYTHON)"

# ── 1. Virtual environment ────────────────────────────────────────────────────
step "Creating Python virtual environment (.venv/)"
if [[ -d ".venv" && "$RESET" == "false" ]]; then
    warn ".venv/ already exists — skipping creation (use --reset to force)"
else
    $PYTHON -m venv .venv
    ok "Virtual environment created"
fi

# Activate — works on both Unix and Windows Git Bash
if [[ -f ".venv/Scripts/activate" ]]; then
    # shellcheck disable=SC1091
    source .venv/Scripts/activate
else
    # shellcheck disable=SC1091
    source .venv/bin/activate
fi
ok "Virtual environment activated"

# ── 2. Python dependencies ────────────────────────────────────────────────────
step "Installing Python dependencies (dbt-duckdb)"
python -m pip install --quiet --upgrade pip
python -m pip install --quiet -r requirements.txt
ok "Dependencies installed"

# ── 3. Reset DuckDB (optional) ────────────────────────────────────────────────
if [[ "$RESET" == "true" && -f "interview.duckdb" ]]; then
    step "Resetting DuckDB database"
    rm -f interview.duckdb
    ok "interview.duckdb removed"
fi

# ── 4. [SKIPPED] Generate seed data ─────────────────────────────────────────────────────

# ── 5. dbt deps ───────────────────────────────────────────────────────────────
step "Installing dbt packages (dbt deps)"
python -m dbt.cli.main deps --profiles-dir "$SCRIPT_DIR/profile" --project-dir "$SCRIPT_DIR" --quiet
ok "dbt packages installed"

# ── 6. dbt seed ───────────────────────────────────────────────────────────────
step "Loading seed data into DuckDB (dbt seed)"
python -m dbt.cli.main seed --profiles-dir "$SCRIPT_DIR/profile" --project-dir "$SCRIPT_DIR" --quiet
ok "Seeds loaded"

# ── 7. dbt run ────────────────────────────────────────────────────────────────
step "Building dbt models (dbt run)"
DBT_OPTS="--profiles-dir $SCRIPT_DIR/profile --project-dir $SCRIPT_DIR"
# Run in two passes: IDW first (CDW depends on idw_end_user views)
python -m dbt.cli.main run $DBT_OPTS --select "idw.landing idw.staging" --quiet
python -m dbt.cli.main run $DBT_OPTS --select "cdw.landing cdw.staging.lv01_build" --quiet
# S2 and above may fail until candidates implement the TODO models — that is expected
if python -m dbt.cli.main run $DBT_OPTS --select "cdw.staging.lv02_modelling+" --quiet 2>/dev/null; then
    ok "All models built successfully"
else
    warn "S2 models returned empty placeholders (expected until Tasks 1 & 2 are implemented)"
    warn "IDW + CDW landing + S1 layers are fully functional"
fi

# ── 8. dbt test ───────────────────────────────────────────────────────────────
step "Running dbt tests"
if python -m dbt.cli.main test $DBT_OPTS --select "idw" --quiet 2>/dev/null; then
    ok "IDW tests passed"
else
    warn "Some IDW tests failed — check dbt test output for details"
fi

# ── 9. Verify the database ────────────────────────────────────────────────────
step "Verifying database schemas"
$PYTHON - <<'EOF'
import duckdb, sys
con = duckdb.connect("interview.duckdb")
schemas = [r[0] for r in con.execute("SELECT schema_name FROM information_schema.schemata WHERE schema_name <> 'end_user' ORDER BY 1").fetchall()]
expected = ["idw_landing", "idw_staging", "cdw_landing", "cdw_staging"]
missing = [s for s in expected if s not in schemas]
if missing:
    print(f"  WARNING: missing schemas: {missing}", file=sys.stderr)
else:
    print(f"  Schemas present: {', '.join(schemas)}")
# Row counts
counts = {}
for schema in ["idw_landing", "idw_staging", "cdw_landing", "cdw_staging"]:
    if schema in schemas:
        tables = con.execute(f"SELECT table_name FROM information_schema.tables WHERE table_schema = '{schema}' ORDER BY 1").fetchall()
        for (t,) in tables:
            n = con.execute(f"SELECT count(*) FROM {schema}.{t}").fetchone()[0]
            counts[f"{schema}.{t}"] = n
for k, v in sorted(counts.items()):
    print(f"  {k}: {v:,} rows")
con.close()
EOF

# ── Done ──────────────────────────────────────────────────────────────────────
echo -e "\n${GREEN}══════════════════════════════════════════════════════"
echo -e "  Setup complete!"
echo -e "══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Next steps:"
echo -e "    1. Activate the environment:"
echo -e "       ${YELLOW}source .venv/bin/activate${NC}   (Linux / Mac / Git Bash)"
echo -e "       ${YELLOW}.venv\\Scripts\\activate${NC}      (Windows CMD / PowerShell)"
echo ""
echo -e "    2. Read ${YELLOW}TASKS.md${NC} for your assignment"
echo ""
echo -e "    3. After editing a model, validate with:"
echo -e "       ${YELLOW}dbt run --profiles-dir . --project-dir . -s <model_name>${NC}"
echo -e "       ${YELLOW}dbt test --profiles-dir . --project-dir .${NC}"
echo ""
echo -e "    4. Explore the data interactively:"
echo -e "       ${YELLOW}python explore.py${NC}"
echo ""