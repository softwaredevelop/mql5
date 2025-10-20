# Session Analysis Professional

## 1. Summary (Introduction)

The Session Analysis Pro is an advanced, multi-faceted analytical tool designed to visualize and analyze price action within specific, user-defined trading sessions. It is particularly useful for traders who focus on the dynamics of the major market opens.

This powerful indicator can simultaneously display and analyze up to **three independent markets** (e.g., NYSE, LSE, TSE), each with its own customizable **Pre-Market, Core, Post-Market, and optional Full Day** sessions.

For each defined session, the indicator can display several key analytical components:

1. **Session Range Box:** A rectangle encompassing the high and low of the session.
2. **Volume Weighted Average Price (VWAP):** The true average price for the session, weighted by volume, rendered using a high-performance, buffer-based drawing method for maximum speed and stability.
3. **Mean Price:** The simple arithmetic average of the selected source prices within the session.
4. **Linear Regression Line:** A statistical trendline showing the "best fit" line for the session's price action.

The indicator is highly customizable and fully supports both **standard** and **Heikin Ashi** data sources for its calculations.

## 2. Calculation Logic

The indicator identifies bars belonging to a specific time window and performs distinct calculations on the data within that session.

1. **Session Range:** Identifies the highest `High` and lowest `Low` within the session's time boundaries and draws a rectangle around them.
2. **Volume Weighted Average Price (VWAP):** Calculates the cumulative, volume-weighted average of the `Typical Price` `(H+L+C)/3`, resetting at the start of each new session. The calculation is performed by a dedicated, optimized engine.
3. **Mean Price:** Calculates the simple arithmetic average of the user-selected `Source Price` for all bars within the session.
4. **Linear Regression Line:** Calculates the "least squares fit" trendline on the user-selected `Source Price`.
    * **Note on Matching Built-in Tools:** The standard MetaTrader `Standard Deviation Channel` object calculates its centerline based on **`PRICE_CLOSE`**. To perfectly match the built-in object's trendline, select `PRICE_CLOSE` as the `Source Price` in the indicator settings. Our indicator's flexibility allows you to analyze regression based on other price types as well.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, robust, and high-performance **hybrid architecture** to provide a smooth, freeze-free user experience.

* **Hybrid Drawing Architecture:** The indicator uses two distinct systems, each optimized for its specific task:
  * **VWAP via Indicator Buffers:** All VWAP calculations are handled by a dedicated `CVWAPCalculator` engine. This engine writes its results directly into MQL5's fastest drawing mechanism: **indicator buffers** (`DRAW_LINE`). We use the **"double buffer" technique** to create clean visual gaps between sessions.
  * **Boxes & Stats via Graphical Objects:** The Session Box, Mean, and Linear Regression lines are drawn using standard graphical objects (`OBJ_RECTANGLE`, `OBJ_TREND`). This is handled by a separate `CSessionAnalyzer` class, providing flexibility for these elements.

* **Unified Heikin Ashi Integration:** When `CANDLE_HEIKIN_ASHI` is selected, the indicator uses a unified approach. Both the `CVWAPCalculator` and the `CSessionAnalyzer` instantiate their respective `_HA` child classes. This ensures that **all visual components**—the VWAP lines, the session range boxes, the Mean, and the Linear Regression lines—are consistently calculated using the smoothed Heikin Ashi data.

* **Robust Multi-Instance Support:** Each instance of the indicator on a chart generates a unique, stable ID for its graphical objects using the `ChartWindowFind()` method. This ID is used as a prefix for all object names, ensuring that multiple copies of the indicator can run on the same chart without any conflicts.

* **Robust Cleanup on Re-initialization:** To prevent "ghost" objects or line fragments after a timeframe change or parameter edit, the indicator employs a strict two-phase cleanup process:
    1. **Object Cleanup:** In `OnInit`, it immediately deletes all graphical objects associated with its unique instance ID from the chart.
    2. **Buffer Cleanup:** At the beginning of every **new bar calculation** in `OnCalculate`, it explicitly clears all 24 VWAP buffers by filling them with `EMPTY_VALUE`.
    This "clean slate" approach guarantees a perfect and stable redraw under all conditions.

* **Efficient "On New Bar" Updates:** All calculations and redraws are executed only **once per bar**, preventing unnecessary CPU load on every tick.

## 4. Parameters

* **Global Settings:**
  * `InpFillBoxes`: Toggles whether the session range boxes are filled or drawn as outlines.
  * `InpVolumeType`: Selects between `Tick Volume` and `Real Volume` for all VWAP calculations.
  * `InpCandleSource`: Selects the candle type (`Standard` or `Heikin Ashi`) for the **VWAP** calculation.
  * `InpSourcePrice`: The source price for the **Mean and Linear Regression** calculations.

* **Market Settings (Market 1, Market 2, Market 3):**
  * `Enable`: A master switch to turn all analysis for that market on or off.
  * **Session Settings (Pre-Market, Core, Post-Market, Full Day):**
    * `Enable`: Turns the analysis for that specific session on or off.
    * `Start / End`: The start and end times for the session in "HH:MM" format, based on the **broker's server time**.
    * `Color`: The color for all graphical elements (box and VWAP line) drawn for that session.
    * `VWAP / Mean / LinReg`: Toggles the visibility of each analytical component for that session.

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
| **Budapest (CEST, UTC+2)**| 12:30–15:30 | 15:30–22:00 | 22:00–02:00 |

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
| **Budapest (CEST, UTC+2)**| 06:00–09:00 | 09:00–17:30 | 17:30–18:15 |

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
| **Frankfurt (CEST)**| 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |
| **UTC** | 06:00–07:00 | 07:00–15:30 | 15:30–18:00 |
| **Nicosia (EEST, UTC+3)** | 09:00–10:00 | 10:00–18:30 | 18:30–21:00 |
| **Budapest (CEST, UTC+2)**| 08:00–09:00 | 09:00–17:30 | 17:30–20:00 |

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
| **Budapest (CEST, UTC+2)**| 23:00–02:00 | 02:00–08:00 | 08:00–11:00 |

---

## 6. Usage and Interpretation

* **Contextual Analysis:** The primary use is to understand the behavior of price during specific, high-volume trading sessions.
* **VWAP as a Benchmark:** The VWAP line is a key level for intraday traders. Price action above the session VWAP is generally considered bullish; price action below is bearish.
* **Mean and Linear Regression:** These lines provide a statistical "fair value" for the session. The slope of the regression line indicates the overall direction and strength of the session's trend.
* **Range Box:** The high and low of the session box become critical support and resistance levels for subsequent trading sessions.
