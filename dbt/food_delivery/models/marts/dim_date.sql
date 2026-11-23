-- dim_date: one row per calendar day, 2022-01-01 to 2026-12-31 (1826 rows)
with spine as (
    select date_day
    from unnest(generate_date_array('2022-01-01', '2026-12-31', interval 1 day)) as date_day
)

select
    date_day,
    extract(year from date_day)    as year,
    extract(month from date_day)   as month,
    format_date('%Y-%m', date_day) as year_month,
    format_date('%A', date_day)    as day_name,
    extract(dayofweek from date_day) in (1, 7) as is_weekend  -- 1 = Sunday, 7 = Saturday
from spine  
