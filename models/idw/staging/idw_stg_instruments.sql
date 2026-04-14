-- IDW Staging: cleanse and standardise instrument master data.

{{
    config(
        materialized='table',
        schema='idw_staging',
        alias='idw_stg_instruments'
    )
}}

select
    trim(isin)                          as isin,
    trim(instrument_name)               as instrument_name,
    upper(trim(asset_class))            as asset_class,
    upper(trim(country_code))           as country_code,
    upper(trim(currency))               as currency,
    upper(trim(sector_l1_code))         as sector_l1_code,
    trim(sector_l1_name)                as sector_l1_name,
    upper(trim(sector_l2_code))         as sector_l2_code,
    trim(sector_l2_name)                as sector_l2_name,
    upper(trim(region_code))            as region_code,
    trim(region_name)                   as region_name,

    -- Simple validity flag — used by downstream tests
    case
        when isin is null or length(trim(isin)) != 12 then false
        when asset_class not in ('EQUITY', 'BOND')    then false
        else true
    end                                 as is_valid

from {{ ref('idw_raw_instruments') }}