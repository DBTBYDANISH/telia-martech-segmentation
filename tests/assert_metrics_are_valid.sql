WITH metrics AS (
    SELECT
        'int_customer_metrics' AS model_name,
        customer_id,
        logins_last_30_days,
        NULL AS logins_last_14_days,
        support_tickets_last_90_days,
        active_days_last_14_days,
        active_days_prior_14_days,
        campaign_open_rate_last_60_days
    FROM {{ ref('int_customer_metrics') }}

    UNION ALL

    SELECT
        'int_customer_metrics_date' AS model_name,
        customer_id,
        logins_last_30_days,
        logins_last_14_days,
        support_tickets_last_90_days,
        active_days_last_14_days,
        active_days_prior_14_days,
        campaign_open_rate_last_60_days
    FROM {{ ref('int_customer_metrics_date') }}
)

SELECT
    model_name,
    customer_id
FROM metrics
WHERE logins_last_30_days < 0
    OR COALESCE(logins_last_14_days, 0) < 0
   OR support_tickets_last_90_days < 0
   OR active_days_last_14_days < 0
   OR active_days_last_14_days > 14
   OR active_days_prior_14_days < 0
   OR active_days_prior_14_days > 14
   OR campaign_open_rate_last_60_days < 0
   OR campaign_open_rate_last_60_days > 1
