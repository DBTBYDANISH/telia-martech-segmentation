import os
from pathlib import Path

import pandas as pd
import streamlit as st


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SEEDS_DIR = PROJECT_ROOT / "seeds"
EXPORT_PATH = Path(__file__).resolve().parent / "data" / "fct_customer_segments_date.csv"
DEFAULT_AS_OF_DATE = os.getenv("AS_OF_DATE", "2025-06-30")
SEGMENT_COLUMNS = {
    "High-value engaged": "is_high_value_engaged",
    "At-risk dormant": "is_at_risk_dormant",
    "Upgrade candidate": "is_upgrade_candidate",
    "Winback target": "is_winback_target",
    "Engagement declining": "is_engagement_declining",
}


@st.cache_data
def load_seed_segments() -> tuple[pd.DataFrame, pd.Timestamp]:
    customers = pd.read_csv(SEEDS_DIR / "customers.csv", parse_dates=["signup_date", "status_change_date"])
    events = pd.read_csv(SEEDS_DIR / "product_events.csv", parse_dates=["event_ts"])
    interactions = pd.read_csv(
        SEEDS_DIR / "campaign_interactions.csv",
        parse_dates=["interaction_ts"],
    )
    consent = pd.read_csv(SEEDS_DIR / "consent_registry.csv", dtype={"customer_id": str})

    consent["customer_id"] = "CUST_" + consent["customer_id"].str.zfill(6)
    marketing_codes = {"PP_011", "PP_012", "PP_013", "PP_014"}
    eligible_consent = set(consent.loc[consent["purpose_code"].isin(marketing_codes), "customer_id"])

    as_of = pd.Timestamp(DEFAULT_AS_OF_DATE)
    event_window = events.loc[events["event_ts"].between(as_of - pd.Timedelta(days=90), as_of)].copy()
    event_window["event_date"] = event_window["event_ts"].dt.date

    event_metrics = event_window.groupby("customer_id").agg(
        last_activity=("event_ts", "max"),
        logins_last_30_days=("event_type", lambda values: int((values == "login").sum())),
        support_tickets_last_90_days=("event_type", lambda values: int((values == "support_ticket").sum())),
    )

    login_events = event_window[event_window["event_type"] == "login"]
    login_14 = login_events.loc[
        login_events["event_ts"] >= as_of - pd.Timedelta(days=14)
    ].groupby("customer_id").size().rename("logins_last_14_days")

    recent_events = event_window.loc[event_window["event_ts"] >= as_of - pd.Timedelta(days=14)]
    active_days = recent_events.groupby("customer_id")["event_date"].nunique().rename("active_days_last_14_days")
    prior_events = event_window.loc[
        event_window["event_ts"].between(
            as_of - pd.Timedelta(days=28),
            as_of - pd.Timedelta(days=14),
            inclusive="left",
        )
    ]
    prior_days = prior_events.groupby("customer_id")["event_date"].nunique().rename("active_days_prior_14_days")

    delivered = interactions.loc[
        (interactions["interaction_type"] == "delivered")
        & interactions["interaction_ts"].between(as_of - pd.Timedelta(days=60), as_of)
    ].groupby("customer_id").size().rename("delivered")
    opened = interactions.loc[
        (interactions["interaction_type"] == "opened")
        & interactions["interaction_ts"].between(as_of - pd.Timedelta(days=60), as_of)
    ].groupby("customer_id").size().rename("opened")

    metrics = pd.concat(
        [event_metrics, login_14, active_days, prior_days, delivered, opened], axis=1
    ).fillna(0)
    metrics["days_since_last_activity"] = (
        as_of - pd.to_datetime(metrics["last_activity"])
    ).dt.days
    metrics["campaign_open_rate_last_60_days"] = (
        metrics["opened"] / metrics["delivered"].replace(0, pd.NA)
    ).fillna(0.0)
    metrics = metrics.drop(columns=["last_activity", "delivered", "opened"])

    result = customers.join(metrics, on="customer_id")
    count_columns = [
        "logins_last_30_days",
        "logins_last_14_days",
        "support_tickets_last_90_days",
        "active_days_last_14_days",
        "active_days_prior_14_days",
    ]
    result[count_columns] = result[count_columns].fillna(0).astype(int)
    result["days_since_last_activity"] = result["days_since_last_activity"].fillna(999).astype(int)
    result["campaign_open_rate_last_60_days"] = result["campaign_open_rate_last_60_days"].fillna(0.0)
    result["is_eligible"] = result["subscription_status"].eq("active") & result["customer_id"].isin(eligible_consent)
    result["is_high_value_engaged"] = (
        result["is_eligible"]
        & result["subscription_plan"].eq("premium")
        & result["logins_last_14_days"].ge(5)
        & result["campaign_open_rate_last_60_days"].gt(0.30)
    )
    result["is_at_risk_dormant"] = result["is_eligible"] & result["days_since_last_activity"].between(30, 60)
    result["is_upgrade_candidate"] = (
        result["is_eligible"]
        & result["subscription_plan"].isin(["basic", "standard"])
        & result["logins_last_30_days"].ge(10)
        & result["support_tickets_last_90_days"].eq(0)
    )
    result["is_winback_target"] = (
        result["subscription_status"].eq("churned")
        & result["status_change_date"].ge(as_of.normalize() - pd.Timedelta(days=90))
        & result["campaign_open_rate_last_60_days"].gt(0.20)
    )
    result["is_engagement_declining"] = (
        result["is_eligible"]
        & result["active_days_prior_14_days"].gt(0)
        & result["active_days_last_14_days"].lt(result["active_days_prior_14_days"] * 0.5)
    )
    result["as_of_timestamp"] = as_of
    return result, as_of


@st.cache_data
def load_segments() -> tuple[pd.DataFrame, pd.Timestamp, str]:
    if EXPORT_PATH.exists():
        data = pd.read_csv(EXPORT_PATH, parse_dates=["as_of_timestamp"], low_memory=False)
        as_of = pd.to_datetime(data["as_of_timestamp"].max())
        return data, as_of, "dbt export"
    data, as_of = load_seed_segments()
    return data, as_of, "local seed preview"


def main() -> None:
    st.set_page_config(page_title="Audience Studio", page_icon="A", layout="wide")
    st.markdown(
        """
        <style>
        .block-container { max-width: 1440px; padding-top: 2rem; }
        .hero { padding: 1.3rem 1.5rem; border-radius: 18px; background: linear-gradient(120deg, #102a43, #176b87); color: white; margin-bottom: 1.3rem; }
        .hero h1 { margin: 0; font-size: 2.2rem; letter-spacing: 0; }
        .hero p { margin: .35rem 0 0; color: #d8f3f0; }
        [data-testid="stMetric"] { background: #f4f7f9; border: 1px solid #d9e2ec; padding: .8rem; border-radius: 12px; }
        </style>
        """,
        unsafe_allow_html=True,
    )

    data, as_of, source_label = load_segments()
    data = data[data["is_eligible"].fillna(False)].copy()

    st.markdown(
        f'<div class="hero"><h1>Audience Studio</h1><p>Activation-ready customer segments · {source_label} · data through {as_of:%d %b %Y}</p></div>',
        unsafe_allow_html=True,
    )

    with st.sidebar:
        st.subheader("Audience filters")
        selected_segment = st.selectbox("Segment", ["All eligible customers", *SEGMENT_COLUMNS.keys()])
        plans = sorted(data["subscription_plan"].dropna().unique())
        selected_plans = st.multiselect("Subscription plan", plans, default=plans)
        statuses = sorted(data["subscription_status"].dropna().unique())
        selected_statuses = st.multiselect("Status", statuses, default=statuses)
        min_open_rate = st.slider("Minimum open rate", 0.0, 1.0, 0.0, 0.05)

    filtered = data[
        data["subscription_plan"].isin(selected_plans)
        & data["subscription_status"].isin(selected_statuses)
        & data["campaign_open_rate_last_60_days"].ge(min_open_rate)
    ]
    if selected_segment != "All eligible customers":
        filtered = filtered[filtered[SEGMENT_COLUMNS[selected_segment]].fillna(False)]

    metrics = st.columns(4)
    metrics[0].metric("Audience size", f"{len(filtered):,}")
    metrics[1].metric("Avg. open rate", f"{filtered['campaign_open_rate_last_60_days'].mean():.1%}" if len(filtered) else "0.0%")
    metrics[2].metric("Premium share", f"{filtered['subscription_plan'].eq('premium').mean():.1%}" if len(filtered) else "0.0%")
    metrics[3].metric("Active days", f"{filtered['active_days_last_14_days'].mean():.1f}" if len(filtered) else "0.0")

    st.subheader("Segment reach")
    segment_counts = pd.DataFrame(
        {label: [int(data[column].fillna(False).sum())] for label, column in SEGMENT_COLUMNS.items()}
    ).T.rename(columns={0: "customers"})
    st.bar_chart(segment_counts, horizontal=True, height=230)

    st.subheader("Audience records")
    display_columns = [
        "customer_id", "email", "subscription_plan", "subscription_status",
        "campaign_open_rate_last_60_days", "logins_last_30_days",
        "active_days_last_14_days", *SEGMENT_COLUMNS.values(),
    ]
    display_columns = [column for column in display_columns if column in filtered.columns]
    st.dataframe(filtered[display_columns], use_container_width=True, hide_index=True)
    st.download_button(
        "Download filtered audience",
        filtered.to_csv(index=False).encode("utf-8"),
        file_name="audience_export.csv",
        mime="text/csv",
    )


if __name__ == "__main__":
    main()
