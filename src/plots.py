"""
plots/semantic_plots.py

Functions for creating sc01 visualizations.
"""
from __future__ import annotations
from typing import Optional, Tuple
import pandas as pd
import matplotlib.pyplot as plt

def plot_uts_histogram(
    df: pd.DataFrame,
    metric_col: str = 'uts_value',
    segment_name: Optional[str] = None,
    alloy: Optional[str] = None,
    bins: int = 30,
    figsize: Tuple[int, int] = (10, 5)
):
    '''
    Plot histogram of UTS distribution.
    
    Parameters
    ----------
    df : pd.DataFrame
        Must have metric_col
    metric_col : str
        Column with values to plot
    segment_name : str, optional
        Name for title
    alloy : str, optional
        Filter to specific alloy
    bins : int
        Number of bins
    figsize : tuple
        Figure size (width, height)
    
    Returns
    -------
    fig, ax : matplotlib objects
    
    Examples
    --------
    >>> fig, ax = plot_uts_histogram(segment, alloy='3105')
    '''
    
    data = df.copy()
    
    if alloy is not None:
        data = data[data['alloy_code'] == alloy]
    
    data = data.dropna(subset=[metric_col])
    
    fig, ax = plt.subplots(figsize=figsize)
    
    ax.hist(data[metric_col], bins=bins, color='steelblue', edgecolor='black', alpha=0.7)
    
    # Title
    if alloy:
        title = f'UTS distribution -- Alloy {alloy}'
        if segment_name:
            title += f' ({segment_name})'
    else:
        title = 'UTS distribution'
        if segment_name:
            title = f'{segment_name} -- UTS distribution'
    
    ax.set_title(title, fontsize=12)
    ax.set_xlabel(f'{metric_col} (MPa)')
    ax.set_ylabel('Count')
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.show()
    
    print(f'\nHistogram: {len(data)} samples')
    print(f'  Mean: {data[metric_col].mean():.1f} MPa')
    print(f'  Std: {data[metric_col].std():.1f} MPa')
    print(f'  Range: {data[metric_col].min():.1f} - {data[metric_col].max():.1f} MPa')
    
    return fig, ax

def plot_uts_boxplot(
    df: pd.DataFrame,
    group_col: str = 'alloy_code',
    metric_col: str = 'uts_value',
    segment_name: Optional[str] = None,
    figsize: Tuple[int, int] = (10, 5)
):
    '''
    Plot boxplot of UTS by group (alloy, temper, etc).
    
    Parameters
    ----------
    df : pd.DataFrame
        Analysis dataset
    group_col : str
        Column to group by (e.g., 'alloy_code')
    metric_col : str
        Metric column to plot
    segment_name : str, optional
        Name for title
    figsize : tuple
        Figure size
    
    Returns
    -------
    fig, ax : matplotlib objects
    
    Examples
    --------
    >>> fig, ax = plot_uts_boxplot(segment, group_col='alloy_code')
    '''
    
    data = df[[group_col, metric_col]].copy()
    data = data.dropna(subset=[metric_col])
    
    # Determine order by median
    order = (
        data.groupby(group_col)[metric_col]
        .median()
        .sort_values(ascending=False)
        .index
        .tolist()
    )
    
    fig, ax = plt.subplots(figsize=figsize)
    
    # Prepare data for boxplot
    plot_data = [data[data[group_col] == g][metric_col].values for g in order]
    
    bp = ax.boxplot(
        plot_data,
        labels=order,
        showfliers=False,
        patch_artist=True,
        boxprops=dict(facecolor='lightblue', alpha=0.7)
    )
    
    # Title
    title = f'{metric_col} distribution by {group_col}'
    if segment_name:
        title = f'{segment_name} -- {title}'
    
    ax.set_title(title, fontsize=12)
    ax.set_xlabel(group_col)
    ax.set_ylabel(f'{metric_col} (MPa)')
    ax.grid(True, alpha=0.3, axis='y')
    
    plt.tight_layout()
    plt.show()
    
    print(f'\nBoxplot by {group_col}: {len(order)} groups')
    
    return fig, ax