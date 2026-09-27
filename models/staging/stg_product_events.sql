
with stg_product_events as (
select
    event_id,
    customer_id,
    lower(event_type) as event_type, 
    event_ts::timestamp as event_ts,
    event_properties
from {{ source('stg', 'product_events') }}
)

Select 
    *
From stg_product_events
