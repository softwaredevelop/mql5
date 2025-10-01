# Supertrend Professional

## 1. Summary (Introduction)

The Supertrend indicator, developed by Olivier Seban, is a simple yet effective trend-following indicator. Plotted directly on the price chart, the Supertrend line changes color and position based on the market's trend, acting as a dynamic level of support or resistance.

Our `Supertrend_Pro` implementation is a unified, professional version that combines three distinct calculation methodologies into a single, flexible indicator:

1. **Standard:** Classic Supertrend using standard price data for both the trend calculation and the ATR.
2. **HA-Hybrid:** A smoothed Supertrend based on Heikin Ashi prices, with channel width based on standard, real-market ATR.
3. **HA-Pure:** A fully smoothed Supertrend where both the trend calculation and the ATR are based on Heikin Ashi data.

## 2. Mathematical Foundations and Calculation Logic

The Supertrend indicator combines a measure of volatility (Average True Range - ATR) with a central price point to construct upper and lower bands.

### Required Components

* **ATR (Average True Range):** A measure of market volatility.
* **Factor (Multiplier):** A user-defined multiplier that adjusts the sensitivity.
* **Median Price (hl2):** The central point for the bands, calculated as `(High + Low) / 2`.

### Calculation Steps (Algorithm)

1. **Calculate the Average True Range (ATR)**.
2. **Calculate the Basic Upper and Lower Bands:**
    * $\text{Upper Basic Band} = \frac{\text{High} + \text{Low}}{2} + (\text{Factor} \times \text{ATR})$
    * $\text{Lower Basic Band} = \frac{\text{High} + \text{Low}}{2} - (\text{Factor} \times \text{ATR})$
3. **Calculate the Final Upper and Lower Bands** using the "stair-step" logic to ensure bands never move against the trend.
4. **Determine the Trend Direction** by comparing the closing price to the opposite band.
5. **Plot the Supertrend Line:**
    * If the trend is **up**, plot the **Final Lower Band**.
    * If the trend is **down**, plot the **Final Upper Band**.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Component-Based Design:** The Supertrend calculator (`Supertrend_Calculator.mqh`) **reuses** our existing, standalone `ATR_Calculator.mqh` module. This eliminates code duplication and ensures that the ATR component is always our robust, definition-true Wilder's ATR.

* **Object-Oriented Logic:**
  * The `CSupertrendCalculator` base class performs the full, state-dependent calculation.
  * The `CSupertrendCalculator_HA` child class inherits all the complex logic and only overrides the initial data preparation step to use smoothed Heikin Ashi prices.
  * The calculator internally checks the `InpAtrSource` parameter and instructs its contained `ATR_Calculator` object to use either standard or Heikin Ashi data, providing all three logical variations within a clean, unified structure.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate`. For a state-dependent indicator like Supertrend, this is the most reliable method.

## 4. Parameters

* **ATR Period (`InpAtrPeriod`):** The lookback period for the ATR calculation. Default is `10`.
* **Factor (`InpFactor`):** The multiplier applied to the ATR value. Default is `3.0`.
* **Candle Source (`InpCandleSource`):** Determines the source for the Supertrend's price component (`(High+Low)/2` and `Close`).
* **ATR Source (`InpAtrSource`):** Determines the source for the ATR calculation (`Standard` or `Heikin Ashi`), allowing you to create "Hybrid" or "Pure" HA versions.

## 5. Usage and Interpretation

* **Trend Identification:** A green line below the price indicates an uptrend. A red line above the price indicates a downtrend.
* **Trailing Stop-Loss:** The indicator is exceptionally well-suited for use as a trailing stop-loss.
* **Trade Signals:** A change in the indicator's color can be interpreted as a trade signal.
* **Caution:** Like all trend-following indicators, Supertrend is most effective in trending markets. In sideways or ranging markets, it can produce frequent false signals ("whipsaws").
