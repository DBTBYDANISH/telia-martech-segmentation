# Audience Studio

A small Streamlit application for marketing users who need to explore dbt audience segments without direct Snowflake access.

## Local preview

From the `martech_audience_segmentation` directory:

```bash
python -m pip install -r app/requirements.txt
streamlit run app/app.py
```

The app reads the seed CSV files and calculates an audience preview using `AS_OF_DATE=2025-06-30` when no export exists. Override the date before starting Streamlit:

```bash
AS_OF_DATE=2025-05-31 streamlit run app/app.py
```

## Using a dbt export

For a production-like workflow, export `fct_customer_segments_date` to:

```text
app/data/fct_customer_segments_date.csv
```

The app will automatically use that file instead of recalculating from the seed data.

Do not place Snowflake credentials in the app or browser. A deployed version should use a read-only backend service account or a scheduled, access-controlled export.
