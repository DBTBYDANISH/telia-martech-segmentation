{{ config(materialized='view') }}

with int_customer_metrics as (
    select *
    from {{ ref('int_customer_metrics') }}
)

select *
from int_customer_metrics
