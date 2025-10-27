# Ehlers High-Pass Filters Professional

## 1. Summary (Introduction)

This document describes two indicators based on John Ehlers' High-Pass (HP) filters: the **1-Pole High-Pass Filter** and the **2-Pole High-Pass Filter**.

A High-Pass filter is a "detrender." Its primary purpose is to remove the low-frequency (long-term trend) components from the price data, leaving only the higher-frequency, cyclical components. The result is a zero-mean oscillator that shows the market's short- to mid-term cycles without the distortion caused by an overarching trend.

These filters are powerful building blocks for more complex indicators (like the Roofing Filter or Band-Pass Filter), but they can also be used as standalone oscillators to analyze market cycles. We have implemented two versions:

1. **HighPass_1P_Pro:** A simple, fast, 1-pole version.
2. **HighPass_2P_Pro:** A more advanced, 2-pole version that provides superior trend removal and a smoother output.

## 2. Mathematical Foundations and Calculation Logic

Both filters are recursive IIR filters. The "number of poles" refers to the complexity of the filter and its ability to attenuate unwanted frequencies.

### 1-Pole High-Pass Filter

This is a simple filter that calculates the difference between the price and a slow-moving component. Its recursive formula is:
$\text{HP}_i = (\frac{1-\alpha}{2}) \times (P_i - P_{i-1}) + (1-\alpha) \times \text{HP}_{i-1}$

### 2-Pole High-Pass Filter

This is a more effective filter that squares the response of the 1-pole filter, resulting in a steeper attenuation of low frequencies (12 dB per octave vs. 6 dB). Its recursive formula is:
$\text{HP}_i = (\frac{1-\alpha}{2})^2 \times (P_i - 2P_{i-1} + P_{i-2}) + 2(1-\alpha)\text{HP}_{i-1} - (1-\alpha)^2\text{HP}_{i-2}$

In both cases, the `alpha` coefficient is derived from the user-selected `Period`.

## 3. MQL5 Implementation Details

* **Dedicated Calculators:** Each filter (`HighPass_1P_Pro` and `HighPass_2P_Pro`) has its own dedicated, self-contained calculator class for clarity and stability.
* **Heikin Ashi Integration:** Both calculators support calculation on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** Both indicators employ a full recalculation on every `OnCalculate` call to ensure the stateful, recursive calculations are always stable.

## 4. Parameters

* **Period (`InpPeriod`):** The cutoff period of the filter. This determines which cycles are considered "slow" (and are thus removed). A longer period will allow longer trends to pass through, while a shorter period will detrend the data more aggressively. A good starting point is **20** to **48**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

Both High-Pass filters are **cycle oscillators** used for timing and analysis.

### **1. Comparing the Two Versions**

* **HighPass_1P_Pro (1-Pole):** This version is faster and more responsive but also "noisier." It may not fully remove the influence of a strong trend.
* **HighPass_2P_Pro (2-Pole):** This version provides a **significantly smoother** output and is much more effective at removing the trend component. The resulting oscillator has a more stable zero mean and clearer cyclical swings. **For most applications, the 2-Pole version is the recommended choice.**

### **2. As a Standalone Oscillator**

* **Zero-Line Crosses:** A cross of the zero line indicates a shift in cyclical momentum.
* **Peaks and Valleys:** The turning points of the oscillator identify the tops and bottoms of the short-term market cycles.
* **Trend Filtering:** As with all detrending oscillators, it is crucial to use them in conjunction with a separate, long-term trend indicator. Only take buy signals (e.g., a valley turning up) when the main trend is bullish, and vice versa.

### **3. As a Building Block (Primary Use)**

The main purpose of these filters in Ehlers' work is to serve as the first stage for more advanced indicators. As we have implemented in our `Roofing_Filter_Pro`, a High-Pass filter's output can be fed into a smoothing filter (like a SuperSmoother) to create a clean, tradable Band-Pass oscillator.
