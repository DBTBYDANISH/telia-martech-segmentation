{{ config(materialized='view') }}

with int_customer_metrics_date as (
    select *
    from {{ ref('int_customer_metrics_date') }}
)

select *
from int_customer_metrics_date
