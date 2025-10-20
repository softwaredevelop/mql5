# RSIH Professional (RSI with Hann Windowing)

## 1. Summary (Introduction)

The RSIH, or "RSI with Hann Windowing," is John Ehlers' innovative take on the classic Relative Strength Index. It introduces two fundamental improvements to address what Ehlers considered shortcomings of the original RSI: its lack of a zero-mean and its inherent noisiness.

The RSIH modifies the standard RSI in two key ways:

1. **Zero-Mean Scaling:** The output is mathematically transformed from the traditional 0-100 scale to a **-1 to +1 scale**. On this new scale, +1 represents maximum bullish momentum, -1 represents maximum bearish momentum, and 0 is the point of perfect equilibrium.
2. **Hann Windowing:** Instead of a simple summation of price changes (like a Simple Moving Average), the RSIH uses a **Hann windowing function** to calculate the "Closes Up" (CU) and "Closes Down" (CD) components. This is a cosine-based weighting method that gives more importance to the data in the middle of the lookback period and less to the newest and oldest data.

The result is an oscillator that is significantly **smoother** than the classic RSI, with the smoothing being an intrinsic part of the calculation itself, rather than an afterthought.

## 2. Mathematical Foundations and Calculation Logic

The RSIH is a Finite Impulse Response (FIR) filter applied to price changes, which is then scaled to a bipolar output.

### Required Components

* **Period (N):** The lookback period for the calculation.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

For each bar, the indicator looks back over the last `N` periods.

1. **Calculate Price Differences:** For each bar within the `N`-period window, calculate the difference from the previous bar: $\text{diff} = P_i - P_{i-1}$.
2. **Calculate Hann Window Weight:** For each position `j` within the window (from 1 to N), calculate the corresponding Hann weight:
    $W_j = 1 - \cos\left(\frac{2\pi \times j}{N+1}\right)$
3. **Calculate Weighted CU and CD:** Sum the positive and negative price differences, multiplied by their respective Hann weights.
    * $\text{CU} = \sum_{j=1}^{N} (\text{if diff}_j > 0, \text{diff}_j \times W_j, \text{else } 0)$
    * $\text{CD} = \sum_{j=1}^{N} (\text{if diff}_j < 0, |\text{diff}_j| \times W_j, \text{else } 0)$
4. **Calculate Final RSIH Value:** Apply Ehlers' zero-mean transformation:
    $\text{RSIH} = \frac{\text{CU} - \text{CD}}{\text{CU} + \text{CD}}$

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`RSIH_Calculator.mqh`):** The entire calculation, including the Hann-windowed summation, is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **FIR-based Logic:** Unlike the classic Wilder's RSI which uses a recursive (IIR) smoothing, the RSIH is a non-recursive (FIR) filter. This means its calculation at any given bar depends only on the last `N` price changes, giving it a finite "memory."
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure stability and accuracy.

## 4. Parameters

* **RSI Period (`InpPeriodRSI`):** The lookback period (`N`) for the calculation.
  * Ehlers notes that due to the nature of Hann windowing, a **longer period** may be required to achieve the same level of smoothing as a traditional RSI. A good starting point is **14**, but experimenting with longer periods (e.g., 21 or 28) can yield a smoother, clearer signal.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The RSIH is used in a similar way to a traditional RSI, but its signals are often cleaner and its zero-mean nature provides a clear momentum baseline.

### **1. Overbought / Oversold Zones**

Instead of 70/30, the key levels are on the -1 to +1 scale. Common levels are **+0.5 / -0.5** or, for more extreme signals, **+0.8 / -0.8**.

* **Buy Signal:** The indicator line crosses up from below the oversold level (e.g., -0.5).
* **Sell Signal:** The indicator line crosses down from above the overbought level (e.g., +0.5).
* **Best Use:** This strategy works best in **ranging or consolidating markets**.

### **2. Zero-Line Crossover (Trend Filter)**

The zero line is the equilibrium point.

* **Bullish Momentum:** When the RSIH is **above 0**, momentum is considered bullish.
* **Bearish Momentum:** When the RSIH is **below 0**, momentum is considered bearish.
* A cross of the zero line can be used as a confirmation of a change in the short-term trend.

### **3. Divergence**

Due to its smoothness, divergences can be easier to spot on the RSIH than on a classic RSI.

* **Bullish Divergence:** Price makes a **new lower low**, but the RSIH makes a **higher low**. This indicates weakening sell pressure.
* **Bearish Divergence:** Price makes a **new higher high**, but the RSIH makes a **lower high**. This indicates weakening buy pressure.
