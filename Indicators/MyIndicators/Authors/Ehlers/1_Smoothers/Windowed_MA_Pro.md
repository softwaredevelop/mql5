# Windowed MA Professional

## 1. Summary (Introduction)

The Windowed MA Pro is an indicator based on John Ehlers' research into advanced **Finite Impulse Response (FIR) filters**. It serves as a superior alternative to the Simple Moving Average (SMA) by employing a **Hann Window** function to create a smoother, more responsive output.

A standard SMA uses a "rectangular window," giving equal weight to all prices in the lookback period, which results in poor filtering characteristics. This indicator applies a mathematically superior cosine-based weighting scheme (Hann Window) that provides excellent smoothing and is Ehlers' recommended choice for most trading applications.

The result is a high-fidelity moving average that produces a cleaner representation of the trend with less noise than a standard SMA.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a weighted moving average, where the weights are determined by the Hann window function.

### Calculation Steps (Algorithm)

For each bar, the indicator looks back over the last `N` periods.

1. **Calculate Weights:** For each position `j` within the `N`-period window, a specific weight is calculated using a cosine formula, creating a smooth, bell-shaped curve:
    $W_j = 0.5 \times (1 - \cos(\frac{2\pi \times j}{N-1}))$
2. **Calculate Weighted Sum:** The source price at each position is multiplied by its corresponding weight and summed up.
3. **Normalize:** The final indicator value is the weighted sum divided by the sum of all weights.

## 3. MQL5 Implementation Details

* **Unified Calculator (`Windowed_MA_Calculator.mqh`):** The calculation is handled by a dedicated calculator class.
* **Optimized Incremental Calculation (O(1)):**
    Unlike basic implementations that recalculate the entire history on every tick, this indicator employs an intelligent incremental algorithm.
  * **State Tracking:** It utilizes `prev_calculated` to process only new bars.
  * **Persistent Buffers:** The internal price buffer persists its state between ticks.
  * **Pre-calculated Weights:** The Hann weights are calculated only once during initialization, making the runtime calculation extremely fast.
* **Heikin Ashi Integration:** The indicator fully supports calculation on smoothed Heikin Ashi data.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) for the moving average. (Default: `20`).
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. (Standard or Heikin Ashi).

## 5. Usage and Interpretation

The Windowed MA should be used as a high-quality replacement for a standard Simple Moving Average.

* **Trend Identification:** Use it to identify the direction of the trend. Price trading above the line indicates an uptrend; price below indicates a downtrend.
* **Dynamic Support and Resistance:** The line acts as a dynamic S/R level. Due to its superior smoothing, it often provides more reliable support/resistance than a standard SMA.

### **Combined Strategy with Windowed Momentum (Advanced)**

The true power of the Ehlers windowing concept is revealed when using the `Windowed_MA_Pro` and `Windowed_Momentum_Pro` indicators together. A key relationship exists between them:

* **The Momentum Oscillator's zero-cross predicts the Moving Average's turning point.**
  * When the `Windowed_Momentum` oscillator crosses **above its zero line**, it signals that the `Windowed_MA` is forming a **trough (a bottom)**.
  * When the `Windowed_Momentum` oscillator crosses **below its zero line**, it signals that the `Windowed_MA` is forming a **peak (a top)**.

This relationship can be used to anticipate changes in the short-term trend defined by the moving average, providing a powerful leading signal.
