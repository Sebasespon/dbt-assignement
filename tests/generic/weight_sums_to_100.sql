-- Generic test: validate that total_weight_pct sums to approximately 100% per market_date and portfolio_code.
-- Usage in schema.yml:
--   tests:
--     - weight_sums_to_100:
--         tolerance: 0.02
{% test weight_sums_to_100(model, tolerance=0.02) %}

with grouped as (
    select
        market_date,
        portfolio_code,
        sum(total_weight_pct) as total_weight_pct
    from {{ model }}
    group by market_date, portfolio_code
)
select *
from grouped
where abs(total_weight_pct - 100.0) > {{ tolerance }}

{% endtest %}
