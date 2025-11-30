# RSI Pro Indicator Family (Pro, %B, Oscillator)

## 1. Summary (Introduction)

This document covers our comprehensive, professionally coded MQL5 implementation of an advanced Relative Strength Index (RSI) indicator family. Moving beyond the classic RSI, this suite transforms the well-known momentum oscillator into a complete, multi-faceted analysis system for measuring the **dynamics of momentum itself**.

The core of the family is the **`RSI_Pro`** indicator, which integrates a fully customizable signal line and optional Bollinger Bands directly onto the RSI values. From this powerful base, we derive two specialized oscillators:

* **`RSI_PercentB`**: Normalizes the RSI's position relative to its own volatility bands.
* **`RSI_Oscillator`**: Displays the difference between the RSI and its signal line as a histogram.

All indicators in this family are built on a shared, modular calculation engine and offer a seamless choice between standard price data and smoothed **Heikin Ashi** data, providing a powerful toolkit for advanced momentum analysis.

## 2. Mathematical Foundations and Calculation Logic

All indicators in this family are derived from the same core components: the RSI, its moving average, and the standard deviation of the RSI.

### Required Components

* **RSI Period:** The lookback period for the base RSI calculation.
* **Source Price:** The price series for the RSI calculation (standard prices or Heikin Ashi Close).
* **MA Period & Method:** The period and type of moving average for the signal line / Bollinger Bands centerline.
* **Bands Deviation:** The standard deviation multiplier for the Bollinger Bands on the RSI.

### Calculation Steps (Algorithm)

1. **Prepare Source Price:** The engine first prepares the price series. If a standard price is selected, it is used directly. If a Heikin Ashi price is selected, the indicator first calculates the HA values and uses the corresponding HA price series as the source.

2. **Calculate the Base RSI:** A standard RSI is calculated on the prepared price series using Wilder's smoothing method.

3. **Calculate the Signal Line / Centerline:** The base RSI line is then smoothed using the selected `MA Method` and `MA Period`. This creates the signal line for the `RSI_Pro` and `RSI_Oscillator`, and the centerline for the Bollinger Bands.

4. **Calculate Bollinger Bands on RSI:** Standard Bollinger Bands are calculated based on the **RSI values**, using the MA line from the previous step as the centerline.

5. **Calculate Derivative Indicators:**
    * **`RSI_Oscillator`**: The difference between the RSI and its signal line.
        $\text{Oscillator}_t = \text{RSI}_t - \text{Signal Line}_t$
    * **`RSI_PercentB`**: Normalizes the RSI's position relative to its bands.
        $\%B_t = \frac{\text{RSI}_t - \text{Lower Band}_t}{\text{Upper Band}_t - \text{Lower Band}_t}$

## 3. MQL5 Implementation Details

Our MQL5 suite is built on a single, shared, modular, and robust calculation engine to ensure consistency and maintainability across the entire indicator family.

* **Unified, Reusable Calculation Engine (`RSI_Pro_Calculator.mqh`):** The entire calculation logic for all components (RSI, MA, Bands) and for both standard and Heikin Ashi versions is encapsulated within this powerful include file.
  * An elegant, object-oriented inheritance model (`CRSIProCalculator` and `CRSIProCalculator_HA`) allows all indicators in the family to dynamically choose the correct calculation engine at runtime based on user input.
  * This **DRY (Don't Repeat Yourself)** approach ensures that any future improvements to the core logic are automatically inherited by all indicators in the family.

* **Optimized Incremental Calculation:**
    All indicators employ an intelligent incremental algorithm.
  * They utilize the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (like `m_rsi_buffer`) persist their state between ticks. This allows recursive smoothing methods (like EMA and SMMA for the signal line) to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Flexible "Pro" Indicators:** Functionality is consolidated into powerful "Pro" versions.
  * **`RSI_Pro.mq5`**: The main indicator, featuring a custom `enum` to seamlessly switch between standard and a full range of Heikin Ashi price types. It also has a `Display Mode` to show the RSI alone, with its signal line, or with the full Bollinger Bands.

## 4. Parameters

* **RSI Period (`InpPeriodRSI`):** The lookback period for the base RSI.
* **Source Price (`InpSourcePrice`):** A comprehensive list of price sources, including all standard prices and a full range of Heikin Ashi prices.
* **MA Period & Method:** The period and type of moving average for the signal line and/or Bollinger Bands centerline.
* **Bands Deviation:** The standard deviation multiplier for the Bollinger Bands on the RSI.
* **Display Mode:** (For `RSI_Pro`) Controls which components are visible on the chart.

## 5. Usage and Interpretation

This indicator family allows for a multi-layered analysis of market momentum.

* **`RSI_Pro` (The Main Dashboard):**
  * Use this as the primary tool to get a complete picture. The Bollinger Bands on the RSI define the **expected range of momentum**. The signal line shows the **trend of momentum**.
  * A crossover of the RSI and its signal line is a basic momentum shift signal.
  * The RSI touching its own outer bands signals a **statistical extreme in momentum**, which is often a more reliable signal than the fixed 70/30 levels.

* **`RSI_Oscillator` (The MACD of RSI):**
  * This provides a clear, histogram-based view of the difference between momentum (RSI) and its trend (Signal Line).
  * A zero-line crossover confirms that momentum has crossed its own average, signaling a potential acceleration in price. It is excellent for spotting divergences.

* **`RSI_PercentB` (The Normalized View):**
  * This oscillator normalizes the RSI's position into a 0-1 scale. It provides an objective measure of overbought/oversold conditions based on the momentum's own volatility.
  * Values above 1.0 or below 0.0 are clear signals of extreme momentum that may precede a reversal or consolidation.
