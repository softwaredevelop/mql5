# MADH Professional (Moving Average Difference - Hann)

## 1. Summary (Introduction)

The MADH (Moving Average Difference - Hann), developed by John Ehlers, is his answer to the classic MACD indicator, which he calls "A Thinking Man's MACD." It improves upon the traditional MACD concept in two fundamental ways:

1. **Rational Period Selection:** Instead of using arbitrary, fixed periods (like 12 and 26), the periods of the two moving averages in MADH are logically derived from a user-defined **short length** and the **dominant cycle period** of the market. This tunes the indicator to the market's current rhythm.
2. **Superior Smoothing:** Instead of using standard Exponential Moving Averages (EMAs), the MADH uses two **Hann-windowed Moving Averages (HWMAs)**. A HWMA is a superior FIR filter that provides significantly more smoothing than an SMA or EMA of the same length, resulting in a much cleaner output signal without extra lag.

The result is a single, zero-mean oscillator that is smoother than a traditional MACD and whose parameters are logically tied to market structure.

## 2. Mathematical Foundations and Calculation Logic

The MADH is the percentage difference between a fast and a slow Hann-windowed Moving Average.

### Required Components

* **Short Length ($N_s$):** The period for the faster HWMA.
* **Dominant Cycle ($D$):** The estimated dominant cycle period of the market.
* **Source Price ($P$):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Long Length:** The period for the slower HWMA is calculated to be exactly half a dominant cycle longer than the short length. This ensures the two averages are optimally spaced to capture the trend.
    $$ N_l = N_s + \text{round}(\frac{D}{2}) $$
2. **Calculate Fast HWMA (`Filt1`):** A Hann-windowed Moving Average is calculated using $N_s$.
3. **Calculate Slow HWMA (`Filt2`):** A second Hann-windowed Moving Average is calculated using $N_l$.
4. **Calculate Final MADH Value:** The final indicator value is the percentage difference between the two HWMAs.
    $$ \text{MADH} = 100 \times \frac{\text{Filt1} - \text{Filt2}}{\text{Filt2}} $$

## 3. MQL5 Implementation Details

* **Modular Architecture:** The indicator uses the **Composition Pattern**. It does not calculate the averages itself but orchestrates two instances of the `Windowed_MA_Calculator` engine. This ensures mathematical consistency with the overlay indicator.
* **Optimized Incremental Calculation (O(1)):**
    The indicator is highly optimized for performance. It uses `prev_calculated` to process only new bars, while the internal engines maintain their state and pre-calculated weights.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data via a Factory Pattern.

## 4. Parameters

* **Short Length (`InpShortLength`):** The period for the faster HWMA. Ehlers' default is **8**.
* **Dominant Cycle (`InpDominantCycle`):** The estimated dominant cycle period of the market. Ehlers' example uses **27**.
  * *Tip:* Use the `CyclePeriod_Pro` indicator to measure the current dominant cycle of your timeframe and input that value here.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The MADH is a **trend-following momentum oscillator**.

### **1. Peaks and Valleys (Early Reversal Signal)**

Ehlers specifically highlights this as the primary strength of the MADH. Because the Hann window produces such a smooth curve, the turning points are distinct.

* **Buy Signal:** The MADH line forms a distinct **valley (trough)** and turns up. This often happens *before* the zero-line cross.
* **Sell Signal:** The MADH line forms a distinct **peak** and turns down.

### **2. Zero-Line Crossover (Trend Confirmation)**

This is the classic MACD-style signal.

* **Bullish Trend:** The MADH line crosses **above the zero line**. This confirms that the fast trend is outpacing the slow trend.
* **Bearish Trend:** The MADH line crosses **below the zero line**.

### **3. Divergence**

* **Bullish Divergence:** Price makes a lower low, MADH makes a higher low.
* **Bearish Divergence:** Price makes a higher high, MADH makes a lower high.
