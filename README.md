# From Excel-Based Analysis to a Reproducible SQL Analytics Model

This repository presents a case study focused on designing an analytics-ready SQL data model starting from spreadsheet-based operational data.

---

## Context & Problem

In a company, critical production data, including process parameters, operational measurements, and quality control results, was manually captured using Excel files/Google Sheets.

Each production process generated its own spreadsheets, which were later used for different types of analysis:

- Daily production monitoring
- Process variable tracking
- Statistical Process Control (SPC)
- Traceability analysis
- Ad-hoc exploratory analysis

Over time, this approach became increasingly fragile and inefficient.

**The main issues were:**

- Approximately **10 different spreadsheet workbooks**, with more than 20 active sheets capturing data
- Data entered without strict validation, leading to inconsistencies and duplication
- Analyses requiring manual merging of multiple files, sheets, and formulas
- Growing data volumes causing performance issues and file corruption
- Historical analysis becoming slow, error-prone, and unreliable

At this stage, the problem was no longer purely technical.
**The existing workflow was neither scalable nor reproducible.**

## Project Goal

The goal of this project was to design and implement a centralized PostgreSQL database, using SQL as the core transformation layer, in order to:

- Centralize production data into a single source of truth
- Define clear and consistent data structures from ingestion
- Support periodic data loads with minimal friction
- Enable analytical consumption without reliance on spreadsheets
- Make analyses reproducible, extensible, and automatable

The objective was not simply to “store data”, but to build a robust analytical foundation for current and future use cases.

## Key Challenges

### 1. Data inconsistency

Historical data originated from spreadsheets with minimal validation, resulting in duplicated records, mixed formats, and undocumented implicit rules.

### 2. Data model design

The primary challenge was conceptual rather than technical:
designing a structure that was:

- simple enough for daily use
- flexible enough to support multiple analytical perspectives
- stable enough to grow over time

### 3. Workflow transition

Moving from manual Excel-based analysis to a database-driven model required a shift in how data was consumed and reasoned about.

## Approach & Solution

### Database as a Single Source of Truth

A PostgreSQL database was designed to act as the system’s single source of truth, where:

- Data is ingested under explicit structural and logical constraints
- Data stages are clearly separated (raw, clean, semantic)
- Consistency, traceability, and reusability are prioritized

This approach eliminated the need for downstream data corrections in spreadsheets.

## Data Modeling Decisions

- **Separation of core entities**  
  From the beginning, key entities such as heats and machines were modeled as standalone entities. This made it possible to consistently attach all related process data to a single heat, avoiding fragmented or duplicated representations across different datasets.

- **Layered data model (raw, clean, semantic)**  
  The data model was structured into clear layers. The *raw* layer preserves the original structure of spreadsheet data, which was designed for ease of manual input by operators. The *clean* layer standardizes and reshapes this data to make it integrable and reliable within the database. The *semantic* layer exposes analytical views and tables optimized for consumption, significantly simplifying downstream analysis.

- **Early validation and error prevention**  
  Data validation was enforced during the transition from *raw* to *clean*. Duplicates, invalid formats, and constraint violations are detected at this stage, ensuring that inconsistent or mixed data cannot propagate into analytical layers.

- **Core vs process separation**  
  Entities that are stable and always present (such as machines and production areas) were modeled in the core layer, while process-specific data was isolated in process domains. This separation allows process data to evolve over time adding, modifying, or deprecating parameters without destabilizing the core model.

- **SQL-first transformation strategy**  
  All transformations that could reasonably be expressed in SQL were implemented at the database level. This centralizes business logic, ensures consistency across analyses, and minimizes the need for repetitive transformations in notebooks.

- **Selective use of pandas for complex reshaping**  
  Python and pandas were reserved for cases where transformations (such as complex pivots or unpivots) were cumbersome or inefficient to express in SQL. This balance keeps the database responsible for structure and rules, while allowing flexibility at the analysis layer.

- **Pragmatic scope control**  
  The model intentionally includes only data required for current analytical use cases, leaving out low-value or rarely used fields. This keeps the model focused, easier to maintain, and ready to evolve as new analytical needs arise.


## Data Ingestion Strategy

Data ingestion was handled using Python and pandas to read spreadsheets files, standardize formats, and export staging-ready CSV files.

**The ingestion flow followed these steps:**

1. Read Excel/Sheets using Python (pandas)
2. Standardize formats (dates, times, column names, data types)
3. Export staging-ready CSV files
4. Load CSVs into PostgreSQL as staging/raw tables
5. Apply SQL-based transformations and validations into clean, core, and semantic layers

This design decoupled data extraction from transformation logic, keeping the database as the authoritative layer for business rules and validations.

## SQL as the Core Transformation Layer

**All core transformations were implemented in SQL, allowing:**

- Standardized business logic
- Reusable transformation patterns
- Reduced downstream data wrangling

By enforcing transformations at the database level, analytical outputs became consistent and reproducible.

## Python for Analytical Consumption

**Once analytical tables and views were available, Python and pandas were used to:**

- Consume curated datasets
- Build reproducible analysis notebooks
- Apply domain-specific transformations on demand

**A typical analytical use case involved generating consolidated, heat level datasets combining:**

- chemical composition results
- rolling temperatures
- lab tests results

These datasets enabled more advanced exploratory and statistical analyses in later phases.

## Results & Impact

**The implementation delivered clear and measurable benefits:**

- Significant efficiency gains by removing dependency on multiple spreadsheet versions
- Higher data reliability through enforced constraints at ingestion
- Elimination of performance bottlenecks caused by large Excel files
- Automated analysis workflows using Python notebooks
- Ability to run daily or historical analyses on demand, without manual reprocessing

The validation point was clear:
when data could be ingested without errors and consumed at any time, the system was operating as intended.

## Value for the Analyst

**From an analytical perspective, the model provides:**

- Fluency: less time preparing data, more time analyzing
- Certainty: a single, trusted version of the data
- Reproducibility: analyses can be repeated and extended without rebuilding pipelines

The analyst transitions from maintaining spreadsheets to working with a stable analytical system.

## Lessons Learned

**The primary lesson from this project is straightforward:**

```
When a consistent and reproducible data structure is defined upfront,
all downstream analysis becomes significantly simpler.
```

**Analytical quality depends directly on:**

- data consistency
- clarity of the data model
- discipline at ingestion

Investing time in data modeling dramatically reduces future complexity.

## Closing

This project represents a transition from spreadsheet-dependent analysis to a reproducible and scalable SQL-based analytics model.

More than a technical migration, it reflects a shift in mindset:  
**treating data as a system rather than a collection of isolated files.**

```mermaid
flowchart LR
  A[Excel / Google Sheets] --> B[Python pandas\\nExtract and standardize]
  B --> C[CSV exports\\nstaging-ready]
  C --> D[(PostgreSQL)]
  D --> E[Semantic layer\\nViews for analysis]
  E --> F[Python notebooks\\nEDA and reporting]
```