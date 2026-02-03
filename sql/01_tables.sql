-- 01_tables.sql
-- Purpose: minimal, portfolio-ready schema (subset) for chem + mechanical tests
-- Note: this v0.1 intentionally excludes casting/hot-rolling process tables to keep the mini-DB lean.
-- Schemas expected: ref, core, lab, sem (created in 00_create_schemas.sql)

-- =========================
-- ref: catalogs
-- =========================

create table if not exists ref.elements (
    element_id      serial primary key,
    symbol          text not null unique,   
    name            text
);

create table if not exists ref.test_types (
    test_type_id    serial primary key,
    code            text not null unique,
    description     text,
    unit            text not null
);

-- =========================
-- core: grain = 1 row per heat
-- =========================

create table if not exists core.heats (
    heat_id     serial primary key,
    heat_num    text not null unique,

    product_code text not null,
    alloy_code  text not null,
    temper_code text not null
);

create index if not exists ix_heats_alloy_temper on core.heats(alloy_code, temper_code);

-- =========================
-- core:product codes
-- =========================

create table if not exists core.product_codes (
    product_code_id     serial primary key,
    product_code        text not null unique,

    base_temper         text not null,
    h_level             text not null,
    product_type        text not null,
    spec_thickness      real not null,
    customer_code       text not null
);

create index if not exists idx_product_codes_code ON core.product_codes(product_code);


-- =========================
-- lab: chemistry
-- =========================

create table if not exists lab.chem_analysis_sessions (
    chem_session_id     serial primary key,
    heat_id             integer not null,
    analysis_date       date not null,
    analysis_type       text not null check (analysis_type in ('pre', 'drop')),
    analysis_status     text not null,

    analysis_lab_id     integer,
    analysis_eq_id      integer,
    analyst_id          integer,

    notes               text,

    foreign key (heat_id) references core.heats(heat_id),

    constraint uq_chem_session unique (heat_id, analysis_type)
);

create index if not exists ix_chem_sessions_heat_id on lab.chem_analysis_sessions(heat_id);
create index if not exists ix_chem_sessions_date on lab.chem_analysis_sessions(analysis_date);

create table if not exists lab.chem_analysis_values (
    chem_value_id       serial primary key,
    chem_session_id     integer not null,
    element_id          integer not null,
    element_value       real not null,

    foreign key (chem_session_id) references lab.chem_analysis_sessions(chem_session_id),
    foreign key (element_id) references ref.elements(element_id),

    constraint uq_chem_session_element unique (chem_session_id, element_id)
);

create index if not exists ix_chem_values_session on lab.chem_analysis_values(chem_session_id);
create index if not exists ix_chem_values_element on lab.chem_analysis_values(element_id);

-- =========================
-- lab: mechanical tests
-- =========================

create table if not exists lab.test_sessions (
    test_session_id         serial primary key,
    session_code            text not null unique,
    session_date            date not null,

    heat_id                 integer not null,
    lab_id                  integer,
    analyst_id              integer,

    session_type            text not null check (session_type in ('standard', 'reanalysis')),
    test_session_status     text not null check (test_session_status in ('valid', 'invalid', 'deviated')),

    notes                   text,

    foreign key (heat_id) references core.heats(heat_id)
);

create index if not exists ix_test_sessions_heat_id on lab.test_sessions(heat_id);
create index if not exists ix_test_sessions_date on lab.test_sessions(session_date);

create table if not exists lab.test_session_values (
    value_id            serial primary key,
    test_session_id     integer not null,
    test_type_id        integer not null,
    test_value          real not null,

    value_status        text not null check (value_status in ('valid', 'invalid')),
    notes               text,

    foreign key (test_type_id) references ref.test_types(test_type_id),
    foreign key (test_session_id) references lab.test_sessions(test_session_id),

    constraint uq_test_session_type unique (test_session_id, test_type_id)
);

create index if not exists ix_test_values_session on lab.test_session_values(test_session_id);
create index if not exists ix_test_values_type on lab.test_session_values(test_type_id);
