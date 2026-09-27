SELECT
    customer_id,
    'high_value_engaged' AS segment_name
FROM {{ ref('fct_customer_segments') }}
WHERE is_high_value_engaged = TRUE
  AND NOT (
      subscription_status = 'active'
      AND subscription_plan = 'premium'
      AND COALESCE(active_days_last_14_days, 0) >= 5
      AND COALESCE(campaign_open_rate_last_60_days, 0) > 0.30
  )

UNION ALL

SELECT
    customer_id,
    'at_risk_dormant' AS segment_name
FROM {{ ref('fct_customer_segments') }}
WHERE is_at_risk_dormant = TRUE
  AND NOT (
      subscription_status = 'active'
      AND days_since_last_activity BETWEEN 30 AND 60
  )

UNION ALL

SELECT
    customer_id,
    'upgrade_candidate' AS segment_name
FROM {{ ref('fct_customer_segments') }}
WHERE is_upgrade_candidate = TRUE
  AND NOT (
      subscription_status = 'active'
      AND subscription_plan IN ('basic', 'standard')
      AND COALESCE(logins_last_30_days, 0) >= 10
      AND COALESCE(support_tickets_last_90_days, 0) = 0
  )

UNION ALL

SELECT
    customer_id,
    'winback_target' AS segment_name
FROM {{ ref('fct_customer_segments') }}
WHERE is_winback_target = TRUE
  AND NOT (
      subscription_status = 'churned'
      AND status_change_date >= DATEADD('day', -90, CURRENT_DATE())
      AND COALESCE(campaign_open_rate_last_60_days, 0) > 0.20
  )

UNION ALL

SELECT
    customer_id,
    'engagement_declining' AS segment_name
FROM {{ ref('fct_customer_segments') }}
WHERE is_engagement_declining = TRUE
  AND NOT (
      subscription_status = 'active'
      AND COALESCE(active_days_prior_14_days, 0) > 0
      AND COALESCE(active_days_last_14_days, 0) < active_days_prior_14_days * 0.50
  )
