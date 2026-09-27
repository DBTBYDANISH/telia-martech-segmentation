
with stg_campaign_interactions as (
    select 
        interaction_id,
        customer_id,
        campaign_id,
        lower(channel) as channel,  -- Standardize values to lowercase
        lower(interaction_type) as interaction_type, -- Standardize values to lowercase
        interaction_ts::timestamp as interaction_ts
    from {{ source('stg', 'campaign_interactions') }}
)

select 
    * 
from stg_campaign_interactions
