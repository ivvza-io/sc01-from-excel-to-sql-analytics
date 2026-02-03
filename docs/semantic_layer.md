# Semantic Layer (Views)

This document describes the core semantic views exposed by the PostgreSQL model.  
These views provide analytics-ready datasets with consistent definitions and a clearly defined **grain**, enabling reproducible analysis (EDA, SPC, and traceability) with minimal downstream wrangling.

---

## Design Principles

- **Analytics-first:** views are shaped for common analytical questions, not for data entry.
- **Stable grain:** each view explicitly documents what “one row” represents to avoid accidental duplication.
- **Consistent keys:** `heat_num` is the primary join key across views.
- **Composable:** views are designed to be joined together to build subject-specific analytical datasets (chemistry, lab results, product characterization).

---

## Scope and Purpose

These views are the **analytical interfaces** designed by SC01 to replace spreadsheet-based consumption patterns.

Each view has an explicit grain contract to prevent confusion about 
what "one row" represents.

For context on why this semantic layer was designed, see the SC01 README: 
[From Fragmented Data to Trustworthy Analytics](README.md).

---

## View Catalog

### 1) Heats by Alloy

**Purpose**  
Provide the alloy associated with each heat for filtering, grouping, and segmentation.

**Grain**  
- 1 row per heat

**Primary key / join key**  
- `heat_num`

**Core columns (typical)**  
- `heat_num`  
- `alloy_code`

**Inputs (sources)**  
- heats / casting entities  
- alloy reference tables

**Typical questions it answers**
- How many heats were produced per alloy over time?
- Which heats belong to a given alloy for downstream analysis (chemistry, lab, SPC)?

**Example query**
```sql
select
  alloy_code,
  count(*) as heats_count
from v_heats_by_alloy
group by alloy_code
order by heats_count desc;
```

---

### 3) Lab Values by Heat

**Purpose**  
Expose laboratory results at the heat level by joining lab test sessions and measured values into a single analytics-ready view.  
This view supports mechanical property monitoring, SPC, and customer/product segmentation.

**Grain**  
- 1 row per (`heat_num`, `lab_session_id`, `lab_test`)  
  Each heat typically has one lab session, with an optional reanalysis session.

**Primary key / join keys**  
- `heat_num`  
- `lab_session_id`  
- `lab_test`

**Core columns (typical)**  
- `heat_num`  
- `lab_session_id`  
- `session_type` (`analysis`, `reanalysis`)  
- `test_type` (e.g., tensile, hardness)  
- `test_date` (if available)  
- `lab_test` (e.g., UTS, YS, Elongation)  
- `test_value` (numeric)  
- `test_session_status` (`pass`, `fail`, `deviated`)

**Inputs (sources)**  
- lab sessions table  
- lab test values table  
- foreign key resolution to `heat_num`

**Typical questions it answers**
- What are mechanical property distributions by alloy / temper / product form?
- Which heats fail acceptance criteria?
- How stable are mechanical properties over time (SPC)?
- How do analysis vs reanalysis results compare?

**Example queries**
```sql
-- Main analysis session for SPC
select
  vha.alloy_code,
  vlv.heat_num,
  vlv.lab_test,
  vlv.test_value
from v_lab_values_by_heats vlv
join v_heats_by_alloy vha
  on vha.heat_num = vlv.heat_num
where vlv.test_type = 'tensile'
  and vlv.lab_test = 'UTS'
  and vlv.session_type = 'analysis'
order by vlv.heat_num;

-- Compare analysis vs reanalysis
select
  heat_num,
  lab_test,
  max(test_value) filter (where session_type = 'analysis')   as analysis_test_value,
  max(test_value) filter (where session_type = 'reanalysis') as reanalysis_test_value
from v_lab_values_by_heats
where heat_num = 123456
group by heat_num, lab_test
order by lab_test;
```

---

### 3) Heats by Final Product

**Purpose**  
Provide final product characterization at the heat level: base temper, strain level, and product form (e.g., coil, sheet, disc).

**Grain**  
- 1 row per heat

**Primary key / join key**  
- `heat_num`

**Core columns (typical)**  
- `heat_num`  
- `base_temper`  
- `strain_level`  
- `product_form`  
- `thickness`  
- `width`

**Inputs (sources)**  
- temper reference tables  
- product form reference tables

**Typical questions it answers**
- How do lab results distribute by product form?
- Does chemistry drift by temper or strain level?
- How do lab tests behave for specific product segments (SPC)?

**Example query**
```sql
select
  product_form,
  base_temper,
  strain_level,
  count(*) as heats_count
from v_heats_by_final_product
group by product_form, base_temper, strain_level
order by heats_count desc;
```

**Business segmentation**  
This view is a key segmentation layer for reporting and SPC. When joined with customer mapping, it enables customer- and product-specific monitoring (e.g., O-temper discs for Customer X).

---

## How These Views Are Used

A typical analytical workflow assembles analysis-ready datasets by joining views:

- Chemistry + Alloy → composition monitoring and SPC  
- Lab + Final Product → mechanical property tracking  
- Chemistry + Lab + Final Product → correlation and root-cause analysis  

**Example dataset build**
```sql
select
  vha.alloy_code,
  vhfp.base_temper,
  vhfp.strain_level,
  vhfp.product_form,
  vlv.lab_test,
  vlv.test_value  as lab_test_value,
  vch.element_symbol,
  vch.element_value as chem_element_value
from v_heats_by_alloy vha
join v_heats_by_final_product vhfp
  on vha.heat_num = vhfp.heat_num
join v_lab_values_by_heats vlv
  on vlv.heat_num = vha.heat_num
join v_chem_by_heats vch
  on vch.heat_num = vha.heat_num;
```

---

## Customer & Product Segmentation Examples

By joining **Heats by Final Product** with **Heats by Customer**, it becomes straightforward to analyze how chemistry and mechanical properties behave by customer and product segment, and to compare delivery consistency across customers.

```sql
-- Mechanical behavior for Customer X, O-temper discs
select
  hc.customer,
  vhfp.product_form,
  vhfp.base_temper,
  vlv.lab_test,
  avg(vlv.test_value) as avg_test_value,
  count(*) as n
from v_lab_values_by_heats vlv
join v_heats_by_final_product vhfp
  on vhfp.heat_num = vlv.heat_num
join v_heats_by_customer hc
  on hc.heat_num = vlv.heat_num
where hc.customer = 'Customer X'
  and vhfp.product_form = 'disc'
  and vhfp.base_temper = 'O'
  and vhfp.thickness between 0.80 and 1.20
group by hc.customer, vhfp.product_form, vhfp.base_temper, vlv.lab_test
order by vlv.lab_test;
```
