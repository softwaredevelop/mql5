# Weis Wave Volume Pro Suite with Integrated SOT

## 1. Summary (Introduction)

The **Weis Wave Volume Pro Suite** is an institutional-grade quantitative trading suite comprising two advanced indicators: `WeisWave_Pro` (Standard) and `WeisWave_MTF_Pro` (Multi-Timeframe). Based on Richard Wyckoff's first law—**The Law of Supply and Demand**—and David Weis's wave mechanics, this suite aggregates volume along price waves (swing legs) rather than individual time-based bars.

In this upgraded version, the suite integrates a revolutionary **4-Color Momentum Exhaustion Layer (Shortening of the Thrust - SOT)**. It dynamically measures the vertical height (Thrust) of consecutive waves in real-time. If three consecutive waves show a progressive loss of vertical progress, the state machine retroactively re-colors the entire completed wave on the histogram in a distinct color, delivering a highly intuitive "Volume & Momentum Heatmap" in a single separate subwindow.

The entire suite features strict $O(1)$ incremental calculation efficiency, Heikin Ashi price source compatibility, and is guaranteed to never repaint, making it 100% reliable for live discretionary trading and automated Expert Advisors (EAs).

---

## 2. Mathematical Foundations and Wave Mechanics

The suite categorizes cumulative volume into a dynamic 4-color palette configuration:

1. **DodgerBlue Histogram (> 0):** Normal Demand Wave (Up swing).
2. **Crimson Histogram (< 0):** Normal Supply Wave (Down swing).
3. **Orange Histogram (> 0):** Exhausted Demand Wave (Bearish SOT detected).
4. **Fuchsia Histogram (< 0):** Exhausted Supply Wave (Bullish SOT detected).

### A. ATR-Based Dynamic Swing Legs

The market swing direction ($D_t$) is tracked dynamically using a multiplier $M$ (`InpMultiplier`) of the Average True Range (ATR):

$$\text{Threshold}_t = M \times \text{ATR}_t$$

* **Up Swing to Down Swing Reversal:** Triggers when the price drops below the wave's peak high minus the threshold:
  $$C_t < \max(H_{\text{wave}}) - \text{Threshold}_t$$
* **Down Swing to Up Swing Reversal:** Triggers when the price rises above the wave's trough low plus the threshold:
  $$C_t > \min(L_{\text{wave}}) + \text{Threshold}_t$$

### B. Vertical Wave Length Calculation

The vertical height (Thrust) of each completed wave is calculated as the absolute distance in points between its peak and trough:

$$\text{Up Wave Length} = \text{Peak High} - \text{Previous Trough Low}$$

$$\text{Down Wave Length} = \text{Previous Peak High} - \text{Trough Low}$$

### C. Sequential SOT Detection

An SOT signal is triggered when a sequence of three consecutive completed waves in the same direction shows a continuous, progressive decrease in vertical progress:

$$\text{Length}_{\text{Current}} < \text{Length}_{\text{Previous}} < \text{Length}_{\text{Before-Previous}}$$

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`WeisWave_Calculator.mqh`):**
  All wave tracking, height calculations, and SOT logic are encapsulated inside `CWeisWaveCalculator`. It maintains persistent state variables (Direction, Peak High, Peak Low, and Wave Length) in internal arrays, isolating calculations from chart rendering.

* **Retroactive Wave Coloring Algorithm:**
  When a wave reversal occurs, if `InpShowSOT` is enabled, the calculator runs a backward-search pass (`GetLastCompletedLengths`) through locked historical state arrays. If an SOT is verified, the calculator instantly loops backwards and changes the color index of the entire completed wave from standard colors to Orange (Bearish SOT) or Fuchsia (Bullish SOT). This visual update runs strictly in $O(1)$ time, maintaining ultra-low CPU latency.

* **100% Non-Repainting and EA-Compatible:**
  Traditional Zigzag-based indicators recalculate past bars when a new high/low is made, making them useless for automated trading. `WeisWave_Pro` locks all wave states into historical arrays once a bar closes. SOT highlighted waves are permanently locked in history and never repaint, making the indicator 100% reliable for Expert Advisors (EAs).

* **Strict $O(1)$ Real-Time Tick Optimization:**
  To support live-updating while preserving performance, the indicator computes only the **current live bar** (index `rates_total - 1`) on every tick. This keeps CPU usage at absolute zero, allowing the wave volume to tick-by-tick accumulate live in real-time.

---

## 4. Parameters

* **ATR Period (`InpATRPeriod`):** The lookback period used to calculate the dynamic Average True Range (Default: `14` bars).
* **Multiplier (`InpMultiplier`):** The number of ATRs required to trigger a wave reversal (Default: `2.5`). Lower values (e.g. `2.0` on M3) capture micro-swings; higher values (e.g. `3.0` on H1) filter out intraday consolidations.
* **Show SOT (`InpShowSOT`):** Toggle to highlight SOT momentum exhaustion waves in Orange/Fuchsia directly on the histogram.

---

## 5. Advanced Wyckoffian & VSA Trading Strategies

The integrated 4-color hőtérkép provides traders with a unified window to execute Wyckoffian market laws:

### A. Trading the SOT Reversal at the "Danger Point"

Wyckoff stated that successful trading involves entering at the "danger point"—the exact price level where your potential loss is minimal and the profit potential is maximum [1].

* **Bullish Setup:** Monitor a falling market. If the active Crimson wave (Supply) turns **Fuchsia** (Bullish SOT), it proves that sellers have exhausted.
* **Entry:** Place a buy limit or enter at the open of the next bar.
* **Stop Loss:** Place your stop loss exactly 1-2 pips below the wave's trough low. Since this is the absolute mathematical trough, if the price drops below it, the SOT setup is invalidated. The risk is extremely small!

### B. Spring and Upthrust Confirmation

SOT waves are highly effective for validating false breakouts of trading ranges:

* **Spring Validation:** If the price breaks below a major support level (Spring) and the corresponding Crimson wave turns **Fuchsia** (SOT), it proves that the breakout lacks institutional supply. The breakdown is a retail trap. Go **Long** immediately as soon as the price closes back inside the range.
* **Upthrust Validation:** If the price breaks above a major resistance level (Upthrust) and the corresponding DodgerBlue wave turns **Orange** (SOT), it proves that the breakout lacks institutional demand. Go **Short** immediately as soon as the price closes back inside the range.

### C. Volume Climax vs. No Supply / No Demand

By combining wave height and cumulative volume on the SOT-highlighted waves, traders can distinguish between two distinct climax behaviors:

* **No Supply / No Demand (Exhaustion):** If the third (Orange/Fuchsia) wave in the sequence shows a **significant drop in volume** compared to the first wave, it is a low-volume exhaustion. The market is reversing due to a complete lack of interest from the opposing force.
* **Buying / Selling Climax (Absorption):** If the third wave shows a **huge volume spike** but has the shortest height (high effort, small result), it represents high-volume absorption. Large institutional limit orders are absorbing the market flow, preparing for a massive, violent trend reversal.
