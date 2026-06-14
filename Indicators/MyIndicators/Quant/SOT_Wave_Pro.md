# Shortening of the Thrust Wave Pro (SOT Wave Pro)

## 1. Summary (Introduction)

The **Shortening of the Thrust Wave Pro (SOT Wave Pro)** is an institutional-grade, non-repainting market regime and momentum exhaustion indicator based on Richard Wyckoff's third law—**The Law of Effort versus Result**—and David Weis's wave mechanics.

In financial markets, a trend ends when the buying or selling waves begin to shorten in distance or duration, signaling a loss of institutional participation. This phenomenon is known as **Shortening of the Thrust (SOT)**.

`SOT_Wave_Pro` automatically detects this momentum exhaustion in real-time. By utilizing a highly optimized, stateful non-repainting calculation engine, the indicator monitors consecutive price waves and plots high-precision buy (Green) and sell (Red) arrows on the exact peak or trough bar where the structural exhaustion occurs.

---

## 2. Mathematical Foundations and Wave Mechanics

Unlike standard oscillators (RSI, Stochastic) that suffer from temporal compression, `SOT_Wave_Pro` measures momentum over **price waves** (swing legs), which is the natural way market cycles unfold.

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

An SOT signal is triggered when a sequence of three consecutive completed waves in the same direction shows a continuous, progressive decrease in vertical progress (Thrust):

$$\text{Length}_{\text{Current}} < \text{Length}_{\text{Previous}} < \text{Length}_{\text{Before-Previous}}$$

* **Bearish SOT (Red Arrow):** Triggered when three consecutive upward waves show diminishing progress. This represents buyers exhausting (No Demand), flagging the absolute distribution peak.
* **Bullish SOT (Green Arrow):** Triggered when three consecutive downward waves show diminishing progress. This represents sellers exhausting (No Supply), flagging the absolute accumulation trough.

---

## 3. MQL5 UI & Architecture

* **Decoupled Stateful Engine (`SOT_Wave_Calculator.mqh`):**
  All wave tracking, height calculations, and SOT logic are encapsulated inside `CSOTWaveCalculator`. It maintains persistent state variables (Direction, Peak High, Peak Low, and Wave Length) in internal arrays, isolating calculations from chart rendering.

* **100% Non-Repainting and EA-Compatible:**
  Traditional Zigzag-based indicators recalculate past bars when a new high/low is made, making them useless for automated trading. `SOT_Wave_Pro` locks all wave states into historical arrays once a bar closes. SOT signals are plotted exactly on the historical peak/trough bar and never repaint, making the indicator 100% reliable for Expert Advisors (EAs).

* **Strict $O(1)$ Real-Time Tick Optimization:**
  To support live-updating while preserving performance, the indicator computes only the **current live bar** (index `rates_total - 1`) on every tick. It resizes dynamic arrays on startup and performs rolling calculations efficiently.

* **High-Performance MT5 Price Copying:**
  To guarantee compatibility across all MT5 terminals and Strategy Tester builds, the indicator uses native 1-bar price/volume copying routines (`CopyHigh`, `CopyLow`, `CopyClose`), completely avoiding outdated MQL4-style functions.

---

## 4. Parameters

* **ATR Period (`InpATRPeriod`):** The lookback period used to calculate the dynamic Average True Range (Default: `14` bars).
* **Multiplier (`InpMultiplier`):** The number of ATRs required to trigger a wave reversal (Default: `2.5`). Lower values (e.g. `2.0` on M3) capture micro-swings; higher values (e.g. `3.0` on H1) filter out intraday consolidations.

---

## 5. Advanced Wyckoffian Trading Strategies

### A. Trading the SOT at the "Danger Point"

Wyckoff stated that successful trading involves entering at the "danger point"—the exact price level where your potential loss is minimal and the profit potential is maximum [1].

* **Setup:** Wait for a **Green Arrow (Bullish SOT)** to print at a major support or VWAP level.
* **Entry:** Place a buy limit or enter at the open of the next bar.
* **Stop Loss:** Place your stop loss exactly 1-2 pips below the trough bar (the bar where the arrow is located). Since this is the absolute mathematical trough, if the price drops below it, the SOT setup is invalidated. The risk is extremely small!

### B. Spring and Upthrust Confirmation

SOT waves are highly effective for validating false breakouts:

* **Spring Validation:** If the price breaks below a major support level (Spring) and immediately triggers a **Green SOT Arrow**, it proves that the selling pressure has exhausted. The breakout is a trap. Go **Long** immediately.
* **Upthrust Validation:** If the price breaks above a major resistance level (Upthrust) and immediately triggers a **Red SOT Arrow**, it proves that the buying pressure has exhausted. Go **Short** immediately.

### C. ADX / Volume Climax Synergy

To further increase the win rate, combine `SOT_Wave_Pro` with a volume-climax filter (such as `WeisWave_Pro`):

* If the third (shortest) wave in the SOT sequence shows a **significant drop in volume** compared to the first wave, it is a low-volume exhaustion (No Supply / No Demand).
* If the third wave has a **huge volume spike** but makes almost no progress, it represents high-volume absorption (Buying/Selling Climax), indicating that institutional limit orders are absorbing the market flow and preparing for a massive reversal.
