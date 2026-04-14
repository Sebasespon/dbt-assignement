-- CDW Landing: raw daily holdings positions as ingested from IDW.
-- No transformation — this is a direct pass-through from IDW.

{{
    config(
        materialized='view',
        schema='cdw_landing',
        alias='cdw_raw_portfolios'
    )
}}

select * from {{ source('idw_staging', 'idw_stg_portfolios') }}
