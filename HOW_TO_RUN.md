# SC01: How to Run

This document explains how to execute the SC01 semantic layer consumption notebook with either CSV files or a live PostgreSQL database.

---

## Overview

The notebook `sc01_sql_semantic_layer_consumption.ipynb` demonstrates two approaches to building analysis-ready datasets:
- **Approach 1 (Pandas):** Explicit transformations visible in code
- **Approach 2 (SQL):** Pre-built semantic layer views

Both modes support:
| Mode | Setup | Best For |
|------|-------|----------|
| **CSV** | None | Quick demo, offline exploration |
| **PostgreSQL** | Docker or local DB | Production data, SQL validation |

> If you only want to understand the idea, run **CSV mode**.
>
> If you want to validate the engineering rigor, use **PostgreSQL**.

---

## Quick Start (CSV Mode - No Setup)

```bash
# 1. Navigate to repository root
cd sc01-from-excel-to-sql-analytics

# 2. Create virtual environment
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Start Jupyter
jupyter notebook

# 5. Open notebook
#    notebooks/sc01_sql_semantic_layer_consumption.ipynb
#    Then: Kernel → Restart & Run All
```

### Expected Output (CSV Mode)
```
DATA SOURCE: CSV

✓ Loaded from CSV files:
  - v_heats_by_alloy: 1200 rows
  - v_final_product: 1200 rows
  - v_lab_values: 6600 rows

✓ Grain validation passed
✓ Pandas and SQL produce IDENTICAL results
✓ Dataset ready for analysis
```

**Execution time:** ~30 seconds

---

## Full Setup (PostgreSQL Mode)

### Prerequisites

- Python 3.9+
- Docker (recommended) OR PostgreSQL 14+ installed locally
- Port 5433 available (or modify docker-compose.yml)

### Step 1: Create Virtual Environment

```bash
cd sc01-from-excel-to-sql-analytics

python -m venv .venv
source .venv/bin/activate  # Mac/Linux
# OR
.venv\Scripts\activate      # Windows

pip install -r requirements.txt
```

### Step 2: Setup Database

#### Option A: Docker (Recommended)

```bash
# 1. Start PostgreSQL container
docker-compose up -d

# 2. Wait for initialization
sleep 20

# 3. Verify container is running
docker ps
# Should show: sc01-db with status "Up"

# 4. Test connection
psql -U sc01_user -d sc01 -h localhost -p 5433 \
  -c "SELECT COUNT(*) FROM sem.v_heats_by_alloy_code"
# Expected: Row count (e.g., 1200)
```

#### Option B: Manual PostgreSQL Setup

```bash
# 1. Create database
psql -U postgres -c "CREATE DATABASE sc01;"

# 2. Create schemas and tables
psql -U postgres -d sc01 -f sql/00_create_schemas.sql
psql -U postgres -d sc01 -f sql/01_tables.sql

# 3. Create semantic views
psql -U postgres -d sc01 -f sql/03_semantic_views.sql

# 4. Load data from CSVs
psql -U postgres -d sc01 -f sql/02_load.sql

# 5. Verify
psql -U postgres -d sc01 \
  -c "SELECT COUNT(*) FROM sem.v_heats_by_alloy_code"
```

### Step 3: Configure Environment

Create `.env` file:

```bash
cp .env.example .env
```

Content of `.env`:
```
DATABASE_URL=postgresql://sc01_user:sc01_password@localhost:5433/sc01
```

### Step 4: Run Notebook

```bash
# Load environment variables
source .env

# Start Jupyter
jupyter notebook

# Open: notebooks/sc01_sql_semantic_layer_consumption.ipynb
# Run: Kernel → Restart & Run All
```

### Expected Output (PostgreSQL Mode)
```
DATA SOURCE: POSTGRESQL

✓ Connected to PostgreSQL

✓ Loaded from PostgreSQL:
  - v_heats_by_alloy: 1200 rows
  - v_final_product: 1200 rows
  - v_lab_values: 6600 rows

✓ Grain validation passed
✓ Pandas and SQL produce IDENTICAL results
✓ Dataset ready for analysis
```

**Execution time:** ~30 seconds

---

## Switching Between Modes

Switching between CSV and PostgreSQL modes is done directly in **Section 1** of the notebook:

### CSV Mode

```python
DATA_SOURCE = 'csv'
loaded = load_semantic_views(
    data_source=DATA_SOURCE,
    repo_root=repo_root,
    database_url=database_url
)
```

### PostgreSQL Mode

```python
repo_root = resolve_repo_root()
database_url = load_database_url(repo_root)
DATA_SOURCE = 'postgresql'
loaded = load_semantic_views(
    data_source=DATA_SOURCE,
    repo_root=repo_root,
    database_url=database_url
)
```

**No need for environment variables** - just change `DATA_SOURCE = 'csv'` to `DATA_SOURCE = 'postgresql'` in the notebook cell and re-run Section 1.

---

## Troubleshooting

### CSV Mode

**"Cannot find data/public directory"**
```bash
# Verify files exist
ls -la data/public/v_*.csv

# Run from repo root
cd sc01-from-excel-to-sql-analytics
jupyter notebook
```

### PostgreSQL Mode

**"connection refused" on port 5433**
```bash
# Check if container is running
docker ps

# Start container
docker-compose up -d
sleep 20
```

**"role 'sc01_user' does not exist"**
```bash
# Reset database completely
docker-compose down -v
docker-compose up -d
sleep 20
```

**Docker container keeps restarting**
```bash
# Check logs
docker logs sc01-db

# Reset and try again
docker-compose down -v
docker-compose up -d
sleep 30  # Wait longer for init
```

---

## Port Configuration

**Default:** 5433 (Docker)

If port 5433 is already in use:

1. Edit `docker-compose.yml`:
```yaml
ports:
  - "5434:5432"  # Change 5433 to 5434
```

2. Update `.env`:
```
DATABASE_URL=postgresql://sc01_user:sc01_password@localhost:5434/sc01
```

---

## Requirements

### Python Packages

See `requirements.txt`:
```
pandas>=2.0.0
matplotlib>=3.7.0
sqlalchemy>=2.0.0
jupyter>=1.0.0
python-dotenv>=1.0.0
psycopg2-binary>=2.9.0  # PostgreSQL only
```

### SQL Scripts

Required for PostgreSQL setup:
```
sql/
├── 00_create_schemas.sql      # Create ref, core, lab, sem schemas
├── 01_tables.sql              # Create all tables
├── 02_load.sql                # Load data from CSVs
└── 03_semantic_views.sql      # Create semantic layer views
```

### Data Files

Required for CSV mode:
```
data/public/
├── v_heats_by_alloy_code.csv
├── v_heats_by_final_product_data_by_heat.csv
├── v_lab_values_by_heats.csv
└── v_analysis_dataset.csv
```

---

## Performance

| Operation | Time |
|-----------|------|
| Virtual env setup | ~30 sec |
| Pip install | ~2 min |
| Docker initialization (first time) | ~20 sec |
| Notebook execution (CSV) | ~30 sec |
| Notebook execution (PostgreSQL) | ~30 sec |

---

## Support

**Issues with this notebook?**

1. Check the Troubleshooting section above
2. Verify Section 0 shows correct DATA_SOURCE
3. Check docker logs: `docker logs sc01-db`
4. Verify data files exist: `ls data/public/`
5. Test connection: `psql -U sc01_user -d sc01 -h localhost -p 5433 -c "SELECT 1"`

---
