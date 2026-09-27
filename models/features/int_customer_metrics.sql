
WITH customers AS (
    SELECT
        customer_id
    FROM {{ ref('stg_customers') }}
),

product_events AS (
    SELECT
        customer_id,
        event_type,
        event_ts,
        DATE(event_ts) AS event_date
    FROM {{ ref('stg_product_events') }}
),

campaign_interactions AS (
    SELECT
        customer_id,
        interaction_type,
        interaction_ts
    FROM {{ ref('stg_campaign_interactions') }}
),

event_aggregates AS (
    SELECT
        customer_id,

        -- Total logins in last 30 days
        SUM(
            CASE
                WHEN event_type = 'login'
                    AND event_ts >= DATEADD('day', -30, CURRENT_TIMESTAMP())
                THEN 1
                ELSE 0
            END
        ) AS logins_last_30_days,

        -- Days since last activity
        CURRENT_DATE - MAX(event_date) AS days_since_last_activity,

        -- Total support tickets in last 90 days
        SUM(
            CASE
                WHEN event_type = 'support_ticket'
                    AND event_ts >= DATEADD('day', -90, CURRENT_TIMESTAMP())
                THEN 1
                ELSE 0
            END
        ) AS support_tickets_last_90_days,

        -- Distinct active days in last 14 days across all events
        COUNT(
            DISTINCT CASE
                WHEN event_ts >= DATEADD('day', -14, CURRENT_TIMESTAMP())
                THEN event_date
            END
        ) AS active_days_last_14_days,

        -- Distinct active days in the 14 days prior to the last 14 days
        COUNT(
            DISTINCT CASE
                WHEN event_ts >= DATEADD('day', -28, CURRENT_TIMESTAMP())
                    AND event_ts < DATEADD('day', -14, CURRENT_TIMESTAMP())
                THEN event_date
            END
        ) AS active_days_prior_14_days

    FROM product_events
    GROUP BY customer_id
),

campaign_aggregates AS (
    SELECT
        customer_id,

        -- Total delivered in last 60 days
        SUM(
            CASE
                WHEN interaction_type = 'delivered'
                    AND interaction_ts >= DATEADD('day', -60, CURRENT_TIMESTAMP())
                THEN 1
                ELSE 0
            END
        ) AS total_delivered_last_60_days,

        -- Total opened in last 60 days
        SUM(
            CASE
                WHEN interaction_type = 'opened'
                    AND interaction_ts >= DATEADD('day', -60, CURRENT_TIMESTAMP())
                THEN 1
                ELSE 0
            END
        ) AS total_opened_last_60_days

    FROM campaign_interactions
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    COALESCE(e.logins_last_30_days, 0) AS logins_last_30_days,
    e.days_since_last_activity,
    COALESCE(e.support_tickets_last_90_days, 0) AS support_tickets_last_90_days,
    COALESCE(e.active_days_last_14_days, 0) AS active_days_last_14_days,
    COALESCE(e.active_days_prior_14_days, 0) AS active_days_prior_14_days,
    -- Campaign open rate over last 60 days
    CASE
        WHEN COALESCE(ca.total_delivered_last_60_days, 0) = 0
            THEN 0.0
        ELSE CAST(ca.total_opened_last_60_days AS FLOAT)
            / ca.total_delivered_last_60_days
    END AS campaign_open_rate_last_60_days,
    ROUND(campaign_open_rate_last_60_days * 100, 2) AS campaign_open_rate_last_60_days_percentage

FROM customers AS c
LEFT JOIN event_aggregates AS e
    ON c.customer_id = e.customer_id
LEFT JOIN campaign_aggregates AS ca
    ON c.customer_id = ca.customer_id
