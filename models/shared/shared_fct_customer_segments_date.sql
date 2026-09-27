{{ config(materialized='view') }}

with fct_customer_segments_date as (
    select *
    from {{ ref('fct_customer_segments_date') }}
)

select *
from fct_customer_segments_date
