## Martech Audience Segmentation

A dbt and Snowflake project that builds reusable, tested customer audience segments for CRM and marketing activation.

## Architecture

```text
seeds/                 Raw CSV inputs
00_sources/            dbt source declarations
models/staging/        Cleaned and typed source models
models/features/       Intermediate customer metrics and feature marts
models/shared/         Shared reporting views for all feature outputs
tests/                 Generic and singular data-quality tests
app/                   Streamlit audience visualization app (Placeholder)
google data studio     Virtualization (https://datastudio.google.com/reporting/fbc95203-974a-4909-bb7e-0d53d54118f7)
```

The main model layers are:

- `stg_*`: normalize identifiers, casing, dates, timestamps, and source formats.
- `int_customer_metrics`: calculate rolling customer activity metrics using the system date.
- `int_customer_metrics_date`: calculate the same metrics relative to the configured `as_of_date` variable.
- `fct_customer_segments`: standard customer segmentation mart.
- `fct_customer_segments_date`: configured-date segmentation mart for the historical dataset.

The shared layer exposes all four feature outputs as views:

- `shared_int_customer_metrics`
- `shared_int_customer_metrics_date`
- `shared_fct_customer_segments`
- `shared_fct_customer_segments_date`

The feature models are materialized in the `features` schema. The shared models read them with `ref()` and are materialized as views in the `shared` schema.

## Database Structure

| Database schema | Purpose |
|---|---|
| `MARTECH_DB.STAGING` | Landing area for source data files. Raw data is loaded here before further processing. |
| `MARTECH_DB.FEATURES` | Contains data product features derived from the source data. |
| `MARTECH_DB.SHARED` | Contains shared models for business users and downstream consumers. |

The segment flags are:

- `is_high_value_engaged`
- `is_at_risk_dormant`
- `is_upgrade_candidate`
- `is_winback_target`
- `is_engagement_declining`

## Requirements

- Python 3.12 or later
- dbt Core with the Snowflake adapter
- Snowflake account and a configured dbt profile

Create a profile named `martech_audience_segmentation` in your dbt `profiles.yml`. 

## Run dbt

Run commands from this directory:

```bash
dbt debug
dbt seed
dbt build
```

Run the configured-date reporting models only:

```bash
dbt build --select int_customer_metrics_date fct_customer_segments_date
```

Change the historical calculation date:

```bash
dbt build --select int_customer_metrics_date fct_customer_segments_date --vars '{as_of_date: "2025-06-30"}'
```

Build all shared reporting views:

```bash
dbt build --select shared_int_customer_metrics shared_int_customer_metrics_date shared_fct_customer_segments shared_fct_customer_segments_date
```

Run source freshness checks:

```bash
dbt source freshness
```

The source freshness rules are defined in `00_sources/sources.yml`. The synthetic CSV files are historical, so they will report as stale until current data is loaded.

## Data quality

The project includes:

- Uniqueness and not-null tests for model grains and identifiers.
- Relationship tests for events, campaign interactions, consent customers, and purpose codes.
- Accepted-value tests for plans, statuses, event types, channels, interaction stages, and legal grounds.
- Business-logic tests for segment predicates.
- Metric validity tests for counts, active-day ranges, and campaign open rates.

Run all tests with:

```bash
dbt test
```

## Google Data Studio

View the audience segmentation report in Google Data Studio:

[Open the visualization report](https://datastudio.google.com/reporting/fbc95203-974a-4909-bb7e-0d53d54118f7)


## Audience Studio app

The Streamlit app lets marketing users explore eligible audiences without direct Snowflake access. It supports segment, plan, status, and open-rate filters, summary metrics, audience tables, and CSV downloads.

Install and start it from this directory:

```bash
python -m pip install -r app/requirements.txt
streamlit run app/app.py
```

Open `http://localhost:8501` in a browser.

The app reads the seed CSV files and calculates a local date-based preview when no export is present. For a reporting deployment, place a controlled export of `fct_customer_segments_date` at:

```text
app/data/fct_customer_segments_date.csv
```

Never put Snowflake credentials in browser code. A production deployment should use a read-only backend service account or a scheduled, access-controlled export.
