-- Generic test: assert that the combination of columns is unique.
-- Usage in schema.yml:
--   tests:
--     - unique_combination:
--         combination_of: [col_a, col_b]
{% test unique_combination(model, combination_of) %}

with counted as (
    select
        {{ combination_of | join(', ') }},
        count(*) as row_count
    from {{ model }}
    group by {{ combination_of | join(', ') }}
)
select *
from counted
where row_count > 1

{% endtest %}