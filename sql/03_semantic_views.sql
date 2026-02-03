-- 03_semantic_views.sql
-- Purpose: Create semantic layer views for analytics-ready consumption
-- Schemas: ref, core, lab, sem (created in 00_create_schemas.sql)
-- Tables: created in 01_tables.sql
-- Data: loaded in 02_load.sql
--
-- These three views (v_heats_by_alloy_code, v_final_product_data_by_heat, v_mechanics_lab_values_by_heat)
-- form the analytical interface that the notebook consumes.
-- Each view has an explicit grain contract.

-- ============================================================================
-- View 1: v_heats_by_alloy_code
-- ============================================================================
-- Grain: 1 row per heat
-- Purpose: Heat-level alloy assignment and identification
-- Used for: Alloy segmentation, filtering, grouping

create or replace view sem.v_heats_by_alloy_code as
select
    h.heat_id,
    h.heat_num,
    h.alloy_code,
    h.temper_code
from core.heats h
order by h.heat_id;

-- ============================================================================
-- View 2: v_final_product_data_by_heat
-- ============================================================================
-- Grain: 1 row per heat
-- Purpose: Product final state metadata (temper, form, etc.)
-- Note: In current schema, this is primarily alloy_code + temper_code from heats table
--       Extended in this view to match the analytical interface expected by notebook

create or replace view sem.v_final_product_data_by_heat as
select
    h.heat_id,
    h.heat_num,
    h.alloy_code,
    pc.base_temper,
    pc.h_level,
    pc.product_type,
    pc.spec_thickness
from core.heats h
join core.product_codes pc
on h.product_code = pc.product_code;


-- ============================================================================
-- View 3: v_mechanics_lab_values_by_heat
-- ============================================================================
-- Grain: 1 row per (heat_id, test_type_id, session_type)
-- Purpose: Mechanical test results (UTS, YS, elongation, etc.)
-- Multiple rows per heat (one per test result)
-- Filters: Only valid sessions and valid values

create or replace view sem.v_mechanics_lab_values_by_heat as
select
    h.heat_id,
    h.heat_num,
    ts.session_code,
    ts.session_date,
    ts.session_type,
    ts.test_session_status,
    tt.code as test_name,
    tt.description as test_description,
    tt.unit,
    tsv.test_value,
    tsv.value_status
from lab.test_session_values tsv
INNER JOIN lab.test_sessions ts 
    ON tsv.test_session_id = ts.test_session_id
INNER JOIN ref.test_types tt 
    ON tsv.test_type_id = tt.test_type_id
INNER JOIN core.heats h 
    ON ts.heat_id = h.heat_id
WHERE ts.test_session_status = 'valid'
  AND tsv.value_status = 'valid'
order by h.heat_id, ts.session_date, tt.code;

-- ============================================================================
-- View 4: v_analysis_dataset
-- ============================================================================
-- Grain: 1 row per heat
-- Purpose: Analysis-ready dataset with all features pivoted wide
-- Contains: heat metadata + product codes + lab test results (UTS, YS, elongation)
-- Filters: Only valid sessions and valid values
-- Note: This view demonstrates SQL-based dataset construction (compare with pandas approach)

create or replace view sem.v_analysis_dataset as
select
    h.heat_id,
    h.alloy_code,
    pc.product_type,
    pc.base_temper,
    pc.h_level,
    pc.spec_thickness,
    tsv_uts.test_value as uts_value,
    tsv_ys.test_value as ys_value,
    tsv_elong.test_value as elongation_value
from core.heats h
join core.product_codes pc on h.product_code = pc.product_code
left join (
    select ts.heat_id, tsv.test_value
    from lab.test_session_values tsv
    join lab.test_sessions ts on tsv.test_session_id = ts.test_session_id
    join ref.test_types tt on tsv.test_type_id = tt.test_type_id
    where tt.code = 'uts_mpa'
      and ts.test_session_status = 'valid'
      and tsv.value_status = 'valid'
) tsv_uts on h.heat_id = tsv_uts.heat_id
left join (
    select ts.heat_id, tsv.test_value
    from lab.test_session_values tsv
    join lab.test_sessions ts on tsv.test_session_id = ts.test_session_id
    join ref.test_types tt on tsv.test_type_id = tt.test_type_id
    where tt.code = 'ys_mpa'
      and ts.test_session_status = 'valid'
      and tsv.value_status = 'valid'
) tsv_ys on h.heat_id = tsv_ys.heat_id
left join (
    select ts.heat_id, tsv.test_value
    from lab.test_session_values tsv
    join lab.test_sessions ts on tsv.test_session_id = ts.test_session_id
    join ref.test_types tt on tsv.test_type_id = tt.test_type_id
    where tt.code = 'el_percent'
      and ts.test_session_status = 'valid'
      and tsv.value_status = 'valid'
) tsv_elong on h.heat_id = tsv_elong.heat_id
order by h.heat_id;
