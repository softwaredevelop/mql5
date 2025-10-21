# RSIH Professional (RSI with Hann Windowing & NET)

## 1. Summary (Introduction)

The RSIH, or "RSI with Hann Windowing," is John Ehlers' innovative take on the classic Relative Strength Index. It introduces two fundamental improvements: a **zero-mean (-1 to +1) scale** for clearer momentum analysis, and a **Hann windowing function** for intrinsic smoothing.

This version is further enhanced with Ehlers' **Noise Elimination Technology (NET)**, a non-lagging filter based on Kendall correlation. The indicator plots two lines:

1. **RSIH Line (dotted gray):** The base, Hann-smoothed RSI. It is faster but can be noisy.
2. **NET Line (solid blue):** The NET-filtered version of the RSIH. This line is significantly smoother, clarifying the underlying momentum state without adding the lag of traditional moving averages.

The result is a comprehensive, two-line oscillator system that provides both a fast signal and a smoothed, reliable confirmation.

## 2. Mathematical Foundations and Calculation Logic

The indicator uses a multi-stage process, first calculating the RSIH and then optionally applying the NET filter.

### Required Components

* **RSI Period (N):** The lookback period for the RSIH calculation.
* **NET Period (M):** The lookback period for the NET calculation.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Weighted CU and CD:** For each bar, the indicator calculates the "Closes Up" (CU) and "Closes Down" (CD) over the last `N` periods. Each price difference is weighted using a **Hann windowing function**, which gives more importance to the data in the middle of the period.
2. **Calculate RSIH Value:** Apply Ehlers' zero-mean transformation:
    $\text{RSIH} = \frac{\text{CU} - \text{CD}}{\text{CU} + \text{CD}}$
3. **Apply NET Filter (Optional):** The calculated RSIH values are then processed by the NET algorithm.
    * The NET calculates the **Kendall rank correlation** between the last `M` values of the RSIH and a perfectly linear trend.
    * It essentially measures the "directional consistency" of the RSIH. If the RSIH is moving smoothly up or down, the correlation is high (near +1 or -1). If it's choppy, the correlation is low (near 0).
    * The result is a smoothed version of the RSIH where the "noise" (inconsistent movements) has been stripped out.

## 3. MQL5 Implementation Details

* **Unified Calculator (`RSIH_Calculator.mqh`):** The entire calculation for both RSIH and NET is encapsulated within a single, dedicated calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows all calculations to be performed seamlessly on smoothed Heikin Ashi data.
* **FIR-based Logic:** The RSIH calculation is a non-recursive (FIR) filter. The NET calculation is a statistical correlation, also non-recursive. This gives the indicator a finite "memory."
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure stability and accuracy.

## 4. Parameters

* **RSI Period (`InpPeriodRSI`):** The lookback period (`N`) for the base RSIH calculation.
* **NET Period (`InpPeriodNET`):** The lookback period (`M`) for the Noise Elimination Technology filter.
* **Apply NET (`InpApplyNET`):** Toggles the visibility and calculation of the NET line. If `false`, only the base RSIH line will be shown as a solid line.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

**Note on Period Sensitivity:** Due to the FIR-based nature of the calculations, this indicator is **highly sensitive to period length**. A small change in `InpPeriodRSI` or `InpPeriodNET` can significantly alter the shape of the output. Users are encouraged to experiment to find the optimal "tuning" for their specific instrument and timeframe. Ehlers uses `14` as a starting point in his articles.

## 5. Usage and Interpretation

The RSIH indicator with NET is a two-line system designed for signal confirmation. Use the **blue NET line** to determine the overall momentum bias and the **gray RSIH line** for timing signals.

### **1. NET Line as a Momentum Filter (Primary Strategy)**

The blue NET line provides a very clear, smoothed view of the market's momentum state.

* **Bullish Bias (NET > 0):** When the blue NET line is above the zero line, the underlying momentum is bullish. In this state, primarily look for **buy signals** on the gray RSIH line.
* **Bearish Bias (NET < 0):** When the blue NET line is below the zero line, the underlying momentum is bearish. In this state, primarily look for **sell signals** on the gray RSIH line.

### **2. RSIH for Entry Signals**

Once the bias is determined by the NET line, use the faster, gray RSIH line for timing entries.

* **Buy Signal:** While the **blue NET line is above 0**, wait for the **gray RSIH line** to dip into the oversold zone (e.g., below -0.5) and then cross back up. This signals a pullback entry in an ongoing uptrend.
* **Sell Signal:** While the **blue NET line is below 0**, wait for the **gray RSIH line** to rise into the overbought zone (e.g., above +0.5) and then cross back down. This signals a rally entry in an ongoing downtrend.

### **3. Crossover Signals**

The crossover of the two lines can be used as a confirmation signal, though it will have more lag.

* **Buy Confirmation:** The gray RSIH line crosses above the blue NET line.
* **Sell Confirmation:** The gray RSIH line crosses below the blue NET line.
