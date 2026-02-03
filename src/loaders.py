"""
io/loaders.py

Functions for loading semantic views from PostgreSQL or CSV.
"""

import os
from pathlib import Path
from typing import Dict, Tuple, Optional, Any
import pandas as pd
from sqlalchemy import create_engine, text
from dotenv import load_dotenv


def resolve_repo_root(current_dir: Optional[Path] = None, notebooks_dir_name: str = 'notebooks') -> Path:
    '''
    Resolve repository root based on current working directory.

    If running from notebooks/, returns parent. Otherwise returns cwd.
    '''
    cwd = current_dir or Path.cwd()
    return cwd.parent if cwd.name == notebooks_dir_name else cwd

def load_database_url(repo_root: Path, env_filename: str = '.env') -> Optional[str]:
    '''
    Load DATABASE_URL from an optional .env file.

    Returns None if .env missing or DATABASE_URL unset.
    '''
    load_dotenv(repo_root / env_filename)
    value = os.getenv('DATABASE_URL')
    if value:
        value = value.strip()
    return value or None

def try_connect_postgresql(database_url: str):
    '''
    Attempt to connect to PostgreSQL using SQLAlchemy.

    Returns (engine, conn). Raises on failure.
    '''
    engine = create_engine(database_url, echo=False)
    conn = engine.connect()
    return engine, conn

def load_semantic_views_postgresql(conn) -> Dict[str, Any]:
    '''
    Load SC01 semantic views from PostgreSQL connection.

    Expects sem.* views to exist.
    '''
    

    df_heats_alloy = pd.read_sql(text('SELECT * FROM sem.v_heats_by_alloy_code'), conn)
    df_final_prod = pd.read_sql(text('SELECT * FROM sem.v_final_product_data_by_heat'), conn)
    df_lab = pd.read_sql(
        text('SELECT * FROM sem.v_mechanics_lab_values_by_heat WHERE value_status = \'valid\''), conn
    )
    df_sql = pd.read_sql('SELECT * FROM sem.v_analysis_dataset', conn)

    return {
        'data_source': 'postgresql',
        'df_heats_alloy': df_heats_alloy,
        'df_final_prod': df_final_prod,
        'df_lab': df_lab,
        'df_sql': df_sql
    }

def load_semantic_views_csv(repo_root: Path, subdir: str = 'data/public') -> Dict[str, Any]:
    '''
    Load SC01 semantic views from versioned CSV files under data/public/.
    '''
    data_dir = repo_root / subdir

    if not data_dir.exists():
        raise FileNotFoundError(
            f'Cannot find {subdir} directory at {data_dir}\n'
            f'Please run notebook from repository root or notebooks/ directory.'
        )

    df_heats_alloy = pd.read_csv(data_dir / 'v_heats_by_alloy_code.csv')
    df_final_prod = pd.read_csv(data_dir / 'v_final_product_data_by_heat.csv')
    df_lab = pd.read_csv(data_dir / 'v_mechanics_lab_values_by_heat.csv')
    df_sql = pd.read_csv(data_dir / 'v_analysis_dataset.csv')

    return {
        'data_source': 'csv',
        'df_heats_alloy': df_heats_alloy,
        'df_final_prod': df_final_prod,
        'df_lab': df_lab,
    }

def load_semantic_views(
    data_source: str = 'csv',
    database_url: Optional[str] = None,
    repo_root: Optional[Path] = None
) -> Dict[str, Any]:
    '''
    Load semantic views from PostgreSQL or CSV.

    Parameters
    ----------
    data_source : str
        'postgresql' or 'csv'
    database_url : str, optional
        PostgreSQL connection string (required if data_source='postgresql')
    repo_root : Path, optional
        Repository root path (required if data_source='csv')

    Returns
    -------
    dict
        Contains:
        - df_heats_alloy
        - df_final_prod
        - df_lab
        - conn (None for CSV)

    Raises
    ------
    ValueError
        If configuration is invalid
    '''
    data_source = data_source.lower()

    if data_source == 'postgresql':
        if not database_url:
            raise ValueError('database_url must be provided when data_source="postgresql"')

        engine, conn = try_connect_postgresql(database_url)
        try:
            return load_semantic_views_postgresql(conn)
        finally:
            conn.close()
            engine.dispose()
    if data_source == 'csv':
        if repo_root is None:
            raise ValueError('repo_root must be provided when data_source="csv"')
        return load_semantic_views_csv(repo_root)

    raise ValueError(f'Invalid data_source: {data_source}. Must be "postgresql" or "csv"')

