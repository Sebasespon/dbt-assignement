{{
    config(
        materialized = 'table',
        schema = 'cdw_landing',
        alias = 'as_of_date'
    )
}}

{%- set datepart   = "day" -%}
{%- set start_date = "CAST('{}' AS DATE)".format(var('START_DATE')) -%}
{%- set end_date   = "CAST('{}' AS DATE)".format(var('END_DATE')) -%}

-- ── Step 1: generate the date spine ──────────────────────────────────────────
with spine as (
    {{
        dbt_utils.date_spine(
            datepart   = datepart,
            start_date = start_date,
            end_date   = end_date
        )
    }}
),

-- ── Step 2: cast date_day (TIMESTAMP from date_spine) to DATE once ────────────
base as (
    select cast(date_day as date) as d from spine
),

-- ── Step 3: derive all calendar attributes ────────────────────────────────────
-- Boundaries that are referenced again in step 4 (flags) are computed here
-- so they can be reused by name rather than duplicating the expression.
dated as (
    select
        d                                                                   as as_of_date,

        --
        -- Date split
        --
        dayofmonth(d)                                                      as day,
        dayname(d)                                                         as day_name,

        isodow(d)                                                          as day_of_week_iso,
        dayofweek(d)                                                       as day_of_week,
        dayofmonth(d)                                                      as day_of_month,
        dayofyear(d)                                                       as day_of_year,

        extract(epoch from d)                                              as epoch,

        -- ISO week label: "2024-W03-1"
        isoyear(d)::varchar
            || '-W' || lpad(weekofyear(d)::varchar, 2, '0')
            || '-' || isodow(d)::varchar                                   as week_of_year_iso,
        weekofyear(d)                                                      as week_iso,
        weekofyear(d)                                                      as week_of_year,

        month(d)                                                           as month,
        monthname(d)                                                       as month_name,

        quarter(d)                                                         as quarter,
        case quarter(d)
            when 1 then 'First'
            when 2 then 'Second'
            when 3 then 'Third'
            when 4 then 'Fourth'
        end                                                                as quarter_name,

        year(d)                                                            as year,
        isoyear(d)                                                         as year_of_week_iso,

        --
        -- Relative dates
        --

        -- Week boundaries (ISO: Mon-Sun)
        (d - cast(isodow(d) - 1 as integer))::date                         as first_day_of_week,
        (d + cast(7 - isodow(d) as integer))::date                         as last_day_of_week,
        (d + cast(5 - isodow(d) as integer))::date                         as last_business_day_of_week,

        -- Month boundaries
        date_trunc('month', d)::date                                       as first_day_of_month,
        ((date_trunc('month', d) + interval '1 month')
            - interval '1 day')::date                                      as last_day_of_month,

        case isodow(date_trunc('month', d)::date)
            when 6 then (date_trunc('month', d) + interval '2 days')::date
            when 7 then (date_trunc('month', d) + interval '1 day')::date
            else        date_trunc('month', d)::date
        end                                                                as first_business_day_of_month,

        case isodow(((date_trunc('month', d) + interval '1 month')
                - interval '1 day')::date)
            when 6 then ((date_trunc('month', d) + interval '1 month')
                            - interval '2 days')::date
            when 7 then ((date_trunc('month', d) + interval '1 month')
                            - interval '3 days')::date
            else        ((date_trunc('month', d) + interval '1 month')
                            - interval '1 day')::date
        end                                                                as last_business_day_of_month,

        -- Quarter boundaries
        date_trunc('quarter', d)::date                                     as first_day_of_quarter,
        ((date_trunc('quarter', d) + interval '3 months')
            - interval '1 day')::date                                      as last_day_of_quarter,

        -- Year boundaries
        date_trunc('year', d)::date                                        as first_day_of_year,
        ((date_trunc('year', d) + interval '1 year')
            - interval '1 day')::date                                      as last_day_of_year,

        --
        -- Formatted strings
        --
        strftime('%Y%m',   d)                                              as yyyymm,
        strftime('%Y%m%d', d)                                              as yyyymmdd

    from base
),

-- ── Step 4: add columns that reference the boundaries computed above ──────────
final as (
    select
        *,

        -- last-business-day of quarter (depends on last_day_of_quarter)
        case isodow(last_day_of_quarter)
            when 7 then (last_day_of_quarter - interval '2 days')::date
            when 6 then (last_day_of_quarter - interval '1 day')::date
            else        last_day_of_quarter
        end                                                                as last_business_day_of_quarter,

        -- last-business-day of year (depends on last_day_of_year)
        case isodow(last_day_of_year)
            when 7 then (last_day_of_year - interval '2 days')::date
            when 6 then (last_day_of_year - interval '1 day')::date
            else        last_day_of_year
        end                                                                as last_business_day_of_year,

        --
        -- Date checks
        --
        (isodow(as_of_date) = 1)                                           as is_first_day_of_week,
        (isodow(as_of_date) = 7)                                           as is_last_day_of_week,
        (isodow(as_of_date) = 5)                                           as is_last_business_day_of_week,
        (isodow(as_of_date) <= 5)                                          as is_business_day,
        (isodow(as_of_date) in (6, 7))                                     as is_weekend_day,
        (as_of_date = last_day_of_month)                                   as is_last_day_of_month,
        (as_of_date = last_business_day_of_month)                          as is_last_business_day_of_month

    from dated
)

select * from final
