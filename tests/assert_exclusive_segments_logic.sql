-- Singular test: Churned customers should never qualify for active engagement segments
select
    customer_id,
    subscription_status,
    is_high_value_engaged
from {{ ref('fct_customer_segments') }}
where subscription_status = 'churned' 
  and is_high_value_engaged = true
  