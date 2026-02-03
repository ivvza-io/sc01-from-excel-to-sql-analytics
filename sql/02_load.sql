-- 02_load.sql
-- Purpose: load human-friendly CSV seeds into the mini-db (adapted to updated 01_tables.sql)
-- Assumes CSVs are mounted inside the container at: data/seed/...

-- =========================
-- Safety / idempotency
-- =========================

truncate table lab.test_session_values restart identity cascade;
truncate table lab.test_sessions restart identity cascade;
truncate table lab.chem_analysis_values restart identity cascade;
truncate table lab.chem_analysis_sessions restart identity cascade;

truncate table core.heats restart identity cascade;
truncate table core.product_codes restart identity cascade;
truncate table ref.test_types restart identity cascade;
truncate table ref.elements restart identity cascade;

-- =========================
-- 1) Load ref catalogs (direct \COPY)
-- =========================

-- data/seed/ref/elements.csv columns:
-- symbol,name
\copy ref.elements(symbol, name) from '/seed/ref/elements.csv' with (format csv, header true);

-- data/seed/ref/test_types.csv columns:
-- code,description,unit
\copy ref.test_types(code, description, unit) from '/seed/ref/test_types.csv' with (format csv, header true);

-- =========================
-- 2) Load core.heats (direct \COPY)
-- =========================

-- data/seed/core/heats.csv columns:
-- heat_num,alloy_code,temper_code
\copy core.heats(heat_num, product_code, alloy_code, temper_code) from '/seed/core/heats.csv' with (format csv, header true);

-- =========================
-- 3) Load core.product_codes (direct \COPY)
-- =========================

-- data/seed/core/product_codes.csv columns:
-- product_code,base_temper,h_level,product_type,spec_thickness,customer_code
\copy core.product_codes(product_code,base_temper,h_level,product_type,spec_thickness,customer_code) from '/seed/core/product_codes.csv' with (format csv, header true);

-- =========================
-- 4) Chemistry: sessions + values (via staging)
-- =========================

begin;

-- data/seed/lab/chem_sessions.csv columns:
-- heat_id,analysis_date,analysis_type,analysis_status,analysis_lab_id,analysis_eq_id,analyst_id,notes
create temporary table stg_chem_sessions (
    heat_id         integer,
    analysis_date   date,
    analysis_type   text,
    analysis_status text,
    analysis_lab_id integer,
    analysis_eq_id  integer,
    analyst_id      integer,
    notes           text
) on commit drop;

\copy stg_chem_sessions from '/seed/lab/chem_sessions.csv' with (format csv, header true);

insert into lab.chem_analysis_sessions (
    heat_id,
    analysis_date,
    analysis_type,
    analysis_status,
    analysis_lab_id,
    analysis_eq_id,
    analyst_id,
    notes
)
select
    h.heat_id,
    s.analysis_date,
    s.analysis_type,
    s.analysis_status,
    s.analysis_lab_id,
    s.analysis_eq_id,
    s.analyst_id,
    s.notes
from stg_chem_sessions s
join core.heats h
    on h.heat_id = s.heat_id
on conflict (heat_id, analysis_type)
do update set
    analysis_date   = excluded.analysis_date,
    analysis_status = excluded.analysis_status,
    analysis_lab_id = excluded.analysis_lab_id,
    analysis_eq_id  = excluded.analysis_eq_id,
    analyst_id      = excluded.analyst_id,
    notes           = excluded.notes;

commit;

begin;

-- data/seed/lab/chem_values.csv columns:
-- chem_session_id,element_id,element_value
create temporary table stg_chem_values (
    chem_session_id integer,
    element_id      integer,
    element_value   real
) on commit drop;

\copy stg_chem_values from '/seed/lab/chem_values.csv' with (format csv, header true);

insert into lab.chem_analysis_values (
    chem_session_id,
    element_id,
    element_value
)
select
    cs.chem_session_id,
    e.element_id,
    v.element_value
from stg_chem_values v
join lab.chem_analysis_sessions cs
    on cs.chem_session_id = v.chem_session_id
join ref.elements e
    on e.element_id = v.element_id
on conflict (chem_session_id, element_id)
do update set
    element_value = excluded.element_value;

commit;

-- =========================
-- 5) Mechanical: sessions + values (via staging)
-- =========================

begin;

-- data/seed/lab/test_sessions.csv columns:
-- session_code,session_date,heat_id,lab_id,analyst_id,session_type,test_session_status,notes
create temporary table stg_test_sessions (
    session_code        text,
    session_date        date,
    heat_id             integer,
    lab_id              integer,
    analyst_id          integer,
    session_type        text,
    test_session_status text,
    notes               text
) on commit drop;

\copy stg_test_sessions from '/seed/lab/test_sessions.csv' with (format csv, header true);

insert into lab.test_sessions (
    session_code,
    session_date,
    heat_id,
    lab_id,
    analyst_id,
    session_type,
    test_session_status,
    notes
)
select
    s.session_code,
    s.session_date,
    h.heat_id,
    s.lab_id,
    s.analyst_id,
    s.session_type,
    s.test_session_status,
    s.notes
from stg_test_sessions s
join core.heats h
    on h.heat_id = s.heat_id
on conflict (session_code)
do update set
    session_date        = excluded.session_date,
    heat_id             = excluded.heat_id,
    lab_id              = excluded.lab_id,
    analyst_id          = excluded.analyst_id,
    session_type        = excluded.session_type,
    test_session_status = excluded.test_session_status,
    notes               = excluded.notes;

commit;

begin;

-- data/seed/lab/test_values.csv columns:
-- test_session_id,test_type_id,test_value,value_status,notes
create temporary table stg_test_values (
    test_session_id integer,
    test_type_id    integer,
    test_value      real,
    value_status    text,
    notes           text
) on commit drop;

\copy stg_test_values from '/seed/lab/test_values.csv' with (format csv, header true);

insert into lab.test_session_values (
    test_session_id,
    test_type_id,
    test_value,
    value_status,
    notes
)
select
    ts.test_session_id,
    tt.test_type_id,
    v.test_value,
    v.value_status,
    v.notes
from stg_test_values v
join lab.test_sessions ts
    on ts.test_session_id = v.test_session_id
join ref.test_types tt
    on tt.test_type_id = v.test_type_id
on conflict (test_session_id, test_type_id)
do update set
    test_value   = excluded.test_value,
    value_status = excluded.value_status,
    notes        = excluded.notes;

commit;
