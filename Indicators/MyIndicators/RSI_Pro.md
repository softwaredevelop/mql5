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

* **Unified, Reusable Calculation Engine (`RSI_Pro_Calculator.mqh`):**
    The entire calculation logic is encapsulated within this powerful include file.
  * **Composition Pattern:** The calculator internally uses our universal `MovingAverage_Engine.mqh` to handle the smoothing of the Signal Line. This allows for advanced smoothing types (like DEMA or TEMA) beyond the standard SMA.
  * **Drift-Free RSI:** We implemented a robust internal buffering system for the Wilder's Smoothing components (Average Gain/Loss). This prevents the common "RSI Drift" issue seen in many incremental implementations, ensuring that the indicator values remain stable and accurate over time.

* **Optimized Incremental Calculation (O(1)):**
    All indicators employ an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations (RSI -> Signal Line -> Bands), ensuring that each step starts only when valid data is available.

* **Object-Oriented Design:**
  * An elegant inheritance model (`CRSIProCalculator` and `CRSIProCalculator_HA`) allows all indicators in the family to dynamically choose the correct calculation engine at runtime based on user input.

## 4. Parameters

* **RSI Period (`InpPeriodRSI`):** The lookback period for the base RSI.
* **Source Price (`InpSourcePrice`):** A comprehensive list of price sources, including all standard prices and a full range of Heikin Ashi prices.
* **MA Period (`InpPeriodMA`):** The period for the signal line / Bollinger Bands centerline.
* **MA Method (`InpMethodMA`):** The type of moving average. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**.
* **Bands Deviation (`InpBandsDev`):** The standard deviation multiplier for the Bollinger Bands on the RSI.
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
