# Roofing Filter Professional

## 1. Summary (Introduction)

The Roofing Filter, developed by John Ehlers, is a sophisticated **band-pass filter** designed to "pre-condition" price data for use in other indicators, particularly oscillators. Its primary purpose is to solve two fundamental problems with raw market data:

1. **Spectral Dilation (Trend):** It removes the slow-moving, long-period trend components from the price data using a two-pole **High-Pass Filter**. This prevents oscillators (like the Stochastic) from getting "stuck" or "pinned" in overbought/oversold zones during strong trends.
2. **Aliasing Noise (Noise):** It removes the fast, high-frequency noise from the price data using a **SuperSmoother Filter**. This results in a much cleaner, smoother input for subsequent indicator calculations.

The output of the Roofing Filter is a smooth, zero-mean oscillator that represents the **tradable, mid-range cycles** of the market. It can be used as a standalone cycle indicator, but its main purpose is to serve as a superior data source for other classic indicators.

## 2. Mathematical Foundations and Calculation Logic

The Roofing Filter is constructed by applying two of Ehlers' other filters in series.

### Calculation Steps (Algorithm)

1. **High-Pass Filtering:** The source price is first passed through a **two-pole High-Pass Filter**. This filter is defined by the `High-Pass Period` and its purpose is to remove the slow, long-term trend components. The formula is:
    $\text{HP}_i = (1 - \frac{\alpha}{2})^2 (P_i - 2P_{i-1} + P_{i-2}) + 2(1-\alpha)\text{HP}_{i-1} - (1-\alpha)^2\text{HP}_{i-2}$
2. **Low-Pass Filtering (Smoothing):** The output of the High-Pass filter (`HP`) is then immediately used as the input for a **SuperSmoother Filter**. This second filter is defined by the `SuperSmoother Period` and its purpose is to remove the high-frequency noise.

The final output is the smoothed, detrended price data, representing the market's primary cyclical activity.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`Roofing_Filter_Calculator.mqh`):** The entire two-stage, recursive calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** The calculation involves two chained, state-dependent filters. To ensure absolute stability, the indicator employs a **full recalculation** on every `OnCalculate` call.

## 4. Parameters

* **High-Pass Period (`InpHighPassPeriod`):** The period for the initial High-Pass filter. This determines the **longest** cycles that will be filtered out (i.e., the trend). Ehlers' recommendation is **48**.
* **SuperSmoother Period (`InpSuperSmootherPeriod`):** The period for the final SuperSmoother filter. This determines the **shortest** cycles (noise) that will be filtered out. Ehlers' recommendation is **10**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The Roofing Filter has two primary use cases.

### 1. As a Standalone Cycle Oscillator

The output line itself is a zero-mean oscillator that shows the market's cycles.

* **Turning Points:** The peaks and troughs of the Roofing Filter line identify the turning points of the mid-range market cycles.
* **Zero-Line Crosses:** A cross of the zero line indicates a shift in cyclical momentum.

### 2. As a Pre-Filter for Other Indicators (Primary Use)

This is the indicator's main purpose. By applying another indicator (like an RSI or Stochastic) to the Roofing Filter's output instead of the raw price, you can create a significantly improved version of that classic indicator.

**How to Apply an Indicator to the Roofing Filter:**

1. Place the `Roofing_Filter_Pro` indicator on your chart.
2. Open the "Navigator" window (Ctrl+N).
3. Find the indicator you want to apply (e.g., the built-in "Relative Strength Index").
4. **Click and drag** the RSI from the Navigator **directly onto the Roofing Filter's sub-window**.
5. In the RSI's "Parameters" tab, set the **"Apply to"** dropdown menu to **"Previous Indicator's Data"**.
6. Click "OK".

The RSI will now be calculated on the smoothed, detrended output of the Roofing Filter, resulting in a zero-mean RSI that is free from trend-based distortion.
