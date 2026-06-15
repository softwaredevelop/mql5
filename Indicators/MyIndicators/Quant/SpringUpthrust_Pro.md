# Wyckoff Springs & Upthrusts Pro (Indicator)

## 1. Summary (Introduction)

The **Wyckoff Springs & Upthrusts Pro** is an institutional-grade, non-repainting chart-overlay indicator designed to automatically detect Richard Wyckoff's most powerful structural false breakout patterns—**Springs** and **Upthrusts** [91, 113].

In technical analysis, major market reversals do not occur randomly. They emerge when large professional operators ("The Composite Man") test the depth of supply and demand around established trading ranges [92, 126].

* A **Spring** is a bullish washout of support where selling pressure exhausts, triggering a fast upward reversal [91].
* An **Upthrust** is a bearish breakout of resistance where buying demand exhausts, triggering a fast downward reversal [113].

`SpringUpthrust_Pro` uses a high-precision, 3-step validation process (Fractal Peaks, Washout, and Volume-Spread Confirmation) to eliminate micro-noise and identify high-probability turning points exactly at the **"danger point"** where risk is minimal and reward is maximal [94, 113].

---

## 2. Mathematical Foundations & VSA Confirmation

The indicator operates a continuous state machine that validates each signal bar against three distinct quantitative criteria:

### A. Step 1: Dynamic Fractal Support & Resistance Detection

The indicator dynamically scans for Bill Williams' 2-bar fractal highs and lows to establish valid historical Support ($S_{\text{level}}$) and Resistance ($R_{\text{level}}$) boundaries.

* **Fractal High ($R_{\text{level}}$) confirmed at bar $t-2$:**
  $$H_{t-2} > \max(H_{t-1}, H_t, H_{t-3}, H_{t-4})$$
* **Fractal Low ($S_{\text{level}}$) confirmed at bar $t-2$:**
  $$L_{t-2} < \min(L_{t-1}, L_t, L_{t-3}, L_{t-4})$$

### B. Step 2: Washout and Rejection Close (The Trap)

The price must penetrate the active level on the current bar $t$, but close back inside the trading range:

* **Spring Condition:**
  $$L_t < S_{\text{level}} \quad \text{and} \quad C_t > S_{\text{level}}$$
* **Upthrust Condition:**
  $$H_t > R_{\text{level}} \quad \text{and} \quad C_t < R_{\text{level}}$$

### C. Step 3: Volume Spread Analysis (VSA) Filtering

To eliminate false signals, the breakout bar is classified and filtered based on its **Relative Volume ($RVOL_t$)** and **Bar Spread ($High_t - Low_t$)**:

* **Type 1: Low-Volume Exhaustion (No Supply / No Demand)**
  Triggers when the level is penetrated on low volume ($RVOL_t < 1.0$) with a clear rejection close (close is in the upper half of the bar for Spring, and lower half for Upthrust) [91, 121]:
  $$\text{Spring Type 1:} \quad RVOL_t < 1.0 \quad \text{and} \quad \frac{C_t - L_t}{H_t - L_t} \ge 0.5$$
  $$\text{Upthrust Type 1:} \quad RVOL_t < 1.0 \quad \text{and} \quad \frac{H_t - C_t}{H_t - L_t} \ge 0.5$$

* **Type 2: High-Volume Absorption (Effort vs. Result)**
  Triggers when the level is penetrated on heavy volume ($RVOL_t > 1.8$), but the price fails to make downward progress (large effort, small result), resulting in a strong rejection pinbar close [96, 121]:
  $$\text{Spring Type 2:} \quad RVOL_t > 1.8 \quad \text{and} \quad \frac{C_t - L_t}{H_t - L_t} \ge 0.6$$
  $$\text{Upthrust Type 2:} \quad RVOL_t > 1.8 \quad \text{and} \quad \frac{H_t - C_t}{H_t - L_t} \ge 0.6$$

---

## 3. MQL5 UI & Architecture

* **Decoupled Math Engine (`SpringUpthrust_Calculator.mqh`):**
  All fractal S/R scanning, breakout verification, and VSA filtering are encapsulated inside `CSpringUpthrustCalculator`.

* **100% Non-Repainting and EA-Compatible:**
  Unlike traditional false breakout indicators that repaint the history when new extremes occur, `SpringUpthrust_Pro` locks all states in historical arrays once a bar closes, ensuring that past signals are permanently frozen and 100% reliable for automated Expert Advisors (EAs).

* **Strict $O(1)$ Real-Time Tick Optimization:**
  The calculator uses the platform's `prev_calculated` parameter to process only the newest incoming bar on every tick. This keeps CPU usage at absolute zero.

* **Bulletproof Chronological Level-Time Tracking:**
  To completely prevent the common MT5 `array out of range` exception inside the Strategy Tester, `SpringUpthrust_Pro` records the **exact time** when the tested Support/Resistance level was originally formed. When drawing the horizontal trend lines, the start coordinate is mapped directly to that historical timestamp, ensuring flawless, crash-free execution on any broker history.

---

## 4. Parameters

* **Fractal Period (`InpFractalPeriod`):** The period used to scan for valid historical support and resistance peaks (Default: `5` bars).
* **Min Level Age (`InpMinLevelAge`):** The minimum number of bars that must elapse after a level is formed before it can be tested (Default: `10` bars). This is the **primary noise filter** that eliminates false breakout signals during steep trends.
* **ATR Period (`InpATRPeriod`):** The lookback period used to calculate the Average True Range (Default: `14` bars).
* **RVOL Period (`InpRVOLPeriod`):** The lookback period used to calculate the Relative Volume (Default: `20` bars).
* **Draw Level Lines (`InpDrawLevelLines`):** Toggle to draw a beautiful, dashed horizontal line from the historical level's starting peak to the breakout bar.

---

## 5. Advanced Wyckoffian Trading Strategies

### A. Entering Trades at the "Danger Point"

Wyckoff noted that the Spring is the ultimate trade because it allows you to enter exactly at the "danger point" where risk is minimal and reward is maximal [94, 112].

* **The Setup:** A **Green Arrow (Spring)** is printed under the low of a bar on the chart, and a dashed green support line is drawn.
* **The Entry:** Buy at the open of the next bar.
* **The Stop Loss:** Place your stop loss exactly 1-2 pips below the low of the Spring bar. Since the SOT math has proven that selling pressure is exhausted, if the price breaks below this low, the setup is invalidated. Your risk is extremely small!

### B. Distinguishing Low-Volume vs. High-Volume Reversals

* **Low-Volume Reversal (Type 1 - No Supply):** The price drops below support on very low volume, indicating a complete lack of public and professional selling interest [94]. The up-move that follows is usually swift.
* **High-Volume Reversal (Type 2 - Absorption):** The price drops below support on huge volume, but the close is high. This means large operators are actively absorbing all selling orders (bag-holding) [92]. This setup often requires a **Secondary Test** (a pullback to the same area on lower volume) before the markup begins [96].

### C. Bull/Bear Market Filter

* **In an Uptrend:** Springs have a very high probability of success and can be traded aggressively to pyramid long positions [91, 105]. Upthrusts in an uptrend are often brief and should only be used to take profits [105].
* **In a Downtrend:** Upthrusts have a very high probability of success [96]. Springs in a downtrend are highly prone to failure ("bottom picker's nightmare") and should be avoided or used to short the failed bounce [105].
