SELECT days_elapsed
FROM (
  SELECT 
    s.created_ts,
    datetime(s.created_ts, 'unixepoch') as created_datetime, 
    s.mean, 
    s.previous_mean, 
    (s.mean - s.previous_mean) AS delta,
    ROUND((julianday('now') - julianday(datetime(s.created_ts, 'unixepoch'))), 2) AS days_elapsed
  FROM (
    SELECT 
      st.mean, 
      st.created_ts,
      LAG(st.mean) OVER (ORDER BY st.created_ts) AS previous_mean
    FROM statistics st
    JOIN statistics_meta sm ON sm.id = st.metadata_id
    WHERE sm.statistic_id = 'sensor.{plant}_soil_moisture' --replace here with the corresponding sensor for the plant
      AND st.mean IS NOT NULL
  ) s
  WHERE (s.mean - s.previous_mean) > 5
  ORDER BY s.created_ts DESC
  LIMIT 1
)
