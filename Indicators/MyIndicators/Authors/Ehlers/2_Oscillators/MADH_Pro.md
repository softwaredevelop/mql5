# MADH Professional (Moving Average Difference - Hann)

## 1. Summary (Introduction)

The MADH (Moving Average Difference - Hann), developed by John Ehlers, is his answer to the classic MACD indicator, which he calls "A Thinking Man's MACD." It improves upon the traditional MACD concept in two fundamental ways:

1. **Rational Period Selection:** Instead of using arbitrary, fixed periods (like 12 and 26), the periods of the two moving averages in MADH are logically derived from a user-defined **short length** and the **dominant cycle period** of the market. This aims to tune the indicator to the market's current rhythm.
2. **Superior Smoothing:** Instead of using standard Exponential Moving Averages (EMAs), the MADH uses two **Hann-windowed Moving Averages (HWMAs)**. A HWMA is a superior FIR filter that provides significantly more smoothing than an SMA or EMA of the same length, resulting in a much cleaner output signal.

The result is a single, zero-mean oscillator that is smoother than a traditional MACD and whose parameters are logically tied to market structure, not arbitrary historical convention.

## 2. Mathematical Foundations and Calculation Logic

The MADH is the percentage difference between a fast and a slow Hann-windowed Moving Average.

### Required Components

* **Short Length (N):** The period for the faster HWMA.
* **Dominant Cycle (C):** The estimated dominant cycle period of the market.
* **Source Price (P):** The price series used for the calculation.

### Calculation Steps (Algorithm)

1. **Calculate Long Length:** The period for the slower HWMA is calculated from the inputs:
    $\text{Long Length} = N + \text{Integer}(\frac{C}{2})$
2. **Calculate Fast HWMA (`Filt1`):** A Hann-windowed Moving Average is calculated on the source price using the `Short Length`.
3. **Calculate Slow HWMA (`Filt2`):** A second Hann-windowed Moving Average is calculated on the source price using the `Long Length`.
4. **Calculate Final MADH Value:** The final indicator value is the percentage difference between the two HWMAs.
    $\text{MADH} = 100 \times \frac{\text{Filt1} - \text{Filt2}}{|\text{Filt2}|}$

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`MADH_Calculator.mqh`):** The entire calculation, including the two internal HWMA computations, is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **FIR-based Logic:** The HWMA is a non-recursive (FIR) filter. The entire indicator has a finite "memory" defined by the `LongLength`.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure stability and accuracy.

## 4. Parameters

* **Short Length (`InpShortLength`):** The period for the faster HWMA. Ehlers' default is **8**.
* **Dominant Cycle (`InpDominantCycle`):** The estimated dominant cycle period of the market, used to calculate the period of the slower HWMA. Ehlers' example uses **27**. This is the primary parameter for tuning the indicator to a specific market or timeframe.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The MADH is a **trend-following momentum oscillator**. It is best used to identify the strength and direction of momentum, and particularly for spotting divergences that signal momentum exhaustion.

### **1. Zero-Line Crossover (Trend Confirmation)**

This is the most basic signal, similar to a MACD crossover.

* **Buy Signal / Bullish Bias:** The MADH line crosses **above the zero line**. This confirms that short-term momentum has become stronger than long-term momentum, suggesting an uptrend is in place.
* **Sell Signal / Bearish Bias:** The MADH line crosses **below the zero line**, confirming a downtrend.
* **Note:** These are lagging, confirming signals, best used to verify a new trend after a breakout.

### **2. Divergence (Primary Reversal Signal)**

This is the most powerful way to use the MADH, as its smoothness makes divergences very clear.

* **Bullish Divergence:** The price makes a **new lower low**, but the MADH makes a **higher low**. This is a strong indication that selling momentum is fading and a bullish reversal is likely.
* **Bearish Divergence:** The price makes a **new higher high**, but the MADH makes a **lower high**. This indicates that buying momentum is exhausting and a bearish reversal or significant pullback is imminent. This is often the most reliable signal for identifying a market top.

**How to Read the "Öntörvényű" (Self-Willed) Behavior:**
The MADH is not designed to pinpoint every single peak and trough. It is designed to measure **momentum**.

* When the indicator makes a **lower high** while the price makes a **higher high**, it is correctly signaling that the *force* behind the price rise is weakening, even if the price itself is still going up. This is not an inaccuracy; it is the core purpose of the indicator.
* Use the MADH to gauge the **health of a trend**. A series of rising peaks in the MADH confirms a strong uptrend. A series of lower peaks, even while the price is still rising, is a warning sign.
