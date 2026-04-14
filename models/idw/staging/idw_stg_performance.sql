-- IDW Staging: cleanse and standardise daily instrument-level performance data.

{{
    config(
        materialized='table',
        schema='idw_staging',
        alias='idw_stg_performance'
    )
}}

select
    cast(valuation_date as date)            as valuation_date,
    upper(trim(portfolio_code))             as portfolio_code,
    upper(trim(isin))                       as isin,

    cast(daily_return_bps as double)        as daily_return_bps,
    cast(contribution_bps as double)        as contribution_bps,

    -- Validity flag — rejects rows with broken keys or missing return data
    case
        when valuation_date is null                              then false
        when portfolio_code is null or trim(portfolio_code) = '' then false
        when isin is null or length(trim(isin)) != 12           then false
        when daily_return_bps is null                            then false
        when contribution_bps is null                            then false
        else true
    end                                     as is_valid

from {{ ref('idw_raw_performance') }}
