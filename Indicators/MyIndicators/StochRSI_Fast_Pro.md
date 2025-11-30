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

* **Component-Based Design:** The StochRSI calculator (`StochRSI_Fast_Calculator.mqh`) **reuses** our existing, standalone `RSI_Pro_Calculator.mqh` module. This eliminates code duplication and ensures consistency.

* **Optimized Incremental Calculation:**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * It utilizes the `prev_calculated` state to determine the exact starting point for updates.
  * **Persistent State:** The internal buffers (like `m_rsi_buffer`) persist their state between ticks. This allows the calculation to efficiently access historical RSI data for the High/Low range search without re-copying or re-calculating the entire series.
  * This results in **O(1) complexity** per tick, ensuring instant updates and zero lag, even on charts with extensive history.

* **Object-Oriented Logic:**
  * The `CStochRSI_Fast_Calculator` contains a pointer to an `CRSIProCalculator` object.
  * The Heikin Ashi version (`CStochRSI_Fast_Calculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the RSI module (`CRSIProCalculator_HA`).

* **Full MA Type Support:** The calculator contains a complete, robust implementation for all standard MQL5 MA types (SMA, EMA, SMMA, LWMA) for the "%D" signal line smoothing.

## 4. Parameters

* **RSI Period (`InpRSIPeriod`):** The lookback period for the underlying RSI.
* **Stochastic %K Period (`InpKPeriod`):** The lookback period for the Stochastic calculation on the RSI.
* **%D Period (`InpDPeriod`):** The smoothing period for the signal line.
* **Applied Price (`InpSourcePrice`):** The source price for the underlying RSI. This unified dropdown allows you to select from all standard and Heikin Ashi price types.
* **%D MA Type (`InpDMAType`):** The MA type for the "%D" signal line.

## 5. Usage and Interpretation

* **Overbought/Oversold Levels:** The primary use is to identify overbought (typically above 80) and oversold (typically below 20) conditions.
* **Crossovers:** The crossover of the %K line and the %D signal line can be used to generate trade signals.
* **Divergence:** Look for divergences between the StochRSI and the price action.
* **Caution:** The Fast StochRSI is extremely sensitive and can produce a significant number of false signals. It is often used as a component in a larger trading system or confirmed with other, less sensitive indicators.
