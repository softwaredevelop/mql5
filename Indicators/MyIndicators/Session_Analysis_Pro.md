# Session Analysis Pro

## 1. Summary (Introduction)

The Session Analysis Pro is an advanced, multi-faceted analytical tool designed to visualize and analyze price action within specific, user-defined trading sessions. It is particularly useful for traders who focus on the dynamics of the major market opens (e.g., London, New York).

The indicator is plotted directly on the price chart and can display up to four key analytical components for each session:

1. **Session Range Box:** A rectangle encompassing the high and low of the session.
2. **Volume Weighted Average Price (VWAP):** The true average price for the session, weighted by volume.
3. **Mean Price:** The simple arithmetic average of the closing prices within the session.
4. **Linear Regression Line:** A statistical trendline showing the "best fit" line for the session's price action.

The indicator is highly customizable, allowing the user to define three separate sessions (e.g., Pre-Market, Core, Post-Market) and toggle the visibility of each analytical component. It fully supports both **standard** and **Heikin Ashi** data sources for all its calculations.

## 2. Calculation Logic

The indicator identifies bars belonging to a specific time window and performs four distinct calculations on the data within that session.

1. **Session Range:**
    - Identifies the highest `High` and lowest `Low` within the session's time boundaries.
    - Draws a rectangle (`OBJ_RECTANGLE`) connecting these points from the start time to the end time of the session.

2. **Volume Weighted Average Price (VWAP):**
    - At the start of each session, cumulative volume and cumulative `Typical Price * Volume` are reset to zero.
    - For each bar within the session, these values are updated, and the VWAP is recalculated as `Cumulative (TP*V) / Cumulative V`.
    - The result is plotted as a continuous, dynamic line using a series of `OBJ_TREND` objects.

3. **Mean Price:**
    - At the start of each session, the cumulative price sum and bar count are reset to zero.
    - For each bar, the `Close` price is added to the sum, and the count is incremented.
    - The final mean price (`Sum / Count`) is drawn as a single horizontal `OBJ_TREND` line across the completed session.

4. **Linear Regression Line:**
    - For all bars within the session, the indicator calculates the sums required for the least squares fit method (`sum_x`, `sum_y`, `sum_xy`, `sum_x2`).
    - At the end of the session, it calculates the slope (`b`) and intercept (`a`) of the regression line.
    - The final line is drawn as a single `OBJ_TREND` object from the calculated start price to the calculated end price of the session.

## 3. MQL5 Implementation Details

- **Modular, Object-Oriented Design:** The entire logic is encapsulated within a `CSessionAnalyzer` class. The main indicator file instantiates three separate objects of this class, one for each user-defined session (Pre-Market, Core, Post-Market), making the code clean and scalable.

- **Heikin Ashi Integration:** The implementation uses an elegant inheritance model. A `CSessionAnalyzer_HA` child class overrides the data preparation step, allowing all calculations (VWAP, Mean, and LinReg) to be performed seamlessly on smoothed Heikin Ashi data if selected by the user.

- **Efficient "On New Bar" Updates:** The indicator is designed to be extremely light on terminal resources. The entire complex calculation and object redrawing process is only performed **once per bar**, preventing unnecessary CPU load on every tick.

- **Robust Time Handling:** The indicator correctly identifies session boundaries regardless of the chart's timeframe and properly handles overnight sessions (e.g., a session that starts at 22:00 and ends at 04:00 the next day).

## 4. Parameters

- **Display Settings:**
  - `InpFillBoxes`: Toggles whether the session range boxes are filled or drawn as outlines.
  - `InpVolumeType`: Selects between `Tick Volume` and `Real Volume` for the VWAP calculation.
  - `InpSourcePrice`: The source price for the Mean and Linear Regression calculations. This unified dropdown allows selection from all standard and Heikin Ashi price types.
- **Session Settings (Pre-Market, Core, Post-Market):**
  - `Enable`: Turns the analysis for that specific session on or off.
  - `Start / End`: The start and end times for the session in "HH:MM" format, based on the **broker's server time**.
  - `Color`: The color for all graphical objects drawn for that session.
  - `VWAP / Mean / LinReg`: Toggles the visibility of each analytical line for that session.

## 5. Usage and Interpretation

- **Contextual Analysis:** The primary use is to understand the behavior of price during specific, high-volume trading sessions.
- **VWAP as a Benchmark:** The VWAP line is a key level for intraday traders. Price action above the session VWAP is generally considered bullish; price action below is bearish. The VWAP often acts as dynamic support or resistance.
- **Mean and Linear Regression:** These lines provide a statistical "fair value" for the session. The slope of the regression line indicates the overall direction and strength of the session's trend.
- **Range Box:** The high and low of the session box become critical support and resistance levels for subsequent trading sessions. A breakout from the previous session's range is often a significant technical event.
