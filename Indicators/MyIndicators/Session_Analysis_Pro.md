# Session Analysis Pro Suite

## 1. Summary (Introduction)

The Session Analysis Pro Suite is an advanced set of analytical tools designed to visualize and analyze price action within specific, user-defined trading sessions. It is particularly useful for traders who focus on the dynamics of major market opens (e.g., London, New York, Tokyo).

The suite includes two specialized indicators:

1. **`Session_Analysis_Pro` (Multi-Market):** A powerhouse indicator capable of simultaneously analyzing up to **three independent markets** on a single chart. Ideal for global macro traders monitoring cross-market correlations.
2. **`Session_Analysis_Single_Pro` (Single-Market):** A streamlined version focused on a **single market**, designed for focused intraday trading on specific assets.

For each defined session (Pre-Market, Core, Post-Market, Full Day), both indicators can display:

1. **Session Range Box:** A rectangle encompassing the high and low of the session.
2. **Volume Weighted Average Price (VWAP):** The true average price for the session, weighted by volume.
3. **Mean Price:** The simple arithmetic average of the session's prices.
4. **Linear Regression Line:** A statistical trendline showing the "best fit" for the session's price action.

Both indicators fully support **standard** and **Heikin Ashi** data sources.

## 2. Calculation Logic

The indicators identify bars belonging to specific time windows and perform distinct calculations on the data within those sessions.

1. **Session Range:** Identifies the highest `High` and lowest `Low` within the session boundaries.
2. **VWAP:** Calculates the cumulative, volume-weighted average of the `Typical Price` `(H+L+C)/3`, resetting at the start of each new session.
3. **Mean Price:** Calculates the simple arithmetic average of the user-selected `Source Price`.
4. **Linear Regression Line:** Calculates the "least squares fit" trendline.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, robust, and high-performance **hybrid architecture**.

* **Unified Calculation Engines:** Both indicators share the exact same core logic:
  * **`Session_Analysis_Calculator.mqh`:** Handles the session timing, box drawing, Mean, and Linear Regression calculations.
  * **`VWAP_Calculator.mqh`:** A dedicated engine for high-precision VWAP calculations.
    This ensures 100% consistency between the Single and Multi versions.

* **Hybrid Drawing Architecture:**
  * **VWAP via Indicator Buffers:** VWAP lines are drawn using high-performance indicator buffers (`DRAW_LINE`) for maximum speed.
  * **Boxes & Stats via Graphical Objects:** Session boxes and trendlines are drawn using standard graphical objects (`OBJ_RECTANGLE`, `OBJ_TREND`), allowing for complex visual overlays.

* **Unified Heikin Ashi Integration:** When `CANDLE_HEIKIN_ASHI` is selected, the indicators automatically switch to using smoothed Heikin Ashi data for **all** calculations (VWAP, Mean, LinReg, and Box High/Low).

* **History Optimization:** The `Max History Days` parameter limits the drawing of objects and buffers to the recent past, keeping chart loading times fast and template files small.

## 4. Parameters

### Common Parameters (Both Versions)

* **Global Settings:**
  * `InpFillBoxes`: Toggles filled/outline boxes.
  * `InpMaxHistoryDays`: Limits the history depth (Default: `5`).
  * `InpVolumeType`: Selects `Tick Volume` or `Real Volume` for VWAP.
  * `InpCandleSource`: Selects `Standard` or `Heikin Ashi` candles.
  * `InpSourcePrice`: Source price for Mean/LinReg calculations.

### Session Settings

* **Pre-Market / Core / Post-Market / Full Day:**
  * `Enable`: Turns the session analysis on/off.
  * `Start / End`: Session times (HH:MM) based on **broker server time**.
  * `Color`: Color for the session's visual elements.
  * `Show VWAP / Mean / LinReg`: Toggles individual components.

### Multi-Market Specific (`Session_Analysis_Pro`)

* **Market 1 / 2 / 3:** Master switches to enable/disable entire market configurations.

## 5. Trading Session Times Reference

This section provides a detailed reference for the trading hours of major global exchanges to help configure the indicator.

**IMPORTANT:** All times are listed in various time zones for comparison. You must use the times that correspond to your **broker's server time** in the indicator settings. Be aware that you may need to adjust these times twice a year due to Daylight Saving Time (DST) changes.

---

### **New York Stock Exchange (NYSE)**

* **Time Zone**: Eastern Time (ET)
* **DST (USA) in 2025**: Starts March 9, Ends November 2.

#### Summer (EDT, UTC-4)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **New York (EDT)** | 06:30–09:30 | 09:30–16:00 | 16:00–20:00 |
| **UTC** | 10:30–13:30 | 13:30–20:00 | 20:00–00:00 |
| **Nicosia (EEST, UTC+3)** | 13:30–16:30 | 16:30–23:00 | 23:00–03:00 |
| **Budapest (CEST, UTC+2)** | 12:30–15:30 | 15:30–22:00 | 22:00–02:00 |

#### Winter (EST, UTC-5)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **New York (EST)** | 06:30–09:30 | 09:30–16:00 | 16:00–20:00 |
| **UTC** | 11:30–14:30 | 14:30–21:00 | 21:00–01:00 |
| **Nicosia (EET, UTC+2)** | 13:30–16:30 | 16:30–23:00 | 23:00–03:00 |
| **Budapest (CET, UTC+1)** | 12:30–15:30 | 15:30–22:00 | 22:00–02:00 |

---

### **London Stock Exchange (LSE)**

* **Time Zone**: GMT / BST
* **DST (Europe) in 2025**: Starts March 30, Ends October 26.

#### Summer (BST, UTC+1)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **London (BST)** | 05:00–08:00 | 08:00–16:30 | 16:30–17:15 |
| **UTC** | 04:00–07:00 | 07:00–15:30 | 15:30–16:15 |
| **Nicosia (EEST, UTC+3)** | 07:00–10:00 | 10:00–18:30 | 18:30–19:15 |
| **Budapest (CEST, UTC+2)** | 06:00–09:00 | 09:00–17:30 | 17:30–18:15 |

#### Winter (GMT, UTC+0)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **London (GMT)** | 05:00–08:00 | 08:00–16:30 | 16:30–17:15 |
| **UTC** | 05:00–08:00 | 08:00–16:30 | 16:30–17:15 |
| **Nicosia (EET, UTC+2)** | 07:00–10:00 | 10:00–18:30 | 18:30–19:15 |
| **Budapest (CET, UTC+1)** | 06:00–09:00 | 09:00–17:30 | 17:30–18:15 |

---

### **Frankfurt Stock Exchange (Xetra)**

* **Time Zone**: CET / CEST
* **DST (Europe) in 2025**: Starts March 30, Ends October 26.

#### Summer (CEST, UTC+2)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Frankfurt (CEST)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |
| **UTC** | 06:00–07:00 | 07:00–15:30 | 15:30–18:00 |
| **Nicosia (EEST, UTC+3)** | 09:00–10:00 | 10:00–18:30 | 18:30–21:00 |
| **Budapest (CEST, UTC+2)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |

#### Winter (CET, UTC+1)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Frankfurt (CET)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |
| **UTC** | 07:00–08:00 | 08:00–16:30 | 16:30–19:00 |
| **Nicosia (EET, UTC+2)** | 09:00–10:00 | 10:00–18:30 | 18:30–21:00 |
| **Budapest (CET, UTC+1)** | 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |

---

### **Tokyo Stock Exchange (TSE)**

* **Time Zone**: Japan Standard Time (JST), UTC+9 all year.
* **No Daylight Saving Time.**

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Tokyo (JST)** | 08:00–09:00 | 09:00–11:30 | 12:30–15:30 |
| **UTC** | 23:00–00:00 | 00:00–02:30 | 03:30–06:30 |
| **Nicosia** | 01:00–02:00 (W) / 02:00–03:00 (S) | 02:00–04:30 (W) / 03:00–05:30 (S) | 05:30–08:30 (W) / 06:30–09:30 (S) |
| **Budapest** | 00:00–01:00 (W) / 01:00–02:00 (S) | 01:00–03:30 (W) / 02:00–04:30 (S) | 04:30–07:30 (W) / 05:30–08:30 (S) |

---

### **Sydney Stock Exchange (ASX)**

* **Time Zone**: AEST / AEDT
* **DST (Australia) in 2025**: Starts October 5, Ends April 6.

#### Summer (AEDT, UTC+11) (Oct - Apr)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Sydney (AEDT)** | 07:00–10:00 | 10:00–16:00 | 16:00–19:00 |
| **UTC** | 20:00–23:00 | 23:00–05:00 | 05:00–08:00 |
| **Nicosia (EET, UTC+2)** | 22:00–01:00 | 01:00–07:00 | 07:00–10:00 |
| **Budapest (CET, UTC+1)** | 21:00–00:00 | 00:00–06:00 | 06:00–09:00 |

#### Winter (AEST, UTC+10) (Apr - Oct)

| Time Zone | Pre-Market | Core Trading | Post-Market |
| :--- | :--- | :--- | :--- |
| **Sydney (AEST)** | 07:00–10:00 | 10:00–16:00 | 16:00–19:00 |
| **UTC** | 21:00–00:00 | 00:00–06:00 | 06:00–09:00 |
| **Nicosia (EEST, UTC+3)** | 00:00–03:00 | 03:00–09:00 | 09:00–12:00 |
| **Budapest (CEST, UTC+2)** | 23:00–02:00 | 02:00–08:00 | 08:00–11:00 |

---

## 6. Usage and Interpretation

* **Contextual Analysis:** Understand price behavior during specific, high-volume sessions.
* **VWAP as Benchmark:** Price above session VWAP is bullish; below is bearish.
* **Fair Value:** The Mean and Linear Regression lines provide a statistical "fair value" for the session.
* **Support/Resistance:** The high and low of the session box act as critical levels for subsequent sessions.
