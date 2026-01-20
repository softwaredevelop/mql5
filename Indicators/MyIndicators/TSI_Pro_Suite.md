# True Strength Index (TSI) Pro Suite

## 1. Summary (Introduction)

The **True Strength Index (TSI)**, developed by William Blau, is a momentum oscillator designed to provide a smoother and more reliable measure of market momentum than traditional indicators. It fluctuates around a zero line, providing clear signals for trend direction, momentum, and overbought/oversold conditions.

Our professional implementation, the **TSI Pro Suite**, modernizes this classic indicator by offering:

* **Extended Smoothing Types:** Ability to replace the standard EMAs with SMA, DEMA, TEMA, etc., for both the core calculation and the signal line.
* **Full Heikin Ashi Support:** Seamless integration with Heikin Ashi price data.
* **Modular Design:** A unified calculation engine powering both the line and oscillator versions.

The suite consists of:

1. **`TSI_Pro`:** The classic implementation (TSI Line + Signal Line).
2. **`TSI_Oscillator_Pro`:** A histogram version displaying the difference between the TSI and its Signal Line.

## 2. Mathematical Foundations

The TSI is calculated by double-smoothing both the price momentum and the absolute price momentum.

### Calculation Steps

1. **Momentum:** Calculate the change in price from the previous bar.
    * $M = P_i - P_{i-1}$
2. **First Smoothing (Slow):** Apply a moving average (typically EMA) to both $M$ and $|M|$ over the `Slow Period`.
3. **Second Smoothing (Fast):** Apply a moving average to the results of the first step over the `Fast Period`.
4. **TSI Value:**
    * $\text{TSI} = 100 \times \frac{\text{DoubleSmoothed}(M)}{\text{DoubleSmoothed}(|M|)}$
5. **Signal Line:** A moving average of the TSI line.
6. **Oscillator:** $\text{TSI} - \text{Signal Line}$.

## 3. MQL5 Implementation Details

* **Unified Calculator Engine:** Both indicators use the `TSI_Calculator.mqh` engine. This ensures mathematical consistency.
* **O(1) Incremental Calculation:** Optimized for high performance. The indicators process only new bars (`prev_calculated`), ensuring zero lag.
* **Composition:** The calculator internally uses 5 instances of our `MovingAverage_Engine` to handle the various smoothing steps flexibly.

## 4. Parameters

### TSI Calculation Settings

* **Slow Period:** Lookback for the first smoothing (Default: 25).
* **Slow MA Type:** Smoothing method for the first step (Default: EMA).
* **Fast Period:** Lookback for the second smoothing (Default: 13).
* **Fast MA Type:** Smoothing method for the second step (Default: EMA).
* **Price Source:** Selects the input data (Standard or Heikin Ashi).

### Signal Line Settings

* **Signal Period:** Lookback for the signal line (Default: 13).
* **Signal MA Type:** Smoothing method for the signal line (Default: EMA).

## 5. Usage and Interpretation

### TSI Line (`TSI_Pro`)

* **Signal Crossover:** Buy when TSI crosses above Signal; Sell when TSI crosses below Signal.
* **Zero Line:** Crossover indicates long-term trend change.
* **Divergence:** Divergences between TSI and price often precede reversals.

### TSI Oscillator (`TSI_Oscillator_Pro`)

* **Histogram:** Visualizes the momentum strength. Growing bars = accelerating momentum. Shrinking bars = decelerating momentum.
* **Zero Cross:** Corresponds to the TSI/Signal crossover.
