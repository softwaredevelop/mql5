# Weis Wave Volume Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Weis Wave Volume Pro Suite** is an institutional-grade quantitative trading suite comprising two advanced indicators: `WeisWave_Pro` (Standard) and `WeisWave_MTF_Pro` (Multi-Timeframe). Developed originally by David Weis, a legendary practitioner of the Wyckoff Method, this suite translates Richard Wyckoff's first law—**The Law of Supply and Demand**—into a highly objective, mathematical framework.

Unlike traditional volume indicators that measure volume on a candle-by-candle basis (introducing substantial noise), the `WeisWave_Pro` suite aggregates volume along price waves (swing legs). This allows traders to measure the true cumulative "buying effort" (Demand) versus "selling effort" (Supply) behind any market movement.

---

## 2. Mathematical Foundations and Wave Mechanics

The suite categorizes volume into two distinct waves:

* **Demand Wave (DodgerBlue Histogram > 0):** Aggregates volume during an active upward swing leg.
* **Supply Wave (Crimson Histogram < 0):** Aggregates volume during an active downward swing leg.

### A. Non-Repainting Stateful State Machine

Standard Weis Wave indicators are built on the classic ZigZag indicator, which continuously recalculates and "repaints" past waves as new price extremes are made. This makes them unusable for live automated execution.

The `WeisWave_Pro` suite solves this by implementing an ATR-based state machine. At each bar $t$, the indicator maintains persistent state variables (Direction, Peak High, Peak Low, and Cumulative Wave Volume) in separate internal arrays:

1. **Direction ($D_t$):** Current active swing direction ($1$ for Up, $-1$ for Down).
2. **Cumulative Volume ($V_{\text{cum}, t}$):** The running sum of volume since the last wave reversal.
3. **Peak Price ($P_{\text{peak}, t}$):** The highest high (for Up swings) or lowest low (for Down swings) achieved during the active wave.

### B. ATR-Based Dynamic Wave Reversals

Instead of using fixed tick-sizes, the reversal threshold is dynamically calculated using a multiplier $M$ (`InpMultiplier`) of the Average True Range (ATR):

$$\text{Threshold}_t = M \times \text{ATR}_t$$

* **Up Swing to Down Swing Reversal Condition:**
  If the active swing is Up ($D_{t-1} = 1$) and the current closing price falls below the peak high minus the threshold:
  $$C_t < \max(H_{t \dots t-L}) - \text{Threshold}_t$$
  The state machine triggers a **Down Swing Reversal**:
  $$D_t = -1 \quad \text{and} \quad V_{\text{cum}, t} = \text{Volume}_t$$

* **Down Swing to Up Swing Reversal Condition:**
  If the active swing is Down ($D_{t-1} = -1$) and the current closing price rises above the trough low plus the threshold:
  $$C_t > \min(L_{t \dots t-L}) + \text{Threshold}_t$$
  The state machine triggers an **Up Swing Reversal**:
  $$D_t = 1 \quad \text{and} \quad V_{\text{cum}, t} = \text{Volume}_t$$

Since all states are locked into historical arrays once a bar closes, **the history is guaranteed to never repaint**, making it 100% compatible with Expert Advisors and backtesting.

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`WeisWave_Calculator.mqh`):**
  All wave calculations and state-tracking are encapsulated inside a highly optimized include class, separating mathematical computations from visual drawing.

* **Strict $O(1)$ Real-Time Tick Optimization:**
  To support live-updating while preserving performance, the indicator computes only the **current live bar** (index `rates_total - 1`) on every tick. This keeps CPU usage at absolute zero, allowing the wave volume to tick-by-tick accumulate live in real-time.

* **High-Performance MTF Synchronization:**
  `WeisWave_MTF_Pro` aligns higher timeframe (HTF) waves directly to the current chart's bars using a highly optimized `iBarShift(..., false)` and native 1-bar price/volume copying routines. This avoids outdated MQL4-style functions (`iHigh`, `iClose`) and prevents terminal freezes during timeframe switching.

* **Platform-Aware Volume Selection:**
  The indicator checks `SYMBOL_VOLUME_LIMIT > 0`. If the broker supports Real Volume, it automatically uses it; otherwise, it seamlessly falls back to Tick Volume.

---

## 4. Parameters

* **Timeframe (`InpTimeframe` - MTF Version Only):** The target higher timeframe to track (e.g., `PERIOD_H1`, `PERIOD_H4`).
* **ATR Period (`InpATRPeriod`):** The lookback period used to calculate the dynamic Average True Range (Default: `14` bars).
* **Multiplier (`InpMultiplier`):** The number of ATRs required to trigger a wave reversal (Default: `2.5`). Higher values filter out minor consolidations; lower values capture micro-swings.

---

## 5. Advanced Wyckoffian Trading Strategies

The Weis Wave Volume Pro Suite is designed to help traders execute the core principles of Volume Spread Analysis (VSA) and Wyckoff methodology:

### A. Volume Climax (The Climactic Ending)

* **Concept:** As a trend wave approaches major support or resistance, institutional players execute climax transactions (Buying Climax or Selling Climax) to complete their accumulation or distribution.
* **Interpretation:** Look for a massive spike in the Weis Wave volume histogram (e.g., reaching or exceeding previous major wave peaks) that coincides with price hitting a VWAP or key horizontal level. This indicates the **effort has peaked**, and the wave is highly likely to exhaust and reverse.

### B. Effort vs. Result Divergences (Momentum Exhaustion)

* **Concept:** Richard Wyckoff's third law states that a large effort (high volume) must yield a proportional result (large price movement).
* **Interpretation:**
  * **No Supply (Test of Supply):** The price drops to make a new low (e.g., breaking a previous support), but the corresponding Crimson wave volume is **significantly smaller** than the previous Crimson wave. This proves there is no institutional selling interest left. Prepare to **BUY (Long)** immediately.
  * **No Demand (Test of Demand):** The price rallies to make a new high (e.g., breaking a previous resistance), but the corresponding DodgerBlue wave volume is **significantly smaller** than the previous DodgerBlue wave. This proves there is no institutional buying interest left. Prepare to **SELL (Short)** immediately.

### C. Spring and Upthrust Confirmation

* **Spring:** A false bearish breakout below support. If the breakout occurs on a Crimson wave with **very low cumulative volume**, it is a valid "Spring". The market is trapping retail sellers. Open a **Long** position as soon as the price closes back inside the range.
* **Upthrust:** A false bullish breakout above resistance. If the breakout occurs on a DodgerBlue wave with **very low cumulative volume**, it is a valid "Upthrust". Open a **Short** position as soon as the price closes back inside the range.
