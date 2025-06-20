SELECT days_elapsed
FROM (
  SELECT 
    s.last_updated, 
    s.state, 
    s.previous_state, 
    (CAST(s.state AS FLOAT) - CAST(s.previous_state AS FLOAT)) AS delta,
    ROUND((julianday('now') - julianday(s.last_updated)), 2) AS days_elapsed
  FROM (
SELECT s.state, datetime(last_updated_ts, 'unixepoch') as last_updated,
         LAG(s.state) OVER (ORDER BY s.last_updated_ts) AS previous_state
  FROM states s
  JOIN states_meta sm ON sm.metadata_id = s.metadata_id
  WHERE sm.entity_id = 'sensor.{plant}_soil_moisture' --replace here with the corresponding sensor for the plant
    AND s.state NOT IN ('unknown', 'unavailable')
) s
WHERE  (CAST(s.state AS FLOAT) - CAST(s.previous_state AS FLOAT)) > 10
ORDER BY s.last_updated DESC
LIMIT 1)
