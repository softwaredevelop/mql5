# Fast Stochastic RSI Pro

## 1. Summary (Introduction)

The Stochastic RSI (StochRSI), developed by Tushar Chande and Stanley Kroll, is an "indicator of an indicator." It applies the Stochastic Oscillator formula to a set of Relative Strength Index (RSI) values instead of standard price data. The "Fast" version represents the raw, un-smoothed calculation of the Stochastic on the RSI.

Our `StochRSI_Fast_Pro` is a unified, professional version that allows the underlying RSI calculation to be based on either **standard** or **Heikin Ashi** price data, and offers full customization of the signal line's smoothing method.

## 2. Mathematical Foundations and Calculation Logic

The Fast StochRSI is a direct application of the Stochastic formula to an RSI data series.

### Required Components

* **RSI:** The underlying data series for the calculation.
* **Stochastic %K Period:** The lookback period for the highest and lowest RSI values.
* **%D Period & MA Method:** The period and type of MA for the signal line.

### Calculation Steps (Algorithm)

1. **Calculate the RSI:** First, calculate the standard RSI for a given period.
2. **Calculate the Fast %K:** Apply the Stochastic formula to the RSI data series. This is the main line of the Fast StochRSI.
    $\text{Fast \%K}_i = 100 \times \frac{\text{RSI}_i - \text{Lowest Low RSI}_{\text{Stoch Period}}}{\text{Highest High RSI}_{\text{Stoch Period}} - \text{Lowest Low RSI}_{\text{Stoch Period}}}$
3. **Calculate the %D (Signal Line):** The signal line is a moving average of the Fast %K line.
    $\text{\%D}_i = \text{MA}(\text{Fast \%K}, \text{\%D Period}, \text{\%D MA Method})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Component-Based Design (Composition):**
    The StochRSI calculator (`StochRSI_Fast_Calculator.mqh`) is a powerful orchestrator that reuses two of our core engines:
    1. **RSI Engine:** It delegates the RSI calculation to the shared `RSI_Engine.mqh`. This ensures that the underlying RSI values are identical to those of the standard RSI indicator.
    2. **MA Engine:** It delegates the %D signal line smoothing to the universal `MovingAverage_Engine.mqh`.
    This ensures mathematical consistency across the entire suite and eliminates code duplication.

* **Advanced Smoothing Options:**
    Thanks to the integration with the `MovingAverage_Engine`, the %D signal line supports **seven** different smoothing methods (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA).

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations (RSI -> StochRSI -> %D), ensuring that each step starts only when valid data is available.

* **Object-Oriented Logic:**
  * The Heikin Ashi version (`CStochRSI_Fast_Calculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the RSI Engine (`CRSIEngine_HA`).

## 4. Parameters

* **RSI Period (`InpRSIPeriod`):** The lookback period for the underlying RSI. (Default: `14`).
* **Stochastic %K Period (`InpKPeriod`):** The lookback period for the Stochastic calculation on the RSI. (Default: `14`).
* **%D Period (`InpDPeriod`):** The smoothing period for the signal line. (Default: `3`).
* **Applied Price (`InpSourcePrice`):** The source price for the underlying RSI. (Standard or Heikin Ashi).
* **%D MA Type (`InpDMAType`):** The MA type for the "%D" signal line. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line can be used to generate trade signals.
* **Divergence:** Look for divergences between the StochRSI and the price action.
* **Caution:** The Fast StochRSI is extremely sensitive and can produce a significant number of false signals. It is often used as a component in a larger trading system or confirmed with other, less sensitive indicators.
