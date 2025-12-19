# Williams' Percent Range (WPR) Professional

## 1. Summary (Introduction)

Williams' Percent Range (%R), developed by Larry Williams, is a momentum oscillator that identifies overbought and oversold conditions. It is mathematically the inverse of the **Fast Stochastic Oscillator's %K line**, plotted on a negative scale from -100 to 0.

Our `WPR_Pro` implementation is a unified, professional version that not only allows the calculation to be based on either **standard** or **Heikin Ashi** price data, but also includes an optional, fully customizable **signal line**, effectively mirroring the functionality of a full Fast Stochastic oscillator on the WPR's scale.

## 2. Mathematical Foundations and Calculation Logic

The %R formula compares the current close to the recent high-low range.

### Required Components

* **Period (N):** The lookback period for the calculation (e.g., 14).
* **Price Data:** The `High`, `Low`, and `Close` of each bar.

### Calculation Steps (Algorithm)

1. **Find the Highest High and Lowest Low:** For each bar, determine the highest high and lowest low over the last `N` periods.
2. **Calculate the Williams %R:** Apply the main formula.
    $\text{\%R}_i = -100 \times \frac{\text{Highest High}_N - \text{Close}_i}{\text{Highest High}_N - \text{Lowest Low}_N}$

This is mathematically equivalent to: $\text{\%R}_i = \text{Fast \%K}_i - 100$.

## 3. MQL5 Implementation Details

Our MQL5 implementation is a prime example of our "Pragmatic Reusability" principle, built as an intelligent "adapter" on top of our existing engines.

* **Composition Pattern:** The `WPR_Calculator` orchestrates two powerful engines:
  1. **Stochastic Engine:** It reuses the `StochasticFast_Calculator.mqh` to compute the raw %K value, which is then transformed into %R. This eliminates code duplication and guarantees consistency.
  2. **MA Engine:** It uses the `MovingAverage_Engine.mqh` to calculate the optional signal line. This allows for advanced smoothing methods beyond standard MAs.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Efficiency:** By reusing the optimized engines, the WPR inherits their high performance and zero-lag updates.

* **Object-Oriented Logic:**
  * The Heikin Ashi version is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the Stochastic module.

## 4. Parameters

* **WPR Period (`InpWPRPeriod`):** The lookback period for the indicator. (Default: `14`).
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).
* **Display Mode (`InpDisplayMode`):** Toggles the visibility of the signal line.
* **Signal Line Settings:**
  * `InpSignalPeriod`: The lookback period for the signal line.
  * `InpSignalMAType`: The type of moving average for the signal line. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**.

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:**
  * **Overbought:** Readings between **0 and -20**.
  * **Oversold:** Readings between **-80 and -100**.
* **Divergence:** Look for divergences between the %R and the price action.
* **Momentum Failure:** A common signal is when the %R enters the overbought zone, pulls back, and then fails to re-enter it on a subsequent price rally.
* **Caution:** Like all oscillators, %R can remain in overbought or oversold territory for extended periods during a strong trend.
