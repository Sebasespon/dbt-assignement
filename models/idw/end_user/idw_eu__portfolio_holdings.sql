-- IDW End-User: Portfolio holdings exposure view.
-- ─────────────────────────────────────────────────────────────────────────────
-- Consumer-facing snapshot of active portfolio holdings enriched with full
-- instrument classification hierarchy.
--
-- One row per (valuation_date, portfolio_code, isin).
-- ─────────────────────────────────────────────────────────────────────────────

{{
    config(
        materialized = 'view',
        schema = 'idw_end_user',
        alias = 'idw_eu__portfolio_holdings'
    )
}}

select
    -- ── Temporal / identity keys ──────────────────────────────────────────
    h.valuation_date,
    p.portfolio_code,
    p.portfolio_name,
    p.base_currency,

    -- ── Instrument identity ────────────────────────────────────────────────
    inst.isin,
    i.instrument_name,
    i.asset_class,
    i.country_code,
    i.region_code,
    i.region_name,
    i.sector_l1_code,
    i.sector_l1_name,
    i.sector_l2_code,
    i.sector_l2_name,

    -- ── Position metrics ──────────────────────────────────────────────────
    h.quantity,
    h.market_value_base,
    h.weight_pct

from {{ ref('idw_stg_holdings') }}      as h

inner join {{ ref('idw_stg_portfolios') }}  as p
    on h.portfolio_code = p.portfolio_code

inner join {{ ref('idw_stg_instruments') }} as i
    on h.isin = inst.isin

where h.is_valid
