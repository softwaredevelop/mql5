# Cyber Cycle Professional

## 1. Summary (Introduction)

The Cyber Cycle, developed by John Ehlers, is a unique indicator designed to isolate and display the short-term cyclical components of price action. Unlike momentum oscillators like the RSI, which measure the strength of price moves, the Cyber Cycle acts as a **band-pass filter** to remove trend and high-frequency noise, revealing the underlying "heartbeat" or rhythm of the market.

The output is a smooth, sine-wave-like oscillator whose amplitude (height of the swings) varies with the strength of the cycles. Its primary purpose is not to measure overbought/oversold levels, but to **time the turning points** of these short-term cycles.

The indicator plots two lines:

* **Cycle Line:** The main filtered value.
* **Signal Line:** The Cycle line delayed by two bars, used for generating crossover signals.

## 2. Mathematical Foundations and Calculation Logic

The indicator uses a two-pole Butterworth band-pass filter to isolate the cyclical component of the price.

### Required Components

* **Alpha (α):** A smoothing factor that determines the center frequency of the band-pass filter (i.e., the length of the cycles it is most sensitive to).
* **Source Price (P):** The price series used for the calculation (Ehlers' original work uses the Median Price `(H+L)/2`).

### Calculation Steps (Algorithm)

1. **Pre-Smoothing:** The source price is first lightly smoothed using a 4-bar weighted FIR filter `(P + 2*P[1] + 2*P[2] + P[3]) / 6`. This reduces some of the extreme noise before the main filter is applied.
2. **Cycle Calculation:** The core of the indicator is a recursive Butterworth filter applied to the smoothed price. The formula calculates the current `Cycle` value based on the change in the smoothed price and the two previous `Cycle` values:
    $\text{Cycle}_i = (1 - 0.5\alpha)^2 \times (\text{Smooth}_i - 2\text{Smooth}_{i-1} + \text{Smooth}_{i-2}) + 2(1-\alpha)\text{Cycle}_{i-1} - (1-\alpha)^2\text{Cycle}_{i-2}$
3. **Signal Line Generation:** The Signal Line is simply the Cycle line's value from two bars prior:
    $\text{Signal}_i = \text{Cycle}_{i-2}$

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`Cyber_Cycle_Calculator.mqh`):** The entire multi-stage, recursive calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** The calculation is highly state-dependent. To ensure absolute stability and prevent desynchronization, the indicator employs a **full recalculation** on every `OnCalculate` call. This is the most robust method for this type of recursive filter.
* **Robust Initialization:** The calculator includes a simplified, non-recursive calculation for the first few bars to provide a stable "warm-up" period for the main filter, as described in Ehlers' work.

## 4. Parameters

* **Alpha (`InpAlpha`):** The smoothing factor for the Butterworth filter. Ehlers' recommendation and a robust starting point is **0.07**.
  * A lower value (e.g., 0.05) will tune the filter to longer cycles, resulting in a smoother, slower indicator.
  * A higher value (e.g., 0.10) will tune the filter to shorter cycles, resulting in a faster, more volatile indicator.
* **Source (`InpSource`):** Selects between `Standard` and `Heikin Ashi` candles. The Median Price of the selected candle type will be used.

## 5. Usage and Interpretation

The Cyber Cycle is a **timing tool for cycle reversals**. Its signals are most powerful when used in conjunction with a separate trend-following indicator.

### **1. Signal Line Crossover (Primary Strategy)**

This is the most direct way to use the indicator for entry signals.

* **Buy Signal:** The **blue Cycle line crosses above the red Signal line**. This indicates that the cycle has turned up from a bottom. The signal is strongest when the crossover occurs below the zero line.
* **Sell Signal:** The **blue Cycle line crosses below the red Signal line**. This indicates that the cycle has turned down from a top. The signal is strongest when the crossover occurs above the zero line.

### **CRITICAL RULE: Always Use with a Trend Filter**

The Cyber Cycle is **not a trend indicator**; by design, it removes the trend component to focus on cycles. Trading its signals against a strong trend is a low-probability strategy.

* **The Problem:** In a strong uptrend, the Cyber Cycle will still generate multiple "Sell" signals during minor pullbacks.
* **The Solution:** Add a long-term moving average (e.g., 100 or 200 EMA) to your main chart to define the overall trend.
  * **Uptrend Rule:** Only take **Buy signals** (Cycle crosses above Signal) when the price is **above** the long-term moving average.
  * **Downtrend Rule:** Only take **Sell signals** (Cycle crosses below Signal) when the price is **below** the long-term moving average.

By following this rule, the Cyber Cycle becomes an excellent tool for timing **trend-following entries** at the end of corrective pullbacks.
