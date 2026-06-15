# Weis Wave Duration Pro (Indicator)

## 1. Summary (Introduction)

The **Weis Wave Duration Pro** is an institutional-grade, high-performance separate window oscillator based on Richard Wyckoff's third law—**The Law of Effort versus Result**—and David Weis's wave mechanics.

While traditional indicators dissect price charts into artificial, equal-time intervals (such as 15-minute or 1-hour chunks), price action naturally unfolds in **waves of varying duration**. As David Weis emphasized, true market analysis requires the study of three critical dimensions:

1. **Wave Length** (Price progress)
2. **Wave Volume** (Transactional force)
3. **Wave Duration** (Time spent in bars)

`WeisWave_Duration_Pro` tracks the **Duration (bar count)** of each completed wave using a highly optimized, stateful non-repainting calculation engine.

In this upgraded version, the indicator integrates a revolutionary **Temporal Shortening of the Thrust (SOT-Duration) Highlight Layer**. It dynamically measures the duration of consecutive waves in real-time. If three consecutive waves show a progressive loss of duration, the state machine retroactively re-colors the entire completed wave on the histogram in a distinct color, delivering a highly intuitive "Time & Momentum Heatmap" in a single separate subwindow.

---

## 2. Mathematical Foundations and Wave Mechanics

The dynamic wave structure is determined by an ATR-based state machine. For each bar $t$, the indicator increments or resets the active wave duration.

### A. Linear Wave Duration Formula

Within an active wave of direction $D_t$, the duration is incremented linearly by exactly $1$ for each bar:

$$\text{Duration}_t = \text{Duration}_{t-1} + 1 \quad \text{for } D_t = D_{t-1}$$

When a reversal is triggered, the duration resets to $1$ for the new opposite wave:

$$\text{Duration}_t = 1 \quad \text{for } D_t \ne D_{t-1}$$

* **Up Wave Duration (Histogram > 0):** Plotted as a positive value ($+\text{Duration}_t$).
* **Down Wave Duration (Histogram < 0):** Plotted as a negative value ($-\text{Duration}_t$).

Because the increment is strictly linear ($1, 2, 3, \dots, N$), the top boundary of each wave histogram forms a **perfectly straight, linear diagonal slope (45-degree angle)**. This creates clean, regular geometric right triangles on the chart, which serves as the baseline of market time.

### B. ATR-Based Reversal Threshold

The swing direction $D_t \in \{1, -1\}$ is tracked dynamically using a multiplier $M$ (`InpMultiplier`) of the Average True Range (ATR):

$$\text{Threshold}_t = M \times \text{ATR}_t$$

* **Up Swing to Down Swing Reversal:**
  $$C_t < \max(H_{\text{wave}}) - \text{Threshold}_t$$
* **Down Swing to Up Swing Reversal:**
  $$C_t > \min(L_{\text{wave}}) + \text{Threshold}_t$$

### C. Sequential Temporal SOT Detection

An SOT signal is triggered when a sequence of three consecutive completed waves in the same direction shows a continuous, progressive decrease in wave duration (bar count):

$$\text{Duration}_{\text{Current}} < \text{Duration}_{\text{Previous}} < \text{Duration}_{\text{Before-Previous}}$$

* **Exhausted Up Duration (Orange Histogram > 0):** Bearish SOT detected. Buyers are losing their time advantage.
* **Exhausted Down Duration (Fuchsia Histogram < 0):** Bullish SOT detected. Sellers are losing their time advantage.

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`WeisWave_Duration_Calculator.mqh`):**
  All wave duration accumulation and state-tracking are encapsulated inside the highly optimized `CWeisWaveDurationCalculator` include class.

* **Retroactive Wave Coloring Algorithm:**
  When a wave reversal occurs, if `InpShowSOT` is enabled, the calculator runs a backward-search pass (`GetLastCompletedDurations`) through locked historical state arrays. If a temporal SOT is verified, the calculator instantly loops backwards and changes the color index of the entire completed wave from standard colors to Orange (Bearish SOT) or Fuchsia (Bullish SOT). This visual update runs strictly in $O(1)$ time, maintaining ultra-low CPU latency.

* **Strict $O(1)$ Real-Time Tick Optimization:**
  The calculator uses the platform's `prev_calculated` parameter to process only the newest incoming bar on every tick. Instead of running historical loops over thousands of bars, the calculator **recomputes only the current live bar** (index `rates_total - 1`), keeping CPU overhead at absolute zero.

* **100% Non-Repainting and EA-Compatible:**
  Standard Zigzag-based indicators repaint the history as new price extremes are made, making them useless for backtesting. `WeisWave_Duration_Pro` locks all wave duration states into historical arrays once a bar closes, ensuring that past waves are permanently frozen and 100% reliable for automated Expert Advisors (EAs).

---

## 4. Parameters

* **ATR Period (`InpATRPeriod`):** The lookback period used to calculate the dynamic Average True Range (Default: `14` bars).
* **Multiplier (`InpMultiplier`):** The number of ATRs required to trigger a wave reversal (Default: `2.5`). Lower values (e.g. `2.0` on M3) capture micro-swings; higher values (e.g. `3.0` on H1) filter out intraday consolidations.
* **Show SOT (`InpShowSOT`):** Toggle to highlight SOT (Momentum Exhaustion) waves in Orange/Fuchsia directly on the duration histogram.

---

## 5. Advanced Wyckoffian & VSA Trading Strategies

Comparing the geometric shapes of `WeisWave_Pro` (Volume) and `WeisWave_Duration_Pro` (Time) allows traders to apply **Wyckoff's Law of Effort versus Result** with high precision:

### A. The "Sharp" Triangle (Climax / High-Velocity Momentum)

* **Setup:** A wave shows a **very short horizontal duration** on `WeisWave_Duration_Pro` but exhibits a **very tall, steep vertical climb** on `WeisWave_Pro` (Volume) and price length.
* **Interpretation:** Huge transactional volume is flowing in over a very short period of time. This is a high-velocity momentum thrust (e.g. breakout) or a sudden, violent **Buying/Selling Climax**.
* **Action:** Prepare to trail your stop closely (if in trend) or look for immediate reversal confirmations at major support/resistance levels.

### B. The "Fat / Extended" Triangle (Institutional Absorption / SOT)

* **Setup:** A wave has a **very long horizontal duration** on `WeisWave_Duration_Pro` (stretching over 30-50 bars), but the price length shows a **Shortening of the Thrust (SOT)** and the cumulative volume is flat or lagging.
* **Interpretation:** Time is passing and effort is being exerted, but the price cannot make upward or downward progress. This represents **Institutional Absorption** (the "Composite Man" is using passive limit orders to absorb all market orders, putting a lid on the price).
* **Action:** This indicates a massive coiling of market energy. Prepare for a violent breakout in the opposite direction once the absorption phase is complete.

### C. Temporal SOT Reversal (Orange/Fuchsia Waves)

* **Bullish Setup:** Monitor a falling market. If the active Crimson wave (Supply) turns **Fuchsia** (Bullish SOT), it proves that sellers are losing their time advantage (exhausting in time). The eladói nyomás kifáradt, and a fast upward reversal is imminent.
* **Bearish Setup:** Monitor a rising market. If the active DodgerBlue wave (Demand) turns **Orange** (Bearish SOT), it proves that buyers are losing their time advantage. Prepare for a downward reversal.
