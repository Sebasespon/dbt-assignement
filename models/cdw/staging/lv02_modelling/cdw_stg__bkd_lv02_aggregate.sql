{{
    config(
        materialized='table',
        schema='cdw_staging',
        alias='cdw_stg__bkd_lv02_aggregate'
    )
}}

select
    market_date,
    portfolio_code,
    'REGION' as breakdown_type,
    region_code as level_1_code,
    region_name as level_1_name,
    null as level_2_code,
    null as level_2_name,
    total_weight_pct,
    total_market_value_base,
    distinct_instruments
from {{ ref('cdw_stg__bkd_lv02_by_region') }}

union all

select
    market_date,
    portfolio_code,
    'SECTOR_L1' as breakdown_type,
    sector_l1_code as level_1_code,
    sector_l1_name as level_1_name,
    null as level_2_code,
    null as level_2_name,
    total_weight_pct,
    total_market_value_base,
    distinct_instruments
from {{ ref('cdw_stg__bkd_lv02_by_sector_l1') }}

union all

select
    market_date,
    portfolio_code,
    'SECTOR_L2' as breakdown_type,
    sector_l1_code as level_1_code,
    sector_l1_name as level_1_name,
    sector_l2_code as level_2_code,
    sector_l2_name as level_2_name,
    total_weight_pct,
    total_market_value_base,
    distinct_instruments
from {{ ref('cdw_stg__bkd_lv02_by_sector_l2') }}
