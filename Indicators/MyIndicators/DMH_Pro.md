# DMH Professional (Directional Movement with Hann Windowing)

## 1. Summary (Introduction)

The DMH (Directional Movement with Hann Windowing) is John Ehlers' modern re-interpretation of J. Welles Wilder's classic Directional Movement concept. Ehlers' goal was to "freshen up" the original DMI/ADX system for modern algorithmic trading by removing what he considered redundant components and improving the filtering method.

Instead of the traditional three-line ADX system (+DI, -DI, ADX), the DMH produces a **single, smooth oscillator** that fluctuates around a zero line. This line directly represents the **balance between bullish (PlusDM) and bearish (MinusDM) pressure**.

* When the DMH is **above zero**, upward directional movement is dominant.
* When the DMH is **below zero**, downward directional movement is dominant.

The indicator uses a sophisticated two-stage smoothing process, combining an EMA with a Hann-windowed FIR filter to create a much cleaner, lower-noise signal than the classic +DI/-DI lines.

## 2. Mathematical Foundations and Calculation Logic

The DMH indicator transforms the raw Directional Movement values into a single, heavily smoothed oscillator.

### Required Components

* **Period (N):** The lookback period for both smoothing stages.
* **Source Price:** The `High` and `Low` of each bar.

### Calculation Steps (Algorithm)

1. **Calculate Raw Directional Movement (DM):** For each bar, calculate the classic `PlusDM` and `MinusDM` values based on the change in highs and lows relative to the previous bar.
2. **Calculate DM Difference:** Instead of normalizing with ATR, Ehlers immediately takes the difference:
    $\text{DM Diff}_i = \text{PlusDM}_i - \text{MinusDM}_i$
3. **First Smoothing (EMA):** The raw `DM Diff` series is smoothed with an Exponential Moving Average (EMA) of period `N`.
4. **Second Smoothing (Hann FIR Filter):** The resulting EMA series is then smoothed again using a **Hann-windowed Finite Impulse Response (FIR) filter** of period `N`. This is a weighted moving average where the weights are derived from a cosine function (the Hann window), which provides superior smoothing compared to a simple average.
5. **Final Output:** The result of this second smoothing is the final DMH line.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`DMH_Calculator.mqh`):** The entire multi-stage calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the initial `PlusDM` and `MinusDM` calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Two-Stage Smoothing:** The calculator accurately implements the two distinct smoothing phases: a recursive EMA followed by a non-recursive, weighted FIR filter.
* **Stability via Full Recalculation:** The indicator employs a full recalculation on every `OnCalculate` call to ensure the stateful EMA calculation and the FIR filter are always perfectly synchronized and stable.

## 4. Parameters

* **Period (`InpPeriod`):** The lookback period (`N`) used for both the initial EMA and the final Hann FIR filter. The default, as in Wilder's original work, is **14**.
  * A shorter period will result in a faster, more volatile oscillator.
  * A longer period will result in a smoother, slower oscillator that only reflects major momentum shifts.
* **Source (`InpSource`):** Selects between `Standard` and `Heikin Ashi` candles for the initial DM calculation.

## 5. Usage and Interpretation

The DMH is a momentum oscillator used to identify the dominant directional pressure and its turning points. Ehlers suggests two ways to interpret its signals.

### **1. Zero-Line Crossover (Trend Direction)**

This is the most basic signal, similar in concept to a +DI/-DI crossover.

* **Buy Signal / Bullish Bias:** The DMH line crosses **above the zero line**. This indicates that bullish pressure is now stronger than bearish pressure.
* **Sell Signal / Bearish Bias:** The DMH line crosses **below the zero line**. This indicates that bearish pressure has taken control.
* **Note:** Ehlers points out that these signals have a natural lag and are better used for confirmation rather than primary entry triggers.

### **2. Peaks and Valleys (Timing Reversals - Ehlers' Preferred Method)**

This method uses the turning points of the smooth DMH line to anticipate reversals in momentum.

* **Buy Signal (Valley):** A **trough or valley** in the DMH line (especially below the zero line) indicates that bearish momentum has reached its peak and is exhausting. A turn upwards from a valley is a potential buy signal.
* **Sell Signal (Peak):** A **peak or crest** in the DMH line (especially above the zero line) indicates that bullish momentum is exhausting. A turn downwards from a peak is a potential sell signal.

### **Important Consideration: Use with a Trend Filter**

Like most oscillators, the DMH is most effective when its signals are filtered by the primary trend.

* **Uptrend Rule:** In a clear uptrend (e.g., price is above a 200-period EMA), focus on **Buy signals** (valleys in the DMH) as potential entry points during pullbacks.
* **Downtrend Rule:** In a clear downtrend, focus on **Sell signals** (peaks in the DMH) as potential entry points during corrective rallies.
