-- CDW Staging — S1 (Holdings - Breakdowns)
-- ─────────────────────────────────────────────────────────────────────────────
-- Joins clean holdings with instrument classification metadata sourced from IDW.
-- This is the foundation for all breakdown aggregations in S2.
--
-- One row per (market_date, portfolio_code, isin).
-- Includes both raw holding values AND the full classification hierarchy
-- so that S2 can group by any level without re-joining.
-- ─────────────────────────────────────────────────────────────────────────────

{{
    config(
        materialized='view',
        schema='cdw_staging',
        alias='cdw_stg__hld_holdings_classified'
    )
}}

select
    -- ── Temporal / identity keys ──────────────────────────────────────────
    h.valuation_date as market_date,
    h.portfolio_code,
    h.isin,

    -- ── Instrument attributes (from IDW mesh) ────────────────────────────
    i.instrument_name,
    i.asset_class,
    i.country_code,
    i.currency                          as instrument_currency,

    -- ── Classification hierarchy ──────────────────────────────────────────
    -- Level 1: Region
    i.region_code                       as region_code,
    i.region_name                       as region_name,
    -- Level 1 (alt): Sector top-level
    i.sector_l1_code                    as sector_l1_code,
    i.sector_l1_name                    as sector_l1_name,
    -- Level 2: Sector sub-category
    i.sector_l2_code                    as sector_l2_code,
    i.sector_l2_name                    as sector_l2_name,

    -- ── Holding values ────────────────────────────────────────────────────
    h.quantity,
    h.market_value_base,
    h.weight_pct

from {{ ref('cdw_raw_holdings') }}      as h

-- Enrich from IDW's exposed instrument reference (data mesh join)
inner join {{ ref('cdw_raw_instruments') }} as i
    on h.isin = i.isin