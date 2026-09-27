{% macro get_as_of_timestamp() %}
    TO_TIMESTAMP_NTZ('{{ var("as_of_date", "2025-06-30") }}')
{% endmacro %}
