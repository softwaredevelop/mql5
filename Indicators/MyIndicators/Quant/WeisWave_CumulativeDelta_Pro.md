# Weis Wave Cumulative Delta Pro (Indicator)

## 1. Summary (Introduction)

The **Weis Wave Cumulative Delta Pro** is an institutional-grade, high-frequency volume-flow oscillator based on Richard Wyckoff's first law—**The Law of Supply and Demand**—and David Weis's wave mechanics.

While traditional volume oscillators (like On-Balance Volume - OBV) accumulate volume based on simple candle-by-candle close prices (introducing massive noise and false signals), `WeisWave_CumulativeDelta_Pro` aggregates volume strictly along **ATR-defined price waves** (swing legs). By summing volume on upward waves and subtracting it on downward waves, the indicator filters out intraday noise and tracks the long-term cumulative net trend of institutional money flow (Smart Money Flow).

The indicator features a highly optimized $O(1)$ real-time mathematical engine, a dynamically colored trend line (Green when rising, Red when falling), and a bulletproof, gap-resistant bar-time synchronization module.

---

## 2. Mathematical Foundations and Wave Mechanics

The mathematical structure of the Cumulative Delta ($\Delta$) is computed continuously at each bar $t$ by integrating the active wave direction ($D_t$) and the volume ($V_t$):

### A. Wave-Filtered Cumulative Delta Formula

$$\Delta_t = \Delta_{t-1} + (D_t \times V_t)$$

Where:

* $V_t$ = The volume (Real Volume or Tick Volume) of the current bar $t$.
* $D_t \in \{1, -1\}$ = The active swing leg direction determined by the ATR-based state machine:
  * $D_t = 1$ (Up Wave / Demand): Volume is added to the cumulative net sum.
  * $D_t = -1$ (Down Wave / Supply): Volume is subtracted from the cumulative net sum.

### B. ATR-Based Reversal Threshold

The swing leg direction is determined dynamically using a multiplier $M$ (`InpMultiplier`) of the Average True Range (ATR):

$$\text{Threshold}_t = M \times \text{ATR}_t$$

* **Up Swing to Down Swing Reversal:** Triggers when the price drops below the wave's peak high minus the threshold:
  $$C_t < \max(H_{\text{wave}}) - \text{Threshold}_t$$
* **Down Swing to Up Swing Reversal:** Triggers when the price rises above the wave's trough low plus the threshold:
  $$C_t > \min(L_{\text{wave}}) + \text{Threshold}_t$$

Once a reversal is triggered, the direction changes, and the volume continues to accumulate in the opposite mathematical direction.

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`WeisWave_CumulativeDelta_Calculator.mqh`):**
  All wave tracking, volume direction routing, and cumulative integration logic are encapsulated inside the highly optimized `CWeisWaveDeltaCalculator` include class.

* **Strict $O(1)$ Real-Time Tick Optimization:**
  To support live-updating while preserving performance, the indicator computes only the **current live bar** (index `rates_total - 1`) on every tick. This keeps CPU usage at absolute zero, allowing the Cumulative Delta to tick-by-tick accumulate live in real-time.

* **100% Non-Repainting and EA-Compatible:**
  Unlike traditional Zigzag-based indicators, `WeisWave_CumulativeDelta_Pro` locks all wave and delta states into historical arrays once a bar closes. The historical line is permanently locked and never repaints, making the indicator 100% reliable for backtesting and automated Expert Advisors (EAs).

* **Dynamic Color Line Rendering:**
  To provide maximum visual clarity, the oscillator line is drawn using a high-precision `DRAW_COLOR_LINE` plot style:
  * **LimeGreen:** Rising Cumulative Delta ($\Delta_t \ge \Delta_{t-1}$), signaling dominant buying pressure.
  * **Crimson:** Falling Cumulative Delta ($\Delta_t < \Delta_{t-1}$), signaling dominant selling pressure.

---

## 4. Parameters

* **ATR Period (`InpATRPeriod`):** The lookback period used to calculate the dynamic Average True Range (Default: `14` bars).
* **Multiplier (`InpMultiplier`):** The number of ATRs required to trigger a wave reversal (Default: `2.5`). Lower values capture micro-swings; higher values filter out intraday consolidations.

---

## 5. Advanced Trading & Divergence Strategies

The Cumulative Delta is the ultimate **Smart Money Divergence Filter**, used to spot when institutional accumulation/distribution is occurring under cover of retail price action.

### A. The Bullish Divergence (Accumulation Setup)

* **The Setup:** The price makes a new lower low (e.g. breaking support), but the Cumulative Delta line makes a **significantly higher low** (and turns Green).
* **The Interpretation:** Retail traders are panic-selling, but the "Composite Man" (institutions) is absorbing all the supply and accumulating positions without pushing the price up yet [1].
* **Action:** Prepare to **BUY (Long)** as soon as the price stabilizes.

### B. The Bearish Divergence (Distribution Setup)

* **The Setup:** The price makes a new higher high (e.g. breaking resistance), but the Cumulative Delta line makes a **significantly lower high** (and turns Red).
* **The Interpretation:** Retail traders are buying the breakout, but institutions are distributing (selling) their positions, capping the net volume flow.
* **Action:** Prepare to **SELL (Short)** as soon as the price rolls over.

### C. Synergy with Weis Wave SOT Pro

By placing `WeisWave_Pro` (with integrated SOT highlighting) and `WeisWave_CumulativeDelta_Pro` on the same chart, traders have a complete Wyckoff terminal:

* **The Trigger:** If the standard Weis Wave turns **Orange/Fuchsia**, signaling a **Shortening of the Thrust (SOT)** wave exhaustion.
* **The Confirmation:** If the Cumulative Delta simultaneously confirms a **Bullish/Bearish Divergence**.
* **Result:** This dual confirmation represents one of the highest-probability trend-reversal setups in the Wyckoff methodology, allowing traders to enter exactly at the "danger point" with minimal risk.
