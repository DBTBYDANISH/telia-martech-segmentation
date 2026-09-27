
With stg_customers as(
    select
        customer_id,
        email,
        phone_number,
        signup_date::date as signup_date,
        lower(subscription_plan) as subscription_plan, -- Standardize values to lowercase
        lower(subscription_status) as subscription_status, -- Standardize values to lowercase
        status_change_date::date as status_change_date
from {{ source('stg', 'customers') }}
)

Select 
    *
from stg_customers