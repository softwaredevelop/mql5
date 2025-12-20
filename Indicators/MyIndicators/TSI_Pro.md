# True Strength Index (TSI) Professional

## 1. Summary (Introduction)

The True Strength Index (TSI), developed by William Blau, is a momentum oscillator designed to provide a smoother and more reliable measure of market momentum. It fluctuates around a zero line, providing clear signals for trend direction, momentum, and overbought/oversold conditions.

**Classic Definition:** The original TSI is defined as a double-smoothed momentum indicator using two **Exponential Moving Averages (EMAs)**.

**Pro Features:** Our `TSI_Pro` implementation extends this concept by allowing the calculation to be based on either **standard** or **Heikin Ashi** price data, and offers unprecedented customization by allowing traders to replace the standard EMAs with other smoothing methods (like SMA, DEMA, or TEMA).

## 2. Mathematical Foundations and Calculation Logic

The TSI is calculated by double-smoothing both the price momentum and the absolute price momentum, and then computing their ratio.

### Required Components

* **Slow Period (N_slow):** The period for the first, longer-term smoothing (standard is 25).
* **Fast Period (N_fast):** The period for the second, shorter-term smoothing (standard is 13).
* **Signal Period:** The period for the moving average signal line.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Price Momentum:** $\text{Momentum}_i = P_i - P_{i-1}$

2. **First Smoothing (Slow Period):** Apply an `N_slow`-period Moving Average to both the `Momentum` and its absolute value.
   * *Classic TSI uses EMA here.*

3. **Second Smoothing (Fast Period):** Apply an `N_fast`-period Moving Average to the results of the first smoothing step.
   * *Classic TSI uses EMA here.*

4. **Calculate the TSI Value:** Divide the double-smoothed momentum by the double-smoothed absolute momentum and scale the result to 100.
    $\text{TSI}_i = 100 \times \frac{\text{MA}_{\text{fast}}(\text{MA}_{\text{slow}}(\text{Momentum}))_i}{\text{MA}_{\text{fast}}(\text{MA}_{\text{slow}}(\text{AbsMomentum}))_i}$

5. **Calculate the Signal Line:** The signal line is a moving average of the TSI line itself.

## 3. MQL5 Implementation Details

Our MQL5 implementation follows a modern, component-based, object-oriented design.

* **Full Engine Integration:**
    The TSI calculator (`TSI_Calculator.mqh`) is a powerful orchestrator that utilizes **five** instances of our universal `MovingAverage_Engine.mqh`:
    1. **Slow Momentum Engine:** Smooths raw momentum.
    2. **Fast Momentum Engine:** Double-smooths the result.
    3. **Slow Abs Momentum Engine:** Smooths absolute momentum.
    4. **Fast Abs Momentum Engine:** Double-smooths the result.
    5. **Signal Engine:** Smooths the final TSI line.
    This architecture allows for extreme flexibility (e.g., using DEMA for internal smoothing) while maintaining code consistency.

* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** Internal buffers persist their state between ticks.
  * **Robust Offset Handling:** The engine correctly handles the initialization periods of the chained calculations, ensuring that each step starts only when valid data is available.

* **Object-Oriented Logic:**
  * The Heikin Ashi version (`CTSICalculator_HA`) is achieved simply by instructing the main calculator to instantiate the Heikin Ashi version of the data preparation module.

## 4. Parameters

* **TSI Calculation Settings:**
  * `InpSlowPeriod`: The period for the first smoothing step. (Default: `25`).
  * `InpSlowMAType`: The MA type for the first smoothing. Set to **EMA** for classic TSI behavior. (Default: `EMA`).
  * `InpFastPeriod`: The period for the second smoothing step. (Default: `13`).
  * `InpFastMAType`: The MA type for the second smoothing. Set to **EMA** for classic TSI behavior. (Default: `EMA`).
  * `InpSourcePrice`: The source price for the calculation. (Standard or Heikin Ashi).
* **Signal Line Settings:**
  * `InpSignalPeriod`: The lookback period for the signal line. (Default: `13`).
  * `InpSignalMAType`: The type of moving average for the signal line. (Default: `EMA`).

## 5. Usage and Interpretation

* **Zero Line Crossovers:** A crossover of the TSI line above the zero line indicates that long-term momentum has turned positive. A crossover below indicates negative momentum.
* **Signal Line Crossovers:** These provide earlier, shorter-term momentum signals. A bullish crossover is when the TSI line crosses above its signal line; a bearish crossover is the opposite.
* **Overbought/Oversold Levels:** The **+25 and -25** levels are often used to identify extreme momentum.
* **Divergence:** Due to its smoothness, the TSI is excellent for spotting divergences between price and momentum, which can foreshadow reversals.
