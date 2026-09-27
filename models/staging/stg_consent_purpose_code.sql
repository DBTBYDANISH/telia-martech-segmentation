
With stg_consent_purpose_code as (
    select
        purpose_code,
        name,
        legal_ground
    from {{ source('stg', 'consent_purpose_code') }}
)

select 
    * 
from stg_consent_purpose_code
