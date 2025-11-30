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

* **Component-Based Design:** The StochRSI calculator (`StochRSI_Slow_Calculator.mqh`) does not recalculate the RSI internally. Instead, it **reuses** our existing, standalone `RSI_Pro_Calculator.mqh` module. This eliminates code duplication and ensures that both the RSI and StochRSI indicators are always based on the exact same, robust RSI calculation logic.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (like `m_rsi_buffer` and `m_raw_k`) persist their state between ticks. This allows recursive smoothing methods (like EMA and SMMA) to continue seamlessly from the last known value without re-processing the entire history.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Object-Oriented Logic:**
  * The `CStochRSI_Slow_Calculator` contains a pointer to an `CRSIProCalculator` object.
  * The Heikin Ashi version (`CStochRSI_Slow_Calculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the RSI module (`CRSIProCalculator_HA`).

* **Full MA Type Support:** The calculator contains a complete, robust implementation for all standard MQL5 MA types (SMA, EMA, SMMA, LWMA) for both the "Slowing" and the "%D" smoothing steps.

## 4. Parameters

* **RSI Period (`InpRSIPeriod`):** The lookback period for the underlying RSI.
* **Stochastic %K Period (`InpKPeriod`):** The lookback period for the Stochastic calculation on the RSI.
* **Slowing Period (`InpSlowingPeriod`):** The smoothing period for the main Slow %K line.
* **%D Period (`InpDPeriod`):** The smoothing period for the signal line.
* **Applied Price (`InpSourcePrice`):** The source price for the underlying RSI. This unified dropdown allows you to select from all standard and Heikin Ashi price types.
* **Slowing MA Type (`InpSlowingMAType`):** The MA type for the "Slowing" step.
* **%D MA Type (`InpDMAType`):** The MA type for the "%D" signal line.

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line can be used to generate trade signals.
* **Divergence:** Look for divergences between the StochRSI and the price action.
* **Caution:** Due to its sensitivity, StochRSI can produce many false signals. It is best used for confirmation alongside other trend-following indicators.
