{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='customer_id'
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

cust_metrics as (
    select * from {{ ref('int_customer_metrics_date') }}
),

valid_consent as (
    select distinct cr.customer_id
    from {{ ref('stg_consent_registry') }} cr
    join {{ ref('stg_consent_purpose_code') }} cpc
      on cr.purpose_code = cpc.purpose_code
),

base_segmentation as (
    select
        c.customer_id,
        c.email,
        c.subscription_plan,
        c.subscription_status,
        c.signup_date,
        c.status_change_date,
        m.as_of_timestamp,
        m.logins_last_30_days,
        m.logins_last_14_days,
        m.days_since_last_activity,
        m.support_tickets_last_90_days,
        m.active_days_last_14_days,
        m.active_days_prior_14_days,
        m.campaign_open_rate_last_60_days,
        m.campaign_open_rate_last_60_days_percentage,
        case
            when c.subscription_status = 'active'
                and vc.customer_id is not null
            then true else false
        end as is_eligible,
        case
            when c.subscription_status = 'active'
                and c.subscription_plan = 'premium'
                and m.logins_last_14_days >= 5
                and m.campaign_open_rate_last_60_days > 0.30
            then true else false
        end as is_high_value_engaged,
        case
            when c.subscription_status = 'active'
                and m.days_since_last_activity between 30 and 60
            then true else false
        end as is_at_risk_dormant,
        case
            when c.subscription_status = 'active'
                and c.subscription_plan in ('basic', 'standard')
                and m.logins_last_30_days >= 10
                and m.support_tickets_last_90_days = 0
            then true else false
        end as is_upgrade_candidate,
        case
            when c.subscription_status = 'churned'
                and c.status_change_date >= DATEADD('day', -90, CAST(m.as_of_timestamp AS DATE))
                and m.campaign_open_rate_last_60_days > 0.20
            then true else false
        end as is_winback_target,
        case
            when c.subscription_status = 'active'
                and m.active_days_prior_14_days > 0
                and m.active_days_last_14_days < (m.active_days_prior_14_days * 0.50)
            then true else false
        end as is_engagement_declining
    from customers c
    left join cust_metrics m
        on c.customer_id = m.customer_id
    left join valid_consent vc
        on c.customer_id = vc.customer_id
)

select *
from base_segmentation
where is_eligible = true
