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

Our MQL5 implementation is a prime example of our "Pragmatic Reusability" principle, built as an intelligent "adapter" on top of our existing Stochastic engine.

* **Adapter Design Pattern:** The `WPR_Calculator` does not contain any WPR calculation logic itself. Instead, it **reuses** our existing, standalone `StochasticFast_Calculator.mqh` module.
  * It calls the Fast Stochastic engine to get the %K and %D lines.
  * It then performs a simple transformation (`value - 100`) on the results to convert them to the WPR's -100 to 0 scale.
  * This approach eliminates code duplication and guarantees that our WPR and Fast Stochastic indicators are always perfectly in sync.

* **Object-Oriented Logic:**
  * The `CWPRCalculator` base class contains a pointer to a `CStochasticFastCalculator` object.
  * The Heikin Ashi version (`CWPRCalculator_HA`) is achieved simply by instantiating the Heikin Ashi version of the Stochastic module (`CStochasticFastCalculator_HA`).

* **Optional Signal Line:** The indicator includes a fully customizable moving average signal line, inherited directly from the underlying Fast Stochastic's %D calculation.

## 4. Parameters

* **WPR Period (`InpWPRPeriod`):** The lookback period for the indicator. Default is `14`.
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).
* **Display Mode (`InpDisplayMode`):** Toggles the visibility of the signal line.
* **Signal Line Settings:**
  * `InpSignalPeriod`: The lookback period for the signal line.
  * `InpSignalMAType`: The type of moving average for the signal line.

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:**
  * **Overbought:** Readings between **0 and -20**.
  * **Oversold:** Readings between **-80 and -100**.
* **Divergence:** Look for divergences between the %R and the price action.
* **Momentum Failure:** A common signal is when the %R enters the overbought zone, pulls back, and then fails to re-enter it on a subsequent price rally.
* **Caution:** Like all oscillators, %R can remain in overbought or oversold territory for extended periods during a strong trend.
