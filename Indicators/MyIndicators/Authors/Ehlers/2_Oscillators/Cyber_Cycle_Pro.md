# Cyber Cycle Pro

## 1. Summary (Introduction)

The **Cyber Cycle Pro**, developed by John Ehlers, is a unique indicator designed to isolate and display the short-term cyclical components of price action. Unlike momentum oscillators like the RSI, which measure the strength of price moves, the Cyber Cycle acts as a **band-pass filter** to remove trend and high-frequency noise, revealing the underlying "heartbeat" or rhythm of the market.

The output is a smooth, sine-wave-like oscillator whose amplitude varies with the strength of the cycles. Its primary purpose is not to measure overbought/oversold levels, but to **time the turning points** of these short-term cycles.

The indicator plots two lines:

* **Cycle Line:** The main filtered value.
* **Signal Line:** The Cycle line delayed by one bar, used for generating crossover signals.

## 2. Mathematical Foundations

The indicator uses a two-pole Butterworth band-pass filter to isolate the cyclical component of the price.

### Calculation Steps

1. **Pre-Smoothing:** The source price is first lightly smoothed using a 4-bar weighted FIR filter `(P + 2*P[1] + 2*P[2] + P[3]) / 6`. This reduces noise before the main filter is applied.
2. **Cycle Calculation:** The core is a recursive Butterworth filter applied to the smoothed price.
    * $\text{Cycle}_i = (1 - 0.5\alpha)^2 \times (\text{Smooth}_i - 2\text{Smooth}_{i-1} + \text{Smooth}_{i-2}) + 2(1-\alpha)\text{Cycle}_{i-1} - (1-\alpha)^2\text{Cycle}_{i-2}$
3. **Signal Line Generation:** The Signal Line is the Cycle line's value from the previous bar:
    * $\text{Signal}_i = \text{Cycle}_{i-1}$

## 3. MQL5 Implementation Details

* **O(1) Incremental Calculation:** Optimized for high performance. The indicator processes only new bars (`prev_calculated`), ensuring zero lag and minimal CPU usage.
* **Stateful Engine (`Cyber_Cycle_Calculator.mqh`):** The calculation logic is encapsulated in a stateful class that persists intermediate values (`m_smooth`, `m_cycle`) between ticks.
* **Heikin Ashi Integration:** Built-in support for all Heikin Ashi price types.

## 4. Parameters

* **Alpha (`InpAlpha`):** The smoothing factor for the Butterworth filter. Ehlers' recommendation is **0.07**.
  * Lower value (e.g., 0.05) = Smoother, slower (longer cycles).
  * Higher value (e.g., 0.10) = Faster, more volatile (shorter cycles).
* **Source Price (`InpSourcePrice`):** Selects the input data. Default is `PRICE_MEDIAN_STD` (Median Price), as recommended by Ehlers.

## 5. Usage and Interpretation

The Cyber Cycle is a **timing tool for cycle reversals**.

### Signal Line Crossover

* **Buy Signal:** The **Cycle line crosses above the Signal line**. This indicates the cycle has turned up.
* **Sell Signal:** The **Cycle line crosses below the Signal line**. This indicates the cycle has turned down.

### Trend Filter Rule (Critical)

The Cyber Cycle removes the trend component. Therefore, trading its signals against a strong trend is risky.

* **Uptrend:** Only take **Buy signals** when price is above a long-term MA (e.g., 200 EMA).
* **Downtrend:** Only take **Sell signals** when price is below a long-term MA.
