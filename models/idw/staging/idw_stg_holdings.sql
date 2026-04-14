-- IDW Staging: cleanse and standardise daily holdings positions.

{{
    config(
        materialized='table',
        schema='idw_staging',
        alias='idw_stg_holdings'
    )
}}

select
    cast(valuation_date as date)            as valuation_date,
    upper(trim(portfolio_code))             as portfolio_code,
    upper(trim(isin))                       as isin,

    cast(quantity as bigint)                as quantity,
    cast(market_value_base as double)       as market_value_base,
    cast(weight_pct as double)              as weight_pct,

    -- Validity flag — rejects rows with broken keys or implausible values
    case
        when valuation_date is null                         then false
        when portfolio_code is null or trim(portfolio_code) = '' then false
        when isin is null or length(trim(isin)) != 12      then false
        when quantity is null or quantity <= 0              then false
        when market_value_base is null or market_value_base <= 0 then false
        when weight_pct is null or weight_pct < 0 or weight_pct > 100 then false
        else true
    end                                     as is_valid

from {{ ref('idw_raw_holdings') }}
