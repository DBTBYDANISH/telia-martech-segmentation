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

as_of_timestamp AS (
    SELECT {{ get_as_of_timestamp() }} AS as_of_timestamp
),

event_aggregates AS (
    SELECT
        pe.customer_id,
        COUNT_IF(
            pe.event_type = 'login'
            AND pe.event_ts >= DATEADD('day', -30, bounds.as_of_timestamp)
            AND pe.event_ts <= bounds.as_of_timestamp
        ) AS logins_last_30_days,
        COUNT_IF(
            pe.event_type = 'login'
            AND pe.event_ts >= DATEADD('day', -14, bounds.as_of_timestamp)
            AND pe.event_ts <= bounds.as_of_timestamp
        ) AS logins_last_14_days,
        DATEDIFF('day', MAX(pe.event_ts), bounds.as_of_timestamp) AS days_since_last_activity,
        COUNT_IF(
            pe.event_type = 'support_ticket'
            AND pe.event_ts >= DATEADD('day', -90, bounds.as_of_timestamp)
            AND pe.event_ts <= bounds.as_of_timestamp
        ) AS support_tickets_last_90_days,
        COUNT(DISTINCT CASE
            WHEN pe.event_ts >= DATEADD('day', -14, bounds.as_of_timestamp)
                AND pe.event_ts <= bounds.as_of_timestamp
            THEN pe.event_date
        END) AS active_days_last_14_days,
        COUNT(DISTINCT CASE
            WHEN pe.event_ts >= DATEADD('day', -28, bounds.as_of_timestamp)
                AND pe.event_ts < DATEADD('day', -14, bounds.as_of_timestamp)
            THEN pe.event_date
        END) AS active_days_prior_14_days

    FROM product_events pe
    CROSS JOIN as_of_timestamp bounds
    GROUP BY pe.customer_id, bounds.as_of_timestamp
),

campaign_aggregates AS (
    SELECT
        ci.customer_id,
        COUNT_IF(
            ci.interaction_type = 'delivered'
            AND ci.interaction_ts >= DATEADD('day', -60, bounds.as_of_timestamp)
            AND ci.interaction_ts <= bounds.as_of_timestamp
        ) AS total_delivered_last_60_days,
        COUNT_IF(
            ci.interaction_type = 'opened'
            AND ci.interaction_ts >= DATEADD('day', -60, bounds.as_of_timestamp)
            AND ci.interaction_ts <= bounds.as_of_timestamp
        ) AS total_opened_last_60_days
    FROM campaign_interactions ci
    CROSS JOIN as_of_timestamp bounds
    GROUP BY ci.customer_id, bounds.as_of_timestamp
)

SELECT
    c.customer_id,
    bounds.as_of_timestamp,
    COALESCE(ea.logins_last_30_days, 0) AS logins_last_30_days,
    COALESCE(ea.logins_last_14_days, 0) AS logins_last_14_days,
    ea.days_since_last_activity,
    COALESCE(ea.support_tickets_last_90_days, 0) AS support_tickets_last_90_days,
    COALESCE(ea.active_days_last_14_days, 0) AS active_days_last_14_days,
    COALESCE(ea.active_days_prior_14_days, 0) AS active_days_prior_14_days,
    CASE
        WHEN COALESCE(ca.total_delivered_last_60_days, 0) = 0 THEN 0.0
        ELSE CAST(ca.total_opened_last_60_days AS FLOAT)
            / ca.total_delivered_last_60_days
    END AS campaign_open_rate_last_60_days,
    ROUND(campaign_open_rate_last_60_days * 100, 2) AS campaign_open_rate_last_60_days_percentage

FROM customers c
CROSS JOIN as_of_timestamp bounds
LEFT JOIN event_aggregates ea
    ON c.customer_id = ea.customer_id
LEFT JOIN campaign_aggregates ca
    ON c.customer_id = ca.customer_id
