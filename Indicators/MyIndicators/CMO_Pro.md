# Chande Momentum Oscillator (CMO) Professional

## 1. Summary (Introduction)

The Chande Momentum Oscillator (CMO), developed by Tushar Chande, is a pure momentum indicator that measures the direction and strength of a trend. Unlike other oscillators like the RSI which can become "compressed" at their extremes, the CMO uses a distinct calculation that allows it to oscillate freely between -100 and +100.

Our `CMO_Pro` implementation is a comprehensive, professional version that significantly enhances the classic indicator. It includes:

* A fully customizable **Signal Line** for crossover strategies.
* Optional **Bollinger Bands** applied directly to the CMO, providing dynamic overbought/oversold levels based on momentum volatility.
* Support for both **standard** and **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The CMO's formula is direct and intuitive, focusing solely on the net momentum over a specified number of periods.

### Required Components

* **CMO Period (N):** The lookback period for the calculation (e.g., 14).
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Sum of Up and Down Moves:** For the last `N` periods, iterate through each bar and calculate the change from the previous bar.
    * $\text{Price Change}_i = P_i - P_{i-1}$
    * If $\text{Price Change}_i > 0$, add it to a running total, `Sum Up`.
    * If $\text{Price Change}_i < 0$, add its absolute value (`-Price Change_i`) to a running total, `Sum Down`.

2. **Calculate the CMO Value:** The final CMO value is calculated using the following formula, which normalizes the result to the -100 to +100 range.
    $\text{CMO}_i = 100 \times \frac{\text{Sum Up}_i - \text{Sum Down}_i}{\text{Sum Up}_i + \text{Sum Down}_i}$

3. **Calculate Signal Line:** A moving average of the CMO line is calculated.

4. **Calculate Bollinger Bands:** Standard Bollinger Bands are calculated on the CMO line, centered around the Signal Line.

## 3. MQL5 Implementation Details

Our MQL5 implementation is built on our standard, robust, and object-oriented framework.

* **Modular Calculator Engine (`CMO_Calculator.mqh`):**
    All core calculation logic is encapsulated within a dedicated and reusable include file.
  * **Composition:** The calculator internally uses our universal `MovingAverage_Engine.mqh` to handle the smoothing of the Signal Line. This allows for advanced smoothing types (like DEMA or TEMA) beyond the standard SMA.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations.

* **Object-Oriented Design (Inheritance):**
  * A base class, `CCMOCalculator`, performs the full CMO calculation on a given source price.
  * A derived class, `CCMOCalculator_HA`, inherits all the logic and only overrides the `PreparePriceSeries` method to supply Heikin Ashi data as the input.

## 4. Parameters (`CMO_Pro.mq5`)

* **CMO Period (`InpPeriodCMO`):** The lookback period for summing up and down price movements. (Default: `14`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. (Standard or Heikin Ashi).
* **Overlay Settings:**
  * **Display Mode (`InpDisplayMode`):** Toggles between `CMO_Only`, `CMO_and_MA`, and `CMO_and_Bands`.
  * **MA Period (`InpPeriodMA`):** The period for the signal line.
  * **MA Method (`InpMethodMA`):** The type of moving average for the signal line. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**.
  * **Bands Deviation (`InpBandsDev`):** The standard deviation multiplier for the Bollinger Bands.

## 5. Usage and Interpretation

The CMO is a versatile tool for identifying momentum, overbought/oversold conditions, and potential trend reversals.

* **Overbought/Oversold Levels:**
  * **CMO > +50:** The market is considered overbought.
  * **CMO < -50:** The market is considered oversold.
  * **Bollinger Bands:** When the CMO touches or exceeds its own Bollinger Bands, it signals an extreme statistical deviation in momentum, often preceding a reversal.

* **Zero Line Crossover:**
  * A crossover **above the zero line** indicates that bullish momentum is now stronger than bearish momentum.
  * A crossover **below the zero line** indicates that bearish momentum has taken control.

* **Signal Line Crossover:**
  * A crossover of the CMO line and its Signal Line provides earlier entry/exit signals than the zero line cross.
