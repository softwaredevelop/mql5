# Slow Stochastic RSI Pro

## 1. Summary (Introduction)

The Stochastic RSI (StochRSI), developed by Tushar Chande and Stanley Kroll, is an "indicator of an indicator." It applies the Stochastic Oscillator formula to a set of Relative Strength Index (RSI) values instead of standard price data. The primary goal is to identify overbought and oversold conditions with greater sensitivity than the RSI alone.

The "Slow" version adds an extra layer of smoothing to its main line, making it less erratic. Our `StochRSI_Slow_Pro` is a unified, professional version that allows the underlying RSI calculation to be based on either **standard** or **Heikin Ashi** price data, and offers full customization of the Stochastic's smoothing methods.

## 2. Mathematical Foundations and Calculation Logic

The StochRSI builds upon the standard RSI and Stochastic formulas.

### Required Components

* **RSI:** The underlying data series for the calculation.
* **Stochastic %K Period:** The lookback period for the highest and lowest RSI values.
* **Slowing Period & MA Method:** The period and type of MA for the first smoothing step.
* **%D Period & MA Method:** The period and type of MA for the signal line.

### Calculation Steps (Algorithm)

1. **Calculate the RSI:** First, calculate the standard RSI for a given period.
2. **Calculate the Raw %K (Fast StochRSI):** Apply the Stochastic formula to the RSI data series.
    $\text{Raw \%K}_i = 100 \times \frac{\text{RSI}_i - \text{Lowest Low RSI}_{\text{Stoch Period}}}{\text{Highest High RSI}_{\text{Stoch Period}} - \text{Lowest Low RSI}_{\text{Stoch Period}}}$
3. **Calculate the Slow %K (Main Line):** The Raw %K line is smoothed using the selected `Slowing MA Method` and `Slowing Period`.
    $\text{Slow \%K}_i = \text{MA}(\text{Raw \%K}, \text{Slowing Period}, \text{Slowing MA Method})_i$
4. **Calculate the %D (Signal Line):** The signal line is a moving average of the Slow %K line.
    $\text{Slow \%D}_i = \text{MA}(\text{Slow \%K}, \text{\%D Period}, \text{\%D MA Method})_i$

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Component-Based Design (Composition):**
    The StochRSI calculator (`StochRSI_Slow_Calculator.mqh`) is a powerful orchestrator that reuses three of our core engines:
    1. **RSI Engine:** It delegates the RSI calculation to the shared `RSI_Engine.mqh`. This ensures that the underlying RSI values are identical to those of the standard RSI indicator.
    2. **Slowing Engine:** It uses a `MovingAverage_Engine.mqh` instance to smooth the Raw %K.
    3. **Signal Engine:** It uses another `MovingAverage_Engine.mqh` instance to calculate the %D line.
    This ensures mathematical consistency across the entire suite and eliminates code duplication.

* **Advanced Smoothing Options:**
    Thanks to the integration with the `MovingAverage_Engine`, both smoothing steps support **seven** different methods (SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA).

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations (RSI -> Raw %K -> Slow %K -> %D), ensuring that each step starts only when valid data is available.

* **Object-Oriented Logic:**
  * The Heikin Ashi version (`CStochRSI_Slow_Calculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the RSI Engine (`CRSIEngine_HA`).

## 4. Parameters

* **RSI Period (`InpRSIPeriod`):** The lookback period for the underlying RSI. (Default: `14`).
* **Stochastic %K Period (`InpKPeriod`):** The lookback period for the Stochastic calculation on the RSI. (Default: `14`).
* **Slowing Period (`InpSlowingPeriod`):** The smoothing period for the main Slow %K line. (Default: `3`).
* **%D Period (`InpDPeriod`):** The smoothing period for the signal line. (Default: `3`).
* **Applied Price (`InpSourcePrice`):** The source price for the underlying RSI. (Standard or Heikin Ashi).
* **Slowing MA Type (`InpSlowingMAType`):** The MA type for the "Slowing" step. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).
* **%D MA Type (`InpDMAType`):** The MA type for the "%D" signal line. Supports: **SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA**. (Default: `SMA`).

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line can be used to generate trade signals.
* **Divergence:** Look for divergences between the StochRSI and the price action.
* **Caution:** Due to its sensitivity, StochRSI can produce many false signals. It is best used for confirmation alongside other trend-following indicators.
