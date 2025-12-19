# Fast Stochastic Pro

## 1. Summary (Introduction)

The Fast Stochastic Oscillator, developed by George C. Lane, is a momentum indicator that compares a closing price to its price range over a period. It is the original, un-smoothed version of the Stochastic oscillator.

The indicator consists of two lines:

* **%K Line:** The "raw" stochastic value, which is highly sensitive to price changes.
* **%D Line:** A moving average of the %K line, which acts as a signal line.

Because it lacks the extra smoothing layer of the "Slow" version, the Fast Stochastic is much more responsive but also more prone to generating false signals ("whipsaws") in choppy markets.

Our `StochasticFast_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data.

## 2. Mathematical Foundations and Calculation Logic

The Fast Stochastic's %K line is the raw calculation, and the %D line is its direct moving average.

### Calculation Steps (Algorithm)

1. **Calculate the %K Line (Fast %K):** This is the core of the Stochastic calculation. It measures where the current close is relative to the price range over the `%K Period`.
    $\text{\%K}_t = 100 \times \frac{\text{Close}_t - \text{Lowest Low}_{\%K \text{ Period}}}{\text{Highest High}_{\%K \text{ Period}} - \text{Lowest Low}_{\%K \text{ Period}}}$

2. **Calculate the %D Line (Signal Line):** The signal line is a moving average of the %K line, using the selected `%D MA Method` and `%D Period`.
    $\text{\%D}_t = \text{MA}(\text{\%K}, \text{\%D Period}, \text{\%D MA Method})_t$

## 3. MQL5 Implementation Details

Our MQL5 implementation is a robust, unified indicator built on a modular, object-oriented framework.

* **Modular Calculation Engine (`StochasticFast_Calculator.mqh`):**
    The entire calculation logic is encapsulated within a reusable include file.
  * **Composition Pattern:** Instead of re-implementing moving average logic, the Stochastic calculator internally uses our powerful `MovingAverage_Engine`. This ensures that the %D line smoothing is mathematically identical to our standalone Moving Average indicator.

* **Advanced Smoothing Options:**
    Thanks to the integration with the `MovingAverage_Engine`, the %D signal line supports **seven** different smoothing methods (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA), giving traders unprecedented control over signal generation.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks, ensuring seamless updates.
  * **Robust Offset Handling:** The engine correctly handles the initialization period of the %K line (where data is insufficient), ensuring that the %D calculation starts only when valid data is available. This prevents artifacts and "INF" errors at the beginning of the chart.

* **Object-Oriented Design:**
  * An elegant inheritance model (`CStochasticFastCalculator` and `CStochasticFastCalculator_HA`) allows the main indicator file to dynamically choose the correct calculation engine (Standard or Heikin Ashi) at runtime.

## 4. Parameters

* **%K Period (`InpKPeriod`):** The lookback period for the initial Stochastic calculation. (Default: `14`).
* **%D Period (`InpDPeriod`):** The smoothing period for the final signal line (%D). (Default: `3`).
* **%D MA Type (`InpDMAType`):** The type of moving average used for the "%D" step. Now supports extended types: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line is a common trade signal. Due to the indicator's sensitivity, these signals will be more frequent than with the Slow Stochastic.
* **Divergence:** Look for divergences between the Stochastic and the price action.
* **Using Heikin Ashi:** Selecting the Heikin Ashi option results in a smoother oscillator, which can help mitigate some of the inherent "choppiness" of the Fast Stochastic.
