# Correlation Trend Professional

## 1. Summary (Introduction)

The Correlation Trend Indicator, developed by John Ehlers, is a unique oscillator that measures the strength and direction of a trend in a purely statistical manner. Instead of using traditional moving averages or momentum calculations, it directly answers the question: **"How closely has the price action of the last N bars resembled a perfect, straight-line trend?"**

The indicator calculates the **Pearson correlation** between the price series and a simple, monotonically changing time index over a specified period. The result is a smooth oscillator bounded between -1 and +1.

* A value near **+1** indicates a strong, consistent **uptrend**.
* A value near **-1** indicates a strong, consistent **downtrend**.
* A value near **0** indicates a **sideways or choppy market** with no clear linear trend.

This provides a very "honest" and direct assessment of the market's trendiness, free from the complexities of many other indicators.

## 2. Mathematical Foundations and Calculation Logic

The indicator is a direct application of the Pearson correlation coefficient formula.

### Required Components

* **Period (N):** The lookback period for the correlation calculation.
* **Source Price (P):** The price series to be analyzed.
* **Time Index (T):** A simple, linearly changing series (e.g., 1, 2, 3, ..., N).

### Calculation Steps (Algorithm)

For each bar, the indicator looks back over the last `N` periods and performs the following steps:

1. **Define Data Sets:** Create two data sets: `X` (the price series) and `Y` (the time index series).
2. **Calculate Sums:** Compute the five core sums required for the Pearson formula:
    * Sum of X (`Sx`)
    * Sum of Y (`Sy`)
    * Sum of X*X (`Sxx`)
    * Sum of Y*Y (`Syy`)
    * Sum of X*Y (`Sxy`)
3. **Apply Correlation Formula:** The final correlation value is calculated using the standard formula:
    $\text{Corr} = \frac{N \times Sxy - Sx \times Sy}{\sqrt{(N \times Sxx - Sx^2) \times (N \times Syy - Sy^2)}}$

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`Correlation_Trend_Calculator.mqh`):** The entire statistical calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **FIR-based Logic:** This is a non-recursive (FIR) filter. Its calculation at any given bar depends only on the last `N` prices.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure stability and accuracy.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) for the correlation calculation. This is the most important parameter and should be aligned with your trading horizon.
  * **Short Periods (e.g., 10-20):** More sensitive, useful for identifying short-term swings and cycle turning points.
  * **Long Periods (e.g., 40-60):** Smoother, useful for identifying longer-term, established trends.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The Correlation Trend indicator is a versatile tool for both trend identification and cycle timing.

### **1. Trend Identification and Strength**

This is the primary use case. The indicator's level provides a clear gauge of the trend.

* **Strong Uptrend:** The indicator is consistently above a high threshold (e.g., +0.6).
* **Strong Downtrend:** The indicator is consistently below a low threshold (e.g., -0.6).
* **Ranging Market:** The indicator oscillates around the zero line, indicating a lack of a clear, sustained trend.

### **2. Trend Reversal Confirmation (Zero-Line Cross)**

A cross of the zero line signals a change in the dominant trend over the lookback period.

* **Buy Signal:** The indicator crosses **above the zero line**, confirming that the market has shifted from a downtrend/range into an uptrend.
* **Sell Signal:** The indicator crosses **below the zero line**, confirming a shift to a downtrend.
* **Note:** These are lagging, confirming signals, not leading ones.

### **3. Cycle Timing (with Shorter Periods)**

When a shorter period is used (e.g., 10-20 on an intraday chart), the indicator acts as a smooth oscillator.

* **Buy Signal:** A turn upwards from a trough in the negative territory.
* **Sell Signal:** A turn downwards from a peak in the positive territory.
* This is best used in conjunction with a longer-term trend filter, taking signals only in the direction of the main trend.
