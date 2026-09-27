{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='customer_id'
) }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

cust_metrics as (
    select * from {{ ref('int_customer_metrics') }}
),

-- Ensure customers have active marketing consent
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
        m.logins_last_30_days,
        m.days_since_last_activity,
        m.support_tickets_last_90_days,
        m.active_days_last_14_days,
        m.active_days_prior_14_days,
        m.campaign_open_rate_last_60_days,
        m.campaign_open_rate_last_60_days_percentage,
        
        -- Eligibility Check: Active subscription + valid marketing consent
        case 
            when c.subscription_status = 'active' and vc.customer_id is not null then true
            else false
        end as is_eligible,

        -- Segment 1: high_value_engaged 
        -- (Premium plan + logged in 5+ of last 14 days + open rate > 30%)
        -- Note: using active_days_last_14_days as proxy for logging in 5+ of last 14 days
        case 
            when c.subscription_status = 'active' 
                 and c.subscription_plan = 'premium' 
                 and m.active_days_last_14_days >= 5 
                 and m.campaign_open_rate_last_60_days > 0.30 
            then true else false 
        end as is_high_value_engaged,

        -- Segment 2: at_risk_dormant 
        -- (No login in last 14 days + was active 30-60 days ago -> measured via days_since_last_activity between 30 and 60)
        case 
            when c.subscription_status = 'active'
                 and (m.days_since_last_activity >= 14 and m.days_since_last_activity between 30 and 60)
            then true else false 
        end as is_at_risk_dormant,

        -- Segment 3: upgrade_candidate 
        -- (Basic/standard plan + 10+ logins in 30 days + zero support tickets in 90 days)
        case 
            when c.subscription_status = 'active'
                 and c.subscription_plan in ('basic', 'standard')
                 and m.logins_last_30_days >= 10
                 and m.support_tickets_last_90_days = 0
            then true else false 
        end as is_upgrade_candidate,

        -- Segment 4: winback_target 
        -- (Churned in last 90 days + had open rate > 20% before churning)
        case 
            when c.subscription_status = 'churned'
                 and c.status_change_date >= dateadd('day', -90, current_date())
                 and m.campaign_open_rate_last_60_days > 0.20
            then true else false 
        end as is_winback_target,

        -- Segment 5: engagement_declining 
        -- (Active days in last 14 < 50% of active days in the 14 days before that)
        case 
            when c.subscription_status = 'active'
                 and m.active_days_last_14_days < (m.active_days_prior_14_days * 0.50)
                 and m.active_days_prior_14_days > 0
            then true else false 
        end as is_engagement_declining

    from customers c
    left join cust_metrics m on c.customer_id = m.customer_id
    left join valid_consent vc on c.customer_id = vc.customer_id
)

select *
from base_segmentation
-- Restrict final mart to only eligible customers as requested by business logic rules
where is_eligible = true
