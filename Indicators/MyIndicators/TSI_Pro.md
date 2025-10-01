# True Strength Index (TSI) Professional

## 1. Summary (Introduction)

The True Strength Index (TSI), developed by William Blau, is a momentum oscillator designed to provide a smoother and more reliable measure of market momentum by using a double-smoothing mechanism with Exponential Moving Averages (EMAs). It fluctuates around a zero line, providing clear signals for trend direction, momentum, and overbought/oversold conditions.

Our `TSI_Pro` implementation is a unified, professional version that allows the calculation to be based on either **standard** or **Heikin Ashi** price data, selectable from a single input parameter.

## 2. Mathematical Foundations and Calculation Logic

The TSI is calculated by double-smoothing both the price momentum and the absolute price momentum, and then computing their ratio.

### Required Components

* **Slow Period (N_slow):** The period for the first, longer-term EMA smoothing (standard is 25).
* **Fast Period (N_fast):** The period for the second, shorter-term EMA smoothing (standard is 13).
* **Signal Period:** The period for the moving average signal line.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Price Momentum:** $\text{Momentum}_i = P_i - P_{i-1}$
2. **First EMA Smoothing (Slow Period):** Apply an `N_slow`-period EMA to both the `Momentum` and its absolute value.
3. **Second EMA Smoothing (Fast Period):** Apply an `N_fast`-period EMA to the results of the first smoothing step.
4. **Calculate the TSI Value:** Divide the double-smoothed momentum by the double-smoothed absolute momentum and scale the result to 100.
    $\text{TSI}_i = 100 \times \frac{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{Momentum}))_i}{\text{EMA}_{\text{fast}}(\text{EMA}_{\text{slow}}(\text{AbsMomentum}))_i}$
5. **Calculate the Signal Line:** The signal line is a moving average of the TSI line itself.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Centralized Calculation Engine (`TSI_Engine.mqh`):**
    The core of our implementation is a single, powerful calculation engine. This include file contains the complete, definition-true logic for calculating both the TSI and its signal line. It supports both standard and Heikin Ashi data sources through class inheritance (`CTSICalculator` and `CTSICalculator_HA`).

* **Specialized Wrapper (`TSI_Calculator.mqh`):**
    The final indicator uses a thin "wrapper" class that utilizes the central engine. The wrapper's role is to instantiate the correct engine (standard or HA) and provide a clean interface to the main `.mq5` indicator file. This approach eliminates code duplication and ensures all TSI-based indicators in our toolkit use the exact same calculation logic.

* **Stability via Full Recalculation:** We employ a "brute-force" full recalculation within `OnCalculate` for maximum stability.

* **Fully Manual EMA Calculations:** All EMA calculations are performed **manually**, with robust initialization to provide a stable starting point for the calculation chain.

## 4. Parameters

* **Slow Period (`InpSlowPeriod`):** The period for the first, longer-term EMA smoothing. Default is `25`.
* **Fast Period (`InpFastPeriod`):** The period for the second, shorter-term EMA smoothing. Default is `13`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.
* **Signal Line Settings:**
  * `InpSignalPeriod`: The lookback period for the signal line. Default is `13`.
  * `InpSignalMAType`: The type of moving average for the signal line. Default is `MODE_EMA`.

## 5. Usage and Interpretation

* **Zero Line Crossovers:** A crossover of the TSI line above the zero line indicates that long-term momentum has turned positive. A crossover below indicates negative momentum.
* **Signal Line Crossovers:** These provide earlier, shorter-term momentum signals. A bullish crossover is when the TSI line crosses above its signal line; a bearish crossover is the opposite.
* **Overbought/Oversold Levels:** The **+25 and -25** levels are often used to identify extreme momentum.
* **Divergence:** Due to its smoothness, the TSI is excellent for spotting divergences between price and momentum, which can foreshadow reversals.
