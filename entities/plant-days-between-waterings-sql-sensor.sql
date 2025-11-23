-- Simple query to calculate average watering intervals
-- Change the parameters in the WHERE clauses below as needed

SELECT 
  COUNT(*) AS total_intervals,
  ROUND(AVG(interval_days), 2) AS avg_days,
  ROUND(MIN(interval_days), 2) AS min_interval,
  ROUND(MAX(interval_days), 2) AS max_interval,
  MIN(water_date) AS first_watering,
  MAX(water_date) AS last_watering
FROM (
  -- Calculate intervals from detected waterings
  SELECT 
    water_date,
    ROUND((julianday(water_time) - julianday(LAG(water_time) OVER (ORDER BY water_timestamp))), 2) AS interval_days
  FROM (
    -- Get one watering per day from significant moisture increases
    SELECT 
      date(datetime(created_ts, 'unixepoch')) as water_date,
      datetime(created_ts, 'unixepoch') as water_time,
      created_ts as water_timestamp,
      ROW_NUMBER() OVER (PARTITION BY date(datetime(created_ts, 'unixepoch')) ORDER BY created_ts DESC) as day_rank
    FROM (
      -- Find moisture increases (watering events)
      SELECT 
        st.created_ts,
        st.mean,
        LAG(st.mean) OVER (ORDER BY st.created_ts) as prev_mean
      FROM statistics st
      JOIN statistics_meta sm ON sm.id = st.metadata_id
      WHERE sm.statistic_id = 'sensor.{plant}_soil_moisture'  -- CHANGE THIS: Your sensor name
        AND st.created_ts >= strftime('%s', 'yyyy-mm-dd')    -- CHANGE THIS: Start date  
        AND st.created_ts <= strftime('%s', 'yyyy-mm-dd')    -- CHANGE THIS: End date (before self-watering)
        AND st.mean IS NOT NULL
      ORDER BY st.created_ts
    ) moisture_data
    WHERE (mean - COALESCE(prev_mean, 0)) > 10  -- CHANGE THIS: Moisture increase threshold
  ) daily_waterings
  WHERE day_rank = 1  -- Last watering per day
) intervals
WHERE interval_days IS NOT NULL 

  AND interval_days >= 2;  -- CHANGE THIS: Minimum days between waterings
