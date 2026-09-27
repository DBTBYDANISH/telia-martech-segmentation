{{ config(materialized='view') }}

with fct_customer_segments as (
    select *
    from {{ ref('fct_customer_segments') }}
)

select *
from fct_customer_segments
