{{
    config(
        materialized='table',
        schema='cdw_staging',
        alias='cdw_stg__prf_lv02_weekly_returns'
    )
}}

with daily_portfolio_returns as (
    select
        p.valuation_date as market_date,
        p.portfolio_code,
        sum(p.contribution_bps) as portfolio_return_bps
    from {{ ref('cdw_raw_performance') }} as p
    inner join {{ ref('cdw_raw_as_of_date') }} as d
        on p.valuation_date = d.as_of_date
    where d.is_business_day
    group by
        p.valuation_date,
        p.portfolio_code
),

weekly_compound as (
    select
        d.year_of_week_iso as iso_year,
        d.week_iso as iso_week,
        r.portfolio_code,
        exp(sum(ln(1 + (r.portfolio_return_bps / 10000.0)))) - 1 as compound_return
    from daily_portfolio_returns as r
    inner join {{ ref('cdw_raw_as_of_date') }} as d
        on r.market_date = d.as_of_date
    group by
        d.year_of_week_iso,
        d.week_iso,
        r.portfolio_code
)

select * from weekly_compound
