{{
    config(
        materialized='table',
        schema='cdw_staging',
        alias='cdw_stg__bkd_lv02_by_sector_l1'
    )
}}

select
    market_date,
    portfolio_code,
    sector_l1_code,
    sector_l1_name,
    sum(weight_pct) as total_weight_pct,
    sum(market_value_base) as total_market_value_base,
    count(distinct isin) as distinct_instruments
from {{ ref('cdw_stg__hld_lv01_holdings_classified') }}
group by
    market_date,
    portfolio_code,
    sector_l1_code,
    sector_l1_name
