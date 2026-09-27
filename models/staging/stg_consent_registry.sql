
With stg_consent_registry as(
    select
        cast('CUST_' || trim(customer_id) as varchar) as customer_id,  -- Prefixing the customer_id with 'CUST_' to avoid conflicts in join
        purpose_code,
        consent_ts::timestamp as consent_ts
from {{ source('stg', 'consent_registry') }}
)

select 
    *
from stg_consent_registry
