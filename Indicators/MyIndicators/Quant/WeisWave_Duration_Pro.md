# Weis Wave Duration Pro Suite (Standard & MTF)

## 1. Summary (Introduction)

The **Weis Wave Duration Pro Suite** is an institutional-grade, high-performance separate window quantitative suite comprising two advanced indicators: `WeisWave_Duration_Pro` (Standard) and `WeisWave_Duration_MTF_Pro` (Multi-Timeframe). Based on Richard Wyckoff's third law—**The Law of Effort versus Result**—and David Weis's wave mechanics, the suite tracks the temporal expansion of market cycles.

While traditional indicators dissect price charts into artificial, equal-time intervals (such as 15-minute or 1-hour chunks), price action naturally unfolds in **waves of varying duration**. As David Weis emphasized, true market analysis requires the study of three critical dimensions:

1. **Wave Length** (Price progress)
2. **Wave Volume** (Transactional force / Cumulative volume)
3. **Wave Duration** (Time spent in bars / Cumulative time)

The suite tracks the **Duration (bar count)** of each completed wave using a highly optimized, stateful non-repainting calculation engine.

Both indicators integrate a revolutionary **Temporal Shortening of the Thrust (SOT-Duration) Highlight Layer**. They dynamically measure the duration of consecutive waves in real-time. If three consecutive waves show a progressive loss of duration, the state machine retroactively re-colors the entire completed wave on the histogram in a distinct color, delivering a highly intuitive "Time & Momentum Heatmap" in a single separate subwindow.

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

* **Exhausted Up Duration (Orange Histogram > 0):** Bearish SOT detected. Buyers are losing their time advantage (exhausting in time).
* **Exhausted Down Duration (Fuchsia Histogram < 0):** Bullish SOT detected. Sellers are losing their time advantage (exhausting in time).

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`WeisWave_Duration_Calculator.mqh`):**
  All wave duration accumulation, backward-state search, and sequential SOT-tracking are encapsulated inside the highly optimized `CWeisWaveDurationCalculator` include class.

* **Retroactive Wave Coloring Algorithm:**
  When a wave reversal occurs, if `InpShowSOT` is enabled, the calculator runs a backward-search pass (`GetLastCompletedDurations`) through locked historical state arrays. If a temporal SOT is verified, the calculator instantly loops backwards and changes the color index of the entire completed wave from standard colors to Orange (Bearish SOT) or Fuchsia (Bullish SOT). This visual update runs strictly in $O(1)$ time, maintaining ultra-low CPU latency.

* **Forming LTF Block Flat-Force (The Warping Solution):**
  `WeisWave_Duration_MTF_Pro` resolves the classic MTF live-bar warping bug (where only the very last LTF bar gets updated, creating a jagged, diagonal line across the active HTF block) by implementing the **Forming LTF Block Flat-Force** step-blocking algorithm. On every tick, the indicator locates the exact boundary of the active forming HTF block and dynamically forces the calculation's starting index back to the beginning of that block:

  ```mql5
  int first_bar_of_forming_htf = rates_total - 1;
  while(first_bar_of_forming_htf > 0 &&
        iBarShift(_Symbol, InpTimeframe, time[first_bar_of_forming_htf], false) == 0)
    {
     first_bar_of_forming_htf--;
    }
  first_bar_of_forming_htf++; // Start index of the forming HTF step block on lower TF chart

  if(start > first_bar_of_forming_htf)
     start = first_bar_of_forming_htf;
  ```

  By forcing a full-block rewrite on every live tick, the active HTF step remains perfectly flat and responsive in real-time, matching institutional charting standards.

* **Strict Non-Repainting State Safety on MTF Live Ticks:**
  To support real-time updating without modifying closed historical wave states (which would cause severe repainting and backtesting discrepancies), `WeisWave_Duration_MTF_Pro` utilizes a highly sophisticated state-mocking call. During live updates on every tick, we pass `prev_calculated = g_htf_count` (which equals `rates_total` inside the calculator). This forces the loop inside the calculator to run **only once** for the active live index, using the stable closed-bar registers, without overwriting or double-accumulating any historical states.
  Once a bar closes, the wave duration is locked permanently, ensuring the indicator is 100% reliable for automated Expert Advisors (EAs).

* **Asynchronous Timer Guard:**
  A 1-second `OnTimer` background daemon repeatedly verifies data readiness (`EnsureHTFDataReady`) and instantly triggers a chart redraw (`ChartRedraw()`) as soon as HTF history is ready, preventing blank charts on startup.

---

## 4. Parameters

### A. Core Kinematic Settings

* **ATR Period (`InpATRPeriod`):** The lookback period used to calculate the Average True Range (Default: `14` bars).
* **Multiplier (`InpMultiplier`):** The number of ATRs required to trigger a wave reversal (Default: `2.5`). Lower values (e.g. `2.0` on M3) capture micro-swings; higher values (e.g. `3.0` on H1) filter out intraday consolidations.

* **Show SOT (`InpShowSOT`):** Toggle to highlight SOT (Momentum Exhaustion) waves in Orange/Fuchsia directly on the duration histogram.

### B. MTF Specific Parameters

* **Target Timeframe (`InpTimeframe`):** The target higher timeframe to calculate wave durations on (Default: `PERIOD_M5`).

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

### D. Top-Down Temporal SOT Alignment (MTF Core Strategy)

1. **Macro Wave Duration (H1/H4):** Apply `WeisWave_Duration_MTF_Pro` set to H1 or H4 on an M5 execution chart.
2. **The Setup:** Wait for the macro **H1 Wave Duration** to turn **Orange (Bearish SOT)** or **Fuchsia (Bullish SOT)**, indicating that the macro-level buying/selling pressure has exhausted in time.
3. **Execution:** On the lower M5 chart, only look for entries aligned with the macro reversal. If H1 is Fuchsia (Bullish SOT), wait for local M5 momentum to shift (e.g. local Velocity crossing its Signal Line, or local Squeeze firing green) and execute high-probability **BUY** orders, riding the macro reversal from its very inception.
