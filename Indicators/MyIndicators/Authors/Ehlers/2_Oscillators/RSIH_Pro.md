# RSIH Professional (RSI with Hann Windowing & NET)

## 1. Summary (Introduction)

The **RSIH Professional** is John Ehlers' innovative take on the classic Relative Strength Index. It introduces two fundamental improvements: a **zero-mean (-1 to +1) scale** for clearer momentum analysis, and a **Hann windowing function** for intrinsic smoothing.

This version is further enhanced with Ehlers' **Noise Elimination Technology (NET)**, a non-lagging filter based on Kendall correlation. The indicator plots two lines:

1. **RSIH Line (solid blue):** The base, Hann-smoothed RSI. It is faster but can be noisy.
2. **NET Line (dotted gray):** The NET-filtered version of the RSIH. This line is significantly smoother, clarifying the underlying momentum state without adding the lag of traditional moving averages.

## 2. Mathematical Foundations

The indicator uses a multi-stage process:

1. **Weighted CU/CD:** The "Closes Up" and "Closes Down" values are calculated using a **Hann Windowed FIR Filter**. This gives more weight to the data in the middle of the period, providing superior smoothing compared to a simple average.
2. **RSIH Calculation:** Ehlers' zero-mean transformation is applied:
    $\text{RSIH} = \frac{\text{CU} - \text{CD}}{\text{CU} + \text{CD}}$
3. **NET Filter (Optional):** The RSIH values are processed by the NET algorithm (Kendall rank correlation) to strip out noise and reveal the true trend direction.

## 3. MQL5 Implementation Details

* **O(1) Incremental Calculation:** Optimized for high performance. The indicator processes only new bars (`prev_calculated`), ensuring zero lag and minimal CPU usage.
* **Modular Engine:** The calculation leverages our `Windowed_MA_Calculator` for the Hann windowing logic, ensuring mathematical precision and code reusability.
* **Heikin Ashi Integration:** Built-in support for all Heikin Ashi price types.

## 4. Parameters

* **RSI Period (`InpPeriodRSI`):** The lookback period for the base RSIH calculation. Default is `14`.
* **NET Period (`InpPeriodNET`):** The lookback period for the NET filter. Default is `14`.
* **Apply NET (`InpApplyNET`):** Toggles the visibility of the NET line.
* **Source Price (`InpSourcePrice`):** Selects the input data.

## 5. Usage and Interpretation

The RSIH with NET is a two-line system designed for signal confirmation.

### Momentum Filter (NET Line)

* **Bullish Bias (NET > 0):** When the blue NET line is positive, look for buy signals.
* **Bearish Bias (NET < 0):** When the blue NET line is negative, look for sell signals.

### Timing Signals (RSIH Line)

* **Pullback Entry:** In a bullish trend (NET > 0), wait for the gray RSIH line to dip into oversold territory (<-0.5) and turn up.
* **Rally Entry:** In a bearish trend (NET < 0), wait for the gray RSIH line to rise into overbought territory (>0.5) and turn down.
