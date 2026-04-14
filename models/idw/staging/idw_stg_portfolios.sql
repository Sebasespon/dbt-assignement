-- IDW Staging: cleanse and standardise portfolio master data.

{{
    config(
        materialized='table',
        schema='idw_staging',
        alias='idw_stg_portfolios'
    )
}}

select
    upper(trim(portfolio_code))         as portfolio_code,
    trim(portfolio_name)                as portfolio_name,
    upper(trim(base_currency))          as base_currency,

    is_benchmark,

    case
        when trim(benchmark_code) = '' then null
        else upper(trim(benchmark_code))
    end as benchmark_code

from {{ ref('idw_raw_portfolios') }}
