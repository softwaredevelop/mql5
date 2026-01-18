# MACD Laguerre Pro Suite

## 1. Summary (Introduction)

The **MACD Laguerre Pro Suite** is a comprehensive set of indicators that modernizes the classic MACD by replacing traditional Exponential Moving Averages (EMAs) with John Ehlers' superior **Laguerre Filters**.

Laguerre filters offer a significant advantage: they are extremely responsive and have minimal lag compared to standard averages. This results in a MACD system that reacts faster to price changes, produces smoother signals, and clearly visualizes market cycles.

The suite consists of four professional-grade indicators, designed to work together:

1. **`MACD_Laguerre_Pro`:** The complete package. Displays the MACD Line, Signal Line, and Histogram in a separate window. Ideal for standard use.
2. **`MACD_Laguerre_Line_Pro`:** Displays only the MACD Line. Designed as a clean base for traders who want to experiment by dragging and dropping custom moving averages onto the line.
3. **`MACD_Laguerre_Histogram_Pro`:** Displays only the Histogram. Useful for creating custom visual layouts or when stacking multiple indicators.
4. **`MACD_Laguerre_Chart_Overlay`:** Displays the two underlying Laguerre Filters (Fast and Slow) directly on the price chart. This visualizes the "raw components" of the MACD calculation.

## 2. Mathematical Foundations

The core logic remains faithful to the MACD concept but upgrades the components:

1. **MACD Line:** The difference between a Fast and a Slow Laguerre Filter.
    * $\text{MACD Line}_t = \text{Laguerre}(P, \gamma_{fast})_t - \text{Laguerre}(P, \gamma_{slow})_t$
    * The speed is controlled by the **Gamma** ($\gamma$) factor ($0.0 - 1.0$). Lower gamma = faster filter.

2. **Signal Line:** A smoothed version of the MACD Line.
    * Our suite allows this smoothing to be a standard MA (SMA, EMA, etc.) OR another Laguerre Filter.

3. **Histogram:** The difference between the MACD Line and the Signal Line.
    * $\text{Histogram}_t = \text{MACD Line}_t - \text{Signal Line}_t$

## 3. MQL5 Implementation Details

* **Unified Calculator Engine:** All oscillator indicators share a single, robust engine (`MACD_Laguerre_Calculator.mqh`). The Chart Overlay uses the base `Laguerre_Engine.mqh` directly.
* **O(1) Incremental Calculation:** The indicators are optimized for high performance. They process only new bars (`prev_calculated`), ensuring zero lag and minimal CPU usage.
* **Heikin Ashi Integration:** Built-in support for all Heikin Ashi price types. The calculation engine automatically handles the transformation of raw price data into Heikin Ashi values before processing.

## 4. Parameters

### Laguerre MACD Settings (Common)

* **Gamma 1 (Fast):** The coefficient for the fast filter (e.g., 0.2).
* **Gamma 2 (Slow):** The coefficient for the slow filter (e.g., 0.8).
* **Price Source:** Selects the input data (Standard or Heikin Ashi).

### Signal Line Settings (Oscillators Only)

* **Signal MA Type:** Selects the smoothing method for the Signal Line.
  * **`SMOOTH_Laguerre`:** Uses a Laguerre filter (controlled by `Signal Gamma`).
  * **Standard MAs:** SMA, EMA, SMMA, LWMA, TMA, DEMA, TEMA (controlled by `Signal Period`).
* **Signal Period:** Lookback period for standard MA types.
* **Signal Gamma:** Gamma factor for the Laguerre signal type.

## 5. Usage and Interpretation

### Signal Line Crossover (Oscillator Window)

* **Buy:** When the MACD Line (Blue) crosses **above** the Signal Line (Red).
* **Sell:** When the MACD Line crosses **below** the Signal Line.

### Zero Line Crossover & Chart Overlay

* **Oscillator:** Crossing the zero line indicates a shift in trend direction.
* **Chart Overlay:** This corresponds exactly to the **crossover of the Fast and Slow Laguerre lines** on the price chart.
  * **Fast > Slow:** Bullish Trend (MACD > 0).
  * **Fast < Slow:** Bearish Trend (MACD < 0).
  * *Visual Tip:* The gap between the two lines on the chart represents the magnitude of the MACD value.

### Histogram Analysis

* **Momentum:** Growing histogram bars indicate accelerating momentum. Shrinking bars warn of a potential slowdown or reversal.
* **Divergence:** Divergences between the histogram peaks and price action are powerful reversal signals.
