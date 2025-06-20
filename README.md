## 🌿 Smart Indoor Plant Dashboard with Home Assistant

A few years ago, I had two beautiful Calatheas. I didn’t know then that they were the divas of the plant world — dramatic, demanding, and quick to decline if you get things wrong. Without any feedback from them (besides looking a bit sad), they eventually died. 😔

Fast forward to six months ago: I moved into a new apartment, started smartifying my home with Home Assistant, and decided to bring plants back into my life — including Calatheas.

This time, though, I was ready.

I'm a Data Analytics consultant by trade, and I believe: **🧠 You can’t care for what you don’t understand — and data makes all the difference.**

So I built a dashboard that tracks over 30 plants using Xiaomi Miflora sensors, helper entities, SQL sensors, and a whole bunch of templating logic. It’s not about automating care — I still water and fertilize my plants manually — but this system keeps me informed, reminds me when to check them, and has dramatically improved how I care for them.

## 🗺️ What This Project Does

This project helps you track plant care in a smart, data-driven way.\
It doesn’t automate the watering or fertilizing — instead, it gives you helpful, dynamic insight into each plant’s status through:

- Real-time moisture and conductivity readings
- Estimates of the last watering based on moisture level changes
- Manual tracking of last fertilization
- Thresholds per plant family to flag when attention is needed
- Color-coded, reusable dashboard cards for each plant
- Morning notifications with summaries of any problems

It’s all powered by Home Assistant, with integrations and sensors tied together through SQL, Jinja, and a ton of helpers.

The result is a dashboard that’s **data-rich but practical** — you stay in control while the system quietly keeps track of everything.

## 🔧 Tools & Integrations Used

| Component                                                                                                           | What it's used for                                                        |
| ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [**Xiaomi Miflora**](https://smarthomescene.com/reviews/xiaomi-miflora-plant-sensor-tuya-version-hhccjcy10-review/) | Soil moisture and nutrient (conductivity) readings                        |
| **ESP32 + [OpenMQTTGateway](https://docs.openmqttgateway.com/)**                                                    | BLE proxy to connect Miflora sensors to Home Assistant                    |
| [**Plant Monitor**](https://github.com/Olen/homeassistant-plant)                                                    | Core plant-tracking logic, threshold support, Open Plant Book integration |
| [**Decluttering-card**](https://github.com/custom-cards/decluttering-card)                                          | For reusable dashboard card templates                                     |
| [**Card-mod**](https://github.com/thomasloven/lovelace-card-mod)                                                    | For advanced visual styling of dashboard cards                            |
| [**SQL Integration**](https://www.home-assistant.io/integrations/sql/)                                              | To detect watering events based on moisture spikes                        |
| [**Flower Card**](https://github.com/Olen/homeassistant-plant#flower-card)                                          | To display plant bars (moisture, conductivity)                            |
| [**Auto-entities**](https://github.com/thomasloven/lovelace-auto-entities)                                          | To help with the summary cards in the dashboard                           |
| [**Mushroom**](https://github.com/piitaya/lovelace-mushroom)                                                        | To display the chips under each flower card                               |
| **Helper Entities (number, datetime)**                                                                              | For storing thresholds and last fertilization times                       |

## 🪴 How Plant Status is Tracked

Each plant has:

- A **Miflora sensor** providing soil moisture and conductivity
- A **dashboard card** showing real-time status, color-coded for warnings
- A **template sensor** showing how many days have passed since the last watering
- A **manual fertilization tracker** using a datetime helper
- Thresholds (warning + alert) based on the plant’s botanical family

Now each component in more detail:

## 💧 Detecting Watering Automatically

We can infer when the plant was watered if the **soil moisture suddenly rises**, as it likely means watering just happened.

To detect this, I use a **SQL sensor** that queries Home Assistant’s internal database for the most recent spike in soil moisture for each plant.

### What the SQL sensor does:

1. **Gets the historical state data** for the plant’s moisture sensor.
2. **Compares each value** with the one before it.
3. **Finds the most recent jump** (greater than 10%, this works fine for my use case).
4. **Returns how many days ago** that happened.

This lets me estimate the last watering — no manual logging needed.

Here’s an example SQL sensor for a plant named "`maia"`:

```sql
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
    WHERE sm.entity_id = 'sensor.maia_soil_moisture'
      AND s.state NOT IN ('unknown', 'unavailable')
  ) s
  WHERE (CAST(s.state AS FLOAT) - CAST(s.previous_state AS FLOAT)) > 10
  ORDER BY s.last_updated DESC
  LIMIT 1
)
```

Each plant gets its own version of this query.\
These sensors return a **float value**, like `2.33`, which means 2 days and 8 hours ago.

> The SQL Integration has a bug when you return a date/datetime, and the resulting sensor can only be used as a string and not as an actual datetime. Because I was planning to use this sensor to track when each plant was last watered, I'm returning a number which represents the number of days that have passed instead of the date. I will calculate the actual date in the dashboard. They are still working on a fix for this.

## 🧪 Tracking Fertilization Manually

I decided to track fertilization manually just to keep it simple. I really just want to know the last time I fertilized each plant, not a full history of fertilization. I do this with:

- `input_datetime.{plant_name}_last_fertilizing` helpers (one per plant)
- A dashboard chip to:
  - View how long it’s been since fertilizing
  - Open a calendar to change the date
  - Mark the plant as fertilized with a one-click script

These values are used in the dashboard and in daily alerts.

## 🌳 Grouping Plants by Botanical Family

Each plant is assigned a **botanical family** (e.g. `Marantaceae`, `Strelitziaceae`).

I store this in the `species_original` attribute of the plant device. While the Plant Monitor uses this field for Open Plant Book syncing, I repurpose it for my own internal logic.

Each family gets its own [threshold helpers](./screenshots/plant-helpers-all-family-numbers.jpg):

- `input_number.{family}_watering_warning_days`
- `input_number.{family}_watering_alert_days`
- `input_number.{family}_fertilizing_warning_days`
- `input_number.{family}_fertilizing_alert_days`

This lets me:

- Apply consistent thresholds to all plants in the same family
- Adjust parameters based on care needs (e.g. Calatheas vs. Dracaenas)

## 🧱 Reusable Dashboard Card

I use [decluttering-card](https://github.com/custom-cards/decluttering-card) to define a reusable plant card template.

### What it includes:

- A flower card for real-time moisture and conductivity bars
- A “last watered” chip:
  - Calculates days + hours since watering (based on SQL sensor)
  - Colors the chip green, orange, or red based on thresholds
  - Shows a tooltip with the exact date and time
- A “last fertilized” chip:
  - Uses the manual datetime
  - Tap: open datetime
  - Hold: mark plant as fertilized via script
  - Color-coded like watering chip

You can find the full code [here](./lovelace/plant_card_compact.yaml), and I’ve added comments inline for clarity.

![](https://holocron.so/uploads/fce3d6a3-1000000514.jpg.jpeg)

## 📢 Dashboard Summary Alerts

The dashboard also includes a **summary section** showing alerts across all plants:

- **Low Soil Moisture**
- **Low Nutrients** (recently fertilized, moist soil, but poor conductivity)
- **Watering Warning** (days since watering exceed family threshold)
- **Watering Alert** (critical days passed without watering)

These use `auto-entities` and Jinja filters to show only relevant plants.\
Code is in [lovelace/summary_cards.yaml](./lovelace/summary_cards.yaml)

![](https://holocron.so/uploads/68bc7daa-1000000505.jpg.jpeg)

## 📬 Morning Notification

Every morning, I receive a **digest of care reminders**:

- Plants that are too dry
- Plants recently fertilized but showing poor conductivity
- Plants that might be overdue for watering

![](https://holocron.so/uploads/4a31e9ba-1000000515.jpg.jpeg)

> ⚠️ **Note:**\
> This logic is currently hardcoded per plant family. I’m working on updating it to pull the same thresholds used in the dashboard from helper entities, and will update the repo when that’s ready.

## ➕ Adding a New Plant

1. Add plant in Plant Monitor.
2. Set the `species_original` attribute to the plant’s family.
3. If it’s a new family, create the 4 helper `input_number` thresholds.
4. Add an `input_datetime.{plant}_last_fertilizing` helper.
5. Create the SQL sensor to detect watering.
6. Add the plant to the dashboard using the `decluttering-card` template.

## 📷 Screenshots

Screenshots are available in the `/screenshots` folder.\
You can also see a demo video in [my Reddit post](https://www.reddit.com/r/homeassistant/comments/I3M77Xn8W4/).

## 🤝 Feedback Welcome

This project is based entirely on my own research and tinkering — it’s probably not perfect, and there might be better ways to do parts of it. I’d love to hear from others using similar setups or trying something new.

Feel free to reuse, adapt, or improve anything here — and if you have ideas or improvements, please let me know!