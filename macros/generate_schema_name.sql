-- Override dbt's default schema naming so that +schema values are used verbatim
-- instead of being prefixed with the target schema (e.g. "main_cdw_lab_vault").
-- This lets every layer land in its own named schema, matching the CDW architecture.
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}