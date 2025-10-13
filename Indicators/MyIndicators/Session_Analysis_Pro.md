# Session Analysis Professional

## 1. Summary (Introduction)

The Session Analysis Pro is an advanced, multi-faceted analytical tool designed to visualize and analyze price action within specific, user-defined trading sessions. It is particularly useful for traders who focus on the dynamics of the major market opens (e.g., London, New York).

The indicator is plotted directly on the price chart and can display up to four key analytical components for each session:

1. **Session Range Box:** A rectangle encompassing the high and low of the session.
2. **Volume Weighted Average Price (VWAP):** The true average price for the session, weighted by volume.
3. **Mean Price:** The simple arithmetic average of the selected source prices within the session.
4. **Linear Regression Line:** A statistical trendline showing the "best fit" line for the session's price action.

The indicator is highly customizable, allowing the user to define three separate sessions (e.g., Pre-Market, Core, Post-Market) and toggle the visibility of each analytical component. It fully supports both **standard** and **Heikin Ashi** data sources for all its calculations.

## 2. Calculation Logic

The indicator identifies bars belonging to a specific time window and performs four distinct calculations on the data within that session.

1. **Session Range:** Identifies the highest `High` and lowest `Low` within the session's time boundaries and draws a rectangle around them.
2. **Volume Weighted Average Price (VWAP):** Calculates the cumulative, volume-weighted average of the `Typical Price` `(H+L+C)/3`, resetting at the start of each new session.
3. **Mean Price:** Calculates the simple arithmetic average of the user-selected `Source Price` for all bars within the session.
4. **Linear Regression Line:** Calculates the "least squares fit" trendline on the user-selected `Source Price` for all bars within the session.

## 3. MQL5 Implementation Details

* **Modular, Object-Oriented Design:** The entire logic is encapsulated within a `CSessionAnalyzer` class. The main indicator file instantiates three separate objects of this class, one for each user-defined session (Pre-Market, Core, Post-Market).
* **Heikin Ashi Integration:** An inherited `CSessionAnalyzer_HA` class allows all calculations (VWAP, Mean, and LinReg) to be performed seamlessly on smoothed Heikin Ashi data.
* **Efficient "On New Bar" Updates:** The entire complex calculation and object redrawing process is only performed **once per bar**, preventing unnecessary CPU load.
* **Robust Time Handling:** The indicator correctly identifies session boundaries regardless of the chart's timeframe and properly handles overnight sessions.
* **Graphical Objects:** All visualizations are drawn using `OBJ_RECTANGLE` and `OBJ_TREND` objects for maximum flexibility.

## 4. Parameters

* **Display Settings:**
  * `InpFillBoxes`: Toggles whether the session range boxes are filled or drawn as outlines.
  * `InpVolumeType`: Selects between `Tick Volume` and `Real Volume` for the VWAP calculation.
  * `InpSourcePrice`: The source price for the Mean and Linear Regression calculations. This unified dropdown allows selection from all standard and Heikin Ashi price types.
* **Session Settings (Pre-Market, Core, Post-Market):**
  * `Enable`: Turns the analysis for that specific session on or off.
  * `Start / End`: The start and end times for the session in "HH:MM" format, based on the **broker's server time**.
  * `Color`: The color for all graphical objects drawn for that session.
  * `VWAP / Mean / LinReg`: Toggles the visibility of each analytical line for that session.

## 5. Recommended Session Times

The following table provides recommended `Pre-Market`, `Core Trading`, and `Post-Market` times for the major global sessions, focusing on periods of highest liquidity and activity relevant to retail traders.

**IMPORTANT:** All times are listed in **UTC/GMT**. You must convert these times to your broker's server time when configuring the indicator's input parameters. Be aware that you may need to adjust these times twice a year due to Daylight Saving Time (DST) changes.

| Market Session | Pre-Market (UTC) | Core Trading (UTC) | Post-Market (UTC) | Key Characteristics |
| :--- | :--- | :--- | :--- | :--- |
| **Asia (Tokyo/Sydney)** | 22:00 - 23:00 | **23:00 - 07:00** | 07:00 - 08:00 | Lower volatility. Best for JPY, AUD, NZD pairs. |
| **Europe (Frankfurt)** | 06:00 - 07:00 | **07:00 - 16:00** | 16:00 - 17:30 | High liquidity begins. Catches the Frankfurt open. |
| **Europe (London)** | 07:00 - 08:00 | **08:00 - 16:30** | 16:30 - 17:30 | Highest liquidity session. Overlaps with Frankfurt. |
| **America (New York)** | 12:00 - 13:30 | **13:30 - 20:00** | 20:00 - 21:00 | High liquidity, especially during the London overlap. |

### **Alternative London Pre-Market Timing**

For traders who wish to capture the very beginning of European market activity, including the Frankfurt open, an earlier start for the London Pre-Market session is recommended:

* **Early London Pre-Market:** `06:00 - 08:00 UTC`

## 6. Usage and Interpretation

* **Contextual Analysis:** The primary use is to understand the behavior of price during specific, high-volume trading sessions.
* **VWAP as a Benchmark:** The VWAP line is a key level for intraday traders. Price action above the session VWAP is generally considered bullish; price action below is bearish.
* **Mean and Linear Regression:** These lines provide a statistical "fair value" for the session. The slope of the regression line indicates the overall direction and strength of the session's trend.
* **Range Box:** The high and low of the session box become critical support and resistance levels for subsequent trading sessions.
